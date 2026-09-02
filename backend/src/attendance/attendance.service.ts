import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AttendanceStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  AttendanceHistoryQueryDto,
  AttendanceSheetQueryDto,
  MarkAttendanceDto,
} from './dto/attendance.dto';

/** Normalise any incoming date to a UTC midnight `Date` (@db.Date column). */
function toDateOnly(input: string | Date): Date {
  const d = typeof input === 'string' ? new Date(input) : input;
  if (Number.isNaN(d.getTime())) throw new BadRequestException('Invalid date');
  return new Date(
    Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()),
  );
}

function ymd(d: Date): string {
  return d.toISOString().slice(0, 10);
}

@Injectable()
export class AttendanceService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Roster for a batch + date, pre-filled with whatever is already marked.
   * The admin UI renders straight from this.
   */
  async sheet(query: AttendanceSheetQueryDto) {
    const date = toDateOnly(query.date);

    const batch = await this.prisma.batch.findUnique({
      where: { id: query.batchId },
      include: {
        students: {
          where: { isActive: true },
          orderBy: { name: 'asc' },
          select: { id: true, name: true, studentCode: true },
        },
      },
    });
    if (!batch) throw new NotFoundException('Batch not found');

    const existing = await this.prisma.attendance.findMany({
      where: { batchId: batch.id, date },
    });
    const byStudent = new Map(existing.map((a) => [a.studentId, a]));

    return {
      batch: {
        id: batch.id,
        name: batch.name,
        subject: batch.subject,
        timing: batch.timing,
        room: batch.room,
      },
      date: ymd(date),
      alreadyMarked: existing.length > 0,
      markedCount: existing.length,
      entries: batch.students.map((s) => {
        const rec = byStudent.get(s.id);
        return {
          studentId: s.id,
          name: s.name,
          studentCode: s.studentCode,
          status: rec?.status ?? null,
          remarks: rec?.remarks ?? null,
          attendanceId: rec?.id ?? null,
        };
      }),
    };
  }

  /**
   * Idempotent bulk mark. The @@unique([studentId, date]) constraint means a
   * student can never have two records for one day - re-submitting simply
   * updates. A student already marked that day *in a different batch* is
   * rejected so the two batches don't silently overwrite each other.
   */
  async mark(dto: MarkAttendanceDto, markedById: string) {
    const date = toDateOnly(dto.date);

    if (date.getTime() > toDateOnly(new Date()).getTime()) {
      throw new BadRequestException('Cannot mark attendance for a future date');
    }

    const batch = await this.prisma.batch.findUnique({
      where: { id: dto.batchId },
    });
    if (!batch) throw new NotFoundException('Batch not found');

    const studentIds = dto.entries.map((e) => e.studentId);
    const duplicates = studentIds.filter(
      (id, i) => studentIds.indexOf(id) !== i,
    );
    if (duplicates.length) {
      throw new BadRequestException(
        'The same student appears more than once in this submission',
      );
    }

    const students = await this.prisma.student.findMany({
      where: { id: { in: studentIds } },
      select: { id: true, name: true, batchId: true, isActive: true },
    });
    if (students.length !== studentIds.length) {
      throw new BadRequestException('One or more students no longer exist');
    }
    const notInBatch = students.filter((s) => s.batchId !== dto.batchId);
    if (notInBatch.length) {
      throw new BadRequestException(
        `${notInBatch[0].name} is not in this batch`,
      );
    }
    const inactive = students.filter((s) => !s.isActive);
    if (inactive.length) {
      throw new BadRequestException(
        `${inactive[0].name} is deactivated and cannot be marked`,
      );
    }

    const clashes = await this.prisma.attendance.findMany({
      where: {
        studentId: { in: studentIds },
        date,
        batchId: { not: dto.batchId },
      },
      include: { student: { select: { name: true } }, batch: { select: { name: true } } },
    });
    if (clashes.length) {
      throw new BadRequestException(
        `${clashes[0].student.name} is already marked on ${ymd(date)} in batch "${clashes[0].batch.name}"`,
      );
    }

    const results = await this.prisma.$transaction(
      dto.entries.map((e) =>
        this.prisma.attendance.upsert({
          where: { student_date_unique: { studentId: e.studentId, date } },
          create: {
            studentId: e.studentId,
            batchId: dto.batchId,
            date,
            status: e.status,
            remarks: e.remarks ?? null,
            markedById,
          },
          update: {
            status: e.status,
            remarks: e.remarks ?? null,
            batchId: dto.batchId,
            markedById,
          },
        }),
      ),
    );

    const summary = results.reduce<Record<string, number>>((acc, r) => {
      acc[r.status] = (acc[r.status] ?? 0) + 1;
      return acc;
    }, {});

    return {
      message: `Attendance saved for ${results.length} student(s)`,
      date: ymd(date),
      batchId: dto.batchId,
      summary,
    };
  }

  async history(query: AttendanceHistoryQueryDto) {
    const where: Prisma.AttendanceWhereInput = {
      ...(query.batchId ? { batchId: query.batchId } : {}),
      ...(query.studentId ? { studentId: query.studentId } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(query.from || query.to
        ? {
            date: {
              ...(query.from ? { gte: toDateOnly(query.from) } : {}),
              ...(query.to ? { lte: toDateOnly(query.to) } : {}),
            },
          }
        : {}),
    };

    const rows = await this.prisma.attendance.findMany({
      where,
      include: {
        student: { select: { id: true, name: true, studentCode: true } },
        batch: { select: { id: true, name: true, subject: true } },
      },
      orderBy: [{ date: 'desc' }, { student: { name: 'asc' } }],
      take: 500,
    });

    return rows.map((r) => ({ ...r, date: ymd(r.date) }));
  }

  /** Day-by-day roll-up for a batch, used by the admin history screen. */
  async batchDays(batchId: string, from?: string, to?: string) {
    const rows = await this.prisma.attendance.findMany({
      where: {
        batchId,
        ...(from || to
          ? {
              date: {
                ...(from ? { gte: toDateOnly(from) } : {}),
                ...(to ? { lte: toDateOnly(to) } : {}),
              },
            }
          : {}),
      },
      orderBy: { date: 'desc' },
      select: { date: true, status: true },
    });

    const map = new Map<
      string,
      { date: string; PRESENT: number; ABSENT: number; LATE: number; LEAVE: number; total: number }
    >();
    for (const r of rows) {
      const key = ymd(r.date);
      const cur =
        map.get(key) ??
        { date: key, PRESENT: 0, ABSENT: 0, LATE: 0, LEAVE: 0, total: 0 };
      cur[r.status] += 1;
      cur.total += 1;
      map.set(key, cur);
    }

    return [...map.values()].map((d) => {
      const considered = d.total - d.LEAVE;
      return {
        ...d,
        percentage:
          considered > 0
            ? Number((((d.PRESENT + d.LATE) / considered) * 100).toFixed(1))
            : 0,
      };
    });
  }

  /** Per-student stats + recent records. Students may only see their own. */
  async studentReport(
    studentId: string,
    requester: { role: string; studentId?: string | null },
  ) {
    if (requester.role === 'STUDENT' && requester.studentId !== studentId) {
      throw new ForbiddenException('You can only view your own attendance');
    }

    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      select: { id: true, name: true, studentCode: true },
    });
    if (!student) throw new NotFoundException('Student not found');

    const records = await this.prisma.attendance.findMany({
      where: { studentId },
      include: { batch: { select: { name: true, subject: true } } },
      orderBy: { date: 'desc' },
      take: 120,
    });

    const counts = { PRESENT: 0, ABSENT: 0, LATE: 0, LEAVE: 0 };
    const all = await this.prisma.attendance.groupBy({
      by: ['status'],
      where: { studentId },
      _count: { _all: true },
    });
    for (const g of all) counts[g.status] = g._count._all;

    const total = Object.values(counts).reduce((a, b) => a + b, 0);
    const considered = total - counts.LEAVE;
    const attended = counts.PRESENT + counts.LATE;

    return {
      student,
      summary: {
        ...counts,
        total,
        percentage:
          considered > 0 ? Number(((attended / considered) * 100).toFixed(1)) : 0,
      },
      records: records.map((r) => ({
        id: r.id,
        date: ymd(r.date),
        status: r.status,
        remarks: r.remarks,
        batch: r.batch,
      })),
    };
  }

  async updateOne(
    id: string,
    status: AttendanceStatus,
    remarks: string | undefined,
    markedById: string,
  ) {
    const found = await this.prisma.attendance.findUnique({ where: { id } });
    if (!found) throw new NotFoundException('Attendance record not found');
    const updated = await this.prisma.attendance.update({
      where: { id },
      data: { status, remarks: remarks ?? null, markedById },
    });
    return { ...updated, date: ymd(updated.date) };
  }

  async remove(id: string) {
    const found = await this.prisma.attendance.findUnique({ where: { id } });
    if (!found) throw new NotFoundException('Attendance record not found');
    await this.prisma.attendance.delete({ where: { id } });
    return { message: 'Attendance record removed' };
  }
}
