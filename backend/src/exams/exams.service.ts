import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../common/decorators/current-user.decorator';
import {
  BulkResultsDto,
  CreateExamDto,
  EnterResultDto,
  ExamSubjectDto,
  UpdateExamDto,
} from './dto/exam.dto';

interface StoredMark {
  subject: string;
  marksObtained: number;
  maxMarks: number;
}

function gradeFor(pct: number): string {
  if (pct >= 90) return 'A+';
  if (pct >= 80) return 'A';
  if (pct >= 70) return 'B+';
  if (pct >= 60) return 'B';
  if (pct >= 50) return 'C';
  if (pct >= 40) return 'D';
  return 'F';
}

@Injectable()
export class ExamsService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(batchId?: string) {
    const exams = await this.prisma.exam.findMany({
      where: batchId ? { batchId } : {},
      include: {
        batch: { select: { id: true, name: true, course: true } },
        _count: { select: { results: true } },
      },
      orderBy: { examDate: 'desc' },
    });
    return exams.map(({ _count, ...e }) => ({
      ...e,
      resultCount: _count.results,
    }));
  }

  async findOne(id: string) {
    const exam = await this.prisma.exam.findUnique({
      where: { id },
      include: {
        batch: {
          select: {
            id: true,
            name: true,
            course: true,
            students: {
              where: { isActive: true },
              select: { id: true, name: true, studentCode: true },
              orderBy: { name: 'asc' },
            },
          },
        },
        results: {
          include: {
            student: { select: { id: true, name: true, studentCode: true } },
          },
          orderBy: [{ obtained: 'desc' }],
        },
      },
    });
    if (!exam) throw new NotFoundException('Exam not found');

    return {
      ...exam,
      results: exam.results.map((r) => this.shapeResult(r)),
      stats: this.stats(exam.results),
    };
  }

  /** Marks-entry grid: every active student in the batch + existing marks. */
  async marksSheet(examId: string) {
    const exam = await this.prisma.exam.findUnique({
      where: { id: examId },
      include: {
        batch: {
          select: {
            id: true,
            name: true,
            students: {
              where: { isActive: true },
              select: { id: true, name: true, studentCode: true },
              orderBy: { name: 'asc' },
            },
          },
        },
        results: true,
      },
    });
    if (!exam) throw new NotFoundException('Exam not found');

    const subjects = exam.subjects as unknown as ExamSubjectDto[];
    const byStudent = new Map(exam.results.map((r) => [r.studentId, r]));

    return {
      exam: {
        id: exam.id,
        name: exam.name,
        examDate: exam.examDate,
        totalMarks: exam.totalMarks,
        isPublished: exam.isPublished,
      },
      batch: { id: exam.batch.id, name: exam.batch.name },
      subjects,
      rows: exam.batch.students.map((s) => {
        const existing = byStudent.get(s.id);
        const marks = (existing?.marks as unknown as StoredMark[]) ?? [];
        return {
          studentId: s.id,
          name: s.name,
          studentCode: s.studentCode,
          resultId: existing?.id ?? null,
          remarks: existing?.remarks ?? null,
          marks: subjects.map((sub) => ({
            subject: sub.name,
            maxMarks: sub.maxMarks,
            marksObtained:
              marks.find((m) => m.subject === sub.name)?.marksObtained ?? null,
          })),
        };
      }),
    };
  }

  async create(dto: CreateExamDto) {
    const batch = await this.prisma.batch.findUnique({
      where: { id: dto.batchId },
    });
    if (!batch) throw new BadRequestException('Selected batch does not exist');

    const names = dto.subjects.map((s) => s.name.trim().toLowerCase());
    if (new Set(names).size !== names.length) {
      throw new BadRequestException('Subject names must be unique');
    }

    const totalMarks = dto.subjects.reduce((s, x) => s + x.maxMarks, 0);
    return this.prisma.exam.create({
      data: {
        batchId: dto.batchId,
        name: dto.name,
        examDate: new Date(dto.examDate),
        description: dto.description ?? null,
        subjects: dto.subjects as unknown as Prisma.InputJsonValue,
        totalMarks,
      },
    });
  }

  async update(id: string, dto: UpdateExamDto) {
    const exam = await this.prisma.exam.findUnique({
      where: { id },
      include: { _count: { select: { results: true } } },
    });
    if (!exam) throw new NotFoundException('Exam not found');

    if (dto.subjects && exam._count.results > 0) {
      throw new BadRequestException(
        'Marks are already entered for this exam. Delete the results before changing subjects.',
      );
    }

    const totalMarks = dto.subjects
      ? dto.subjects.reduce((s, x) => s + x.maxMarks, 0)
      : undefined;

    return this.prisma.exam.update({
      where: { id },
      data: {
        ...(dto.batchId ? { batchId: dto.batchId } : {}),
        ...(dto.name ? { name: dto.name } : {}),
        ...(dto.examDate ? { examDate: new Date(dto.examDate) } : {}),
        ...(dto.description !== undefined
          ? { description: dto.description }
          : {}),
        ...(dto.subjects
          ? { subjects: dto.subjects as unknown as Prisma.InputJsonValue }
          : {}),
        ...(totalMarks !== undefined ? { totalMarks } : {}),
        ...(dto.isPublished !== undefined
          ? { isPublished: dto.isPublished }
          : {}),
      },
    });
  }

  async remove(id: string) {
    const exam = await this.prisma.exam.findUnique({ where: { id } });
    if (!exam) throw new NotFoundException('Exam not found');
    await this.prisma.exam.delete({ where: { id } });
    return { message: 'Exam and its results deleted' };
  }

  async enterResult(examId: string, dto: EnterResultDto) {
    await this.saveResults(examId, [dto]);
    await this.recalculateRanks(examId);
    const saved = await this.prisma.examResult.findUnique({
      where: { exam_student_unique: { examId, studentId: dto.studentId } },
      include: { student: { select: { id: true, name: true, studentCode: true } } },
    });
    return this.shapeResult(saved!);
  }

  async enterBulk(examId: string, dto: BulkResultsDto) {
    await this.saveResults(examId, dto.results);
    await this.recalculateRanks(examId);
    return {
      message: `Marks saved for ${dto.results.length} student(s)`,
      ...(await this.findOne(examId)),
    };
  }

  async removeResult(resultId: string) {
    const result = await this.prisma.examResult.findUnique({
      where: { id: resultId },
    });
    if (!result) throw new NotFoundException('Result not found');
    await this.prisma.examResult.delete({ where: { id: resultId } });
    await this.recalculateRanks(result.examId);
    return { message: 'Result removed' };
  }

  /** Report card for a student: every published exam they sat. */
  async studentResults(studentId: string, requester: AuthUser) {
    if (requester.role === 'STUDENT' && requester.studentId !== studentId) {
      throw new ForbiddenException('You can only view your own results');
    }
    const onlyPublished = requester.role === 'STUDENT';

    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      select: { id: true, name: true, studentCode: true, course: true },
    });
    if (!student) throw new NotFoundException('Student not found');

    const results = await this.prisma.examResult.findMany({
      where: {
        studentId,
        ...(onlyPublished ? { exam: { isPublished: true } } : {}),
      },
      include: {
        exam: {
          select: {
            id: true,
            name: true,
            examDate: true,
            totalMarks: true,
            isPublished: true,
            batch: { select: { name: true } },
            _count: { select: { results: true } },
          },
        },
      },
      orderBy: { exam: { examDate: 'desc' } },
    });

    const shaped = results.map((r) => ({
      ...this.shapeResult(r),
      classSize: r.exam._count.results,
    }));

    const avg =
      shaped.length > 0
        ? Number(
            (
              shaped.reduce((s, r) => s + r.percentage, 0) / shaped.length
            ).toFixed(2),
          )
        : 0;

    return {
      student,
      summary: {
        examsTaken: shaped.length,
        averagePercentage: avg,
        bestPercentage:
          shaped.length > 0
            ? Math.max(...shaped.map((r) => r.percentage))
            : 0,
        bestRank:
          shaped.filter((r) => r.rank).length > 0
            ? Math.min(...shaped.filter((r) => r.rank).map((r) => r.rank!))
            : null,
      },
      results: shaped,
    };
  }

  private async saveResults(examId: string, entries: EnterResultDto[]) {
    const exam = await this.prisma.exam.findUnique({
      where: { id: examId },
      include: { batch: { select: { id: true } } },
    });
    if (!exam) throw new NotFoundException('Exam not found');

    const subjects = exam.subjects as unknown as ExamSubjectDto[];
    const subjectMap = new Map(subjects.map((s) => [s.name, s.maxMarks]));

    const studentIds = entries.map((e) => e.studentId);
    const students = await this.prisma.student.findMany({
      where: { id: { in: studentIds } },
      select: { id: true, name: true, batchId: true },
    });
    if (students.length !== new Set(studentIds).size) {
      throw new BadRequestException('One or more students no longer exist');
    }
    const wrongBatch = students.find((s) => s.batchId !== exam.batchId);
    if (wrongBatch) {
      throw new BadRequestException(
        `${wrongBatch.name} is not in the batch this exam belongs to`,
      );
    }

    const ops: Prisma.PrismaPromise<unknown>[] = [];

    for (const entry of entries) {
      const marks: StoredMark[] = [];
      for (const m of entry.marks) {
        const maxMarks = subjectMap.get(m.subject);
        if (maxMarks === undefined) {
          throw new BadRequestException(
            `"${m.subject}" is not a subject in this exam`,
          );
        }
        if (m.marksObtained > maxMarks) {
          throw new BadRequestException(
            `${m.subject}: ${m.marksObtained} exceeds the maximum of ${maxMarks}`,
          );
        }
        marks.push({
          subject: m.subject,
          marksObtained: m.marksObtained,
          maxMarks,
        });
      }

      // Only count the subjects actually entered towards the total.
      const totalMarks = marks.reduce((s, m) => s + m.maxMarks, 0);
      const obtained = marks.reduce((s, m) => s + m.marksObtained, 0);
      const percentage =
        totalMarks > 0 ? Number(((obtained / totalMarks) * 100).toFixed(2)) : 0;

      const data = {
        marks: marks as unknown as Prisma.InputJsonValue,
        totalMarks,
        obtained: new Prisma.Decimal(obtained),
        percentage: new Prisma.Decimal(percentage),
        grade: gradeFor(percentage),
        remarks: entry.remarks ?? null,
      };

      ops.push(
        this.prisma.examResult.upsert({
          where: {
            exam_student_unique: { examId, studentId: entry.studentId },
          },
          create: { examId, studentId: entry.studentId, ...data },
          update: data,
        }),
      );
    }

    await this.prisma.$transaction(ops);
  }

  /** Dense ranking by percentage; ties share a rank. */
  private async recalculateRanks(examId: string) {
    const results = await this.prisma.examResult.findMany({
      where: { examId },
      orderBy: { percentage: 'desc' },
      select: { id: true, percentage: true },
    });

    let rank = 0;
    let lastPct: number | null = null;
    const ops = results.map((r, i) => {
      const pct = Number(r.percentage);
      if (lastPct === null || pct < lastPct) {
        rank = i + 1;
        lastPct = pct;
      }
      return this.prisma.examResult.update({
        where: { id: r.id },
        data: { rank },
      });
    });
    if (ops.length) await this.prisma.$transaction(ops);
  }

  private shapeResult(r: any) {
    return {
      ...r,
      obtained: Number(r.obtained),
      percentage: Number(r.percentage),
      marks: r.marks as StoredMark[],
    };
  }

  private stats(results: { percentage: Prisma.Decimal }[]) {
    if (results.length === 0) {
      return { count: 0, average: 0, highest: 0, lowest: 0, passRate: 0 };
    }
    const pcts = results.map((r) => Number(r.percentage));
    const passed = pcts.filter((p) => p >= 40).length;
    return {
      count: pcts.length,
      average: Number(
        (pcts.reduce((a, b) => a + b, 0) / pcts.length).toFixed(2),
      ),
      highest: Math.max(...pcts),
      lowest: Math.min(...pcts),
      passRate: Number(((passed / pcts.length) * 100).toFixed(1)),
    };
  }
}
