import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FeeStatus, Prisma, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuthService } from '../auth/auth.service';
import { paginate } from '../common/dto/pagination.dto';
import {
  CreateStudentDto,
  QueryStudentsDto,
  UpdateStudentDto,
} from './dto/student.dto';

const studentInclude = {
  batch: {
    select: {
      id: true,
      name: true,
      course: true,
      subject: true,
      timing: true,
      room: true,
    },
  },
  user: { select: { id: true, email: true, isActive: true, lastLoginAt: true } },
} satisfies Prisma.StudentInclude;

@Injectable()
export class StudentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  async findAll(query: QueryStudentsDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const search = query.search?.trim();

    const where: Prisma.StudentWhereInput = {
      ...(query.batchId ? { batchId: query.batchId } : {}),
      ...(query.course ? { course: query.course } : {}),
      ...(query.isActive !== undefined ? { isActive: query.isActive } : {}),
      ...(search
        ? {
            OR: [
              { name: { contains: search, mode: 'insensitive' } },
              { studentCode: { contains: search, mode: 'insensitive' } },
              { phone: { contains: search } },
              { email: { contains: search, mode: 'insensitive' } },
              { parentName: { contains: search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [rows, total] = await this.prisma.$transaction([
      this.prisma.student.findMany({
        where,
        include: studentInclude,
        orderBy: [{ isActive: 'desc' }, { name: 'asc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.student.count({ where }),
    ]);

    return paginate(rows, total, page, limit);
  }

  async findOne(id: string) {
    const student = await this.prisma.student.findUnique({
      where: { id },
      include: studentInclude,
    });
    if (!student) throw new NotFoundException('Student not found');

    const [attendance, fees] = await Promise.all([
      this.attendanceSummary(id),
      this.feeSummary(id),
    ]);

    return { ...student, attendanceSummary: attendance, feeSummary: fees };
  }

  async create(dto: CreateStudentDto) {
    const email = dto.email.toLowerCase().trim();

    const existingUser = await this.prisma.user.findUnique({
      where: { email },
    });
    if (existingUser) {
      throw new BadRequestException(
        'A user with this email already exists. Use a different email.',
      );
    }

    if (dto.batchId) await this.assertBatchExists(dto.batchId);

    const studentCode =
      dto.studentCode?.trim() || (await this.nextStudentCode());

    const password =
      dto.password ?? this.config.get<string>('SEED_STUDENT_PASSWORD') ?? 'Student@123';

    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          email,
          name: dto.name,
          phone: dto.phone,
          role: Role.STUDENT,
          passwordHash: await AuthService.hashPassword(password),
        },
      });

      return tx.student.create({
        data: {
          userId: user.id,
          studentCode,
          name: dto.name,
          phone: dto.phone,
          email,
          parentName: dto.parentName,
          parentPhone: dto.parentPhone,
          address: dto.address,
          course: dto.course,
          batchId: dto.batchId ?? null,
          admissionDate: dto.admissionDate
            ? new Date(dto.admissionDate)
            : new Date(),
          notes: dto.notes ?? null,
        },
        include: studentInclude,
      });
    });
  }

  async update(id: string, dto: UpdateStudentDto) {
    const student = await this.prisma.student.findUnique({ where: { id } });
    if (!student) throw new NotFoundException('Student not found');

    if (dto.batchId) await this.assertBatchExists(dto.batchId);

    const email = dto.email ? dto.email.toLowerCase().trim() : undefined;
    if (email && email !== student.email) {
      const taken = await this.prisma.user.findFirst({
        where: { email, NOT: { id: student.userId } },
      });
      if (taken) throw new BadRequestException('That email is already in use');
    }

    return this.prisma.$transaction(async (tx) => {
      if (dto.name || dto.phone || email || dto.isActive !== undefined) {
        await tx.user.update({
          where: { id: student.userId },
          data: {
            ...(dto.name ? { name: dto.name } : {}),
            ...(dto.phone ? { phone: dto.phone } : {}),
            ...(email ? { email } : {}),
            ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
          },
        });
      }

      return tx.student.update({
        where: { id },
        data: {
          ...(dto.name ? { name: dto.name } : {}),
          ...(dto.studentCode ? { studentCode: dto.studentCode } : {}),
          ...(dto.phone ? { phone: dto.phone } : {}),
          ...(email ? { email } : {}),
          ...(dto.parentName ? { parentName: dto.parentName } : {}),
          ...(dto.parentPhone ? { parentPhone: dto.parentPhone } : {}),
          ...(dto.address ? { address: dto.address } : {}),
          ...(dto.course ? { course: dto.course } : {}),
          ...(dto.batchId !== undefined ? { batchId: dto.batchId || null } : {}),
          ...(dto.admissionDate
            ? { admissionDate: new Date(dto.admissionDate) }
            : {}),
          ...(dto.notes !== undefined ? { notes: dto.notes } : {}),
          ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        },
        include: studentInclude,
      });
    });
  }

  /** Soft delete: keeps history, blocks login. */
  async setActive(id: string, isActive: boolean) {
    const student = await this.prisma.student.findUnique({ where: { id } });
    if (!student) throw new NotFoundException('Student not found');

    await this.prisma.$transaction([
      this.prisma.student.update({ where: { id }, data: { isActive } }),
      this.prisma.user.update({
        where: { id: student.userId },
        data: { isActive, ...(isActive ? {} : { refreshToken: null }) },
      }),
    ]);

    return {
      message: isActive
        ? 'Student reactivated'
        : 'Student deactivated. Their history is preserved.',
    };
  }

  async remove(id: string) {
    const student = await this.prisma.student.findUnique({ where: { id } });
    if (!student) throw new NotFoundException('Student not found');
    // Cascades to student + all related rows via User -> Student.
    await this.prisma.user.delete({ where: { id: student.userId } });
    return { message: 'Student deleted permanently' };
  }

  async attendanceSummary(studentId: string) {
    const grouped = await this.prisma.attendance.groupBy({
      by: ['status'],
      where: { studentId },
      _count: { _all: true },
    });

    const counts = { PRESENT: 0, ABSENT: 0, LATE: 0, LEAVE: 0 };
    for (const g of grouped) counts[g.status] = g._count._all;

    const total = Object.values(counts).reduce((a, b) => a + b, 0);
    // Late still counts as attended.
    const attended = counts.PRESENT + counts.LATE;
    const considered = total - counts.LEAVE;

    return {
      ...counts,
      total,
      percentage:
        considered > 0
          ? Number(((attended / considered) * 100).toFixed(1))
          : 0,
    };
  }

  async feeSummary(studentId: string) {
    const fees = await this.prisma.fee.findMany({ where: { studentId } });
    const totalFee = fees.reduce((s, f) => s + Number(f.totalAmount), 0);
    const paid = fees.reduce((s, f) => s + Number(f.paidAmount), 0);
    const now = new Date();
    const overdue = fees
      .filter((f) => f.status !== FeeStatus.PAID && f.dueDate < now)
      .reduce((s, f) => s + (Number(f.totalAmount) - Number(f.paidAmount)), 0);

    return {
      totalFee: Number(totalFee.toFixed(2)),
      paid: Number(paid.toFixed(2)),
      due: Number((totalFee - paid).toFixed(2)),
      overdue: Number(overdue.toFixed(2)),
      installments: fees.length,
    };
  }

  private async assertBatchExists(batchId: string) {
    const batch = await this.prisma.batch.findUnique({ where: { id: batchId } });
    if (!batch) throw new BadRequestException('Selected batch does not exist');
  }

  private async nextStudentCode() {
    const year = new Date().getFullYear();
    const prefix = `BP${year}`;
    const last = await this.prisma.student.findFirst({
      where: { studentCode: { startsWith: prefix } },
      orderBy: { studentCode: 'desc' },
      select: { studentCode: true },
    });
    const seq = last ? Number(last.studentCode.slice(prefix.length)) + 1 : 1;
    return `${prefix}${String(seq).padStart(3, '0')}`;
  }
}
