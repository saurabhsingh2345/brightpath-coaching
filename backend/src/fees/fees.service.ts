import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { FeeStatus, PaymentMode, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { paginate } from '../common/dto/pagination.dto';
import { AuthUser } from '../common/decorators/current-user.decorator';
import {
  CreateFeeDto,
  CreateFeePlanDto,
  QueryFeesDto,
  RecordPaymentDto,
  UpdateFeeDto,
} from './dto/fee.dto';

const money = (v: Prisma.Decimal | number) => Number(Number(v).toFixed(2));

@Injectable()
export class FeesService {
  constructor(private readonly prisma: PrismaService) {}

  /** Derive status from amounts + due date. Single source of truth. */
  private computeStatus(
    total: number,
    paid: number,
    dueDate: Date,
  ): FeeStatus {
    if (paid >= total) return FeeStatus.PAID;
    const overdue = dueDate.getTime() < Date.now();
    if (paid > 0) return overdue ? FeeStatus.OVERDUE : FeeStatus.PARTIAL;
    return overdue ? FeeStatus.OVERDUE : FeeStatus.PENDING;
  }

  private shape(fee: any) {
    const total = money(fee.totalAmount);
    const paid = money(fee.paidAmount);
    return {
      ...fee,
      totalAmount: total,
      paidAmount: paid,
      balance: money(total - paid),
      ...(fee.payments
        ? {
            payments: fee.payments.map((p: any) => ({
              ...p,
              amount: money(p.amount),
            })),
          }
        : {}),
    };
  }

  async findAll(query: QueryFeesDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const search = query.search?.trim();

    const where: Prisma.FeeWhereInput = {
      ...(query.studentId ? { studentId: query.studentId } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(query.batchId ? { student: { batchId: query.batchId } } : {}),
      ...(search
        ? {
            OR: [
              { title: { contains: search, mode: 'insensitive' } },
              { student: { name: { contains: search, mode: 'insensitive' } } },
              {
                student: {
                  studentCode: { contains: search, mode: 'insensitive' },
                },
              },
            ],
          }
        : {}),
    };

    const [rows, total] = await this.prisma.$transaction([
      this.prisma.fee.findMany({
        where,
        include: {
          student: {
            select: {
              id: true,
              name: true,
              studentCode: true,
              batch: { select: { id: true, name: true } },
            },
          },
          _count: { select: { payments: true } },
        },
        orderBy: [{ dueDate: 'asc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.fee.count({ where }),
    ]);

    return paginate(
      rows.map(({ _count, ...f }) =>
        this.shape({ ...f, paymentCount: _count.payments }),
      ),
      total,
      page,
      limit,
    );
  }

  async findOne(id: string, requester: AuthUser) {
    const fee = await this.prisma.fee.findUnique({
      where: { id },
      include: {
        student: {
          select: { id: true, name: true, studentCode: true, course: true },
        },
        payments: {
          orderBy: { paidAt: 'desc' },
          include: { recordedBy: { select: { name: true } } },
        },
      },
    });
    if (!fee) throw new NotFoundException('Fee record not found');
    if (requester.role === 'STUDENT' && requester.studentId !== fee.studentId) {
      throw new ForbiddenException('You can only view your own fees');
    }
    return this.shape(fee);
  }

  /** Full picture for one student: installments, payments, totals. */
  async studentFees(studentId: string, requester: AuthUser) {
    if (requester.role === 'STUDENT' && requester.studentId !== studentId) {
      throw new ForbiddenException('You can only view your own fees');
    }

    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      select: { id: true, name: true, studentCode: true, course: true },
    });
    if (!student) throw new NotFoundException('Student not found');

    const fees = await this.prisma.fee.findMany({
      where: { studentId },
      include: {
        payments: {
          orderBy: { paidAt: 'desc' },
          include: { recordedBy: { select: { name: true } } },
        },
      },
      orderBy: { dueDate: 'asc' },
    });

    const shaped = fees.map((f) => this.shape(f));
    const totalFee = shaped.reduce((s, f) => s + f.totalAmount, 0);
    const paid = shaped.reduce((s, f) => s + f.paidAmount, 0);
    const overdue = shaped
      .filter((f) => f.status === FeeStatus.OVERDUE)
      .reduce((s, f) => s + f.balance, 0);
    const nextDue = shaped.find((f) => f.status !== FeeStatus.PAID) ?? null;

    return {
      student,
      summary: {
        totalFee: money(totalFee),
        paid: money(paid),
        due: money(totalFee - paid),
        overdue: money(overdue),
        installments: shaped.length,
        paidInstallments: shaped.filter((f) => f.status === FeeStatus.PAID)
          .length,
        nextDueDate: nextDue?.dueDate ?? null,
        nextDueAmount: nextDue ? nextDue.balance : 0,
      },
      fees: shaped,
    };
  }

  async createPlan(dto: CreateFeePlanDto) {
    const student = await this.prisma.student.findUnique({
      where: { id: dto.studentId },
    });
    if (!student) throw new BadRequestException('Student does not exist');

    const total = dto.installments.length;
    const created = await this.prisma.$transaction(
      dto.installments.map((inst, i) =>
        this.prisma.fee.create({
          data: {
            studentId: dto.studentId,
            title: inst.title,
            totalAmount: new Prisma.Decimal(inst.amount),
            dueDate: new Date(inst.dueDate),
            installmentNo: i + 1,
            totalInstallments: total,
            notes: dto.notes ?? null,
            status: this.computeStatus(inst.amount, 0, new Date(inst.dueDate)),
          },
        }),
      ),
    );
    return {
      message: `${created.length} installment(s) created`,
      fees: created.map((f) => this.shape(f)),
    };
  }

  async create(dto: CreateFeeDto) {
    const student = await this.prisma.student.findUnique({
      where: { id: dto.studentId },
    });
    if (!student) throw new BadRequestException('Student does not exist');

    const dueDate = new Date(dto.dueDate);
    const fee = await this.prisma.fee.create({
      data: {
        studentId: dto.studentId,
        title: dto.title,
        totalAmount: new Prisma.Decimal(dto.totalAmount),
        dueDate,
        installmentNo: dto.installmentNo ?? 1,
        totalInstallments: dto.totalInstallments ?? 1,
        notes: dto.notes ?? null,
        status: this.computeStatus(dto.totalAmount, 0, dueDate),
      },
    });
    return this.shape(fee);
  }

  async update(id: string, dto: UpdateFeeDto) {
    const fee = await this.prisma.fee.findUnique({ where: { id } });
    if (!fee) throw new NotFoundException('Fee record not found');

    const paid = money(fee.paidAmount);
    const newTotal = dto.totalAmount ?? money(fee.totalAmount);
    if (newTotal < paid) {
      throw new BadRequestException(
        `Total cannot be less than the ₹${paid} already paid`,
      );
    }
    const dueDate = dto.dueDate ? new Date(dto.dueDate) : fee.dueDate;

    const updated = await this.prisma.fee.update({
      where: { id },
      data: {
        ...(dto.title ? { title: dto.title } : {}),
        ...(dto.totalAmount !== undefined
          ? { totalAmount: new Prisma.Decimal(dto.totalAmount) }
          : {}),
        ...(dto.dueDate ? { dueDate } : {}),
        ...(dto.installmentNo ? { installmentNo: dto.installmentNo } : {}),
        ...(dto.totalInstallments
          ? { totalInstallments: dto.totalInstallments }
          : {}),
        ...(dto.notes !== undefined ? { notes: dto.notes } : {}),
        status: this.computeStatus(newTotal, paid, dueDate),
      },
    });
    return this.shape(updated);
  }

  async remove(id: string) {
    const fee = await this.prisma.fee.findUnique({
      where: { id },
      include: { _count: { select: { payments: true } } },
    });
    if (!fee) throw new NotFoundException('Fee record not found');
    if (fee._count.payments > 0) {
      throw new BadRequestException(
        'This fee already has payments recorded and cannot be deleted.',
      );
    }
    await this.prisma.fee.delete({ where: { id } });
    return { message: 'Fee record deleted' };
  }

  /** Record a (possibly partial) payment and roll the fee status forward. */
  async recordPayment(
    feeId: string,
    dto: RecordPaymentDto,
    recordedById: string,
  ) {
    return this.prisma.$transaction(async (tx) => {
      const fee = await tx.fee.findUnique({ where: { id: feeId } });
      if (!fee) throw new NotFoundException('Fee record not found');

      const total = money(fee.totalAmount);
      const paid = money(fee.paidAmount);
      const balance = money(total - paid);

      if (balance <= 0) {
        throw new BadRequestException('This installment is already fully paid');
      }
      if (dto.amount > balance) {
        throw new BadRequestException(
          `Payment exceeds the remaining balance of ₹${balance}`,
        );
      }

      const receiptNo = await this.nextReceiptNo(tx);
      const payment = await tx.feePayment.create({
        data: {
          feeId,
          amount: new Prisma.Decimal(dto.amount),
          mode: dto.mode ?? PaymentMode.CASH,
          reference: dto.reference ?? null,
          paidAt: dto.paidAt ? new Date(dto.paidAt) : new Date(),
          receiptNo,
          recordedById,
        },
      });

      const newPaid = money(paid + dto.amount);
      const updated = await tx.fee.update({
        where: { id: feeId },
        data: {
          paidAmount: new Prisma.Decimal(newPaid),
          status: this.computeStatus(total, newPaid, fee.dueDate),
        },
      });

      return {
        message: `Payment of ₹${dto.amount} recorded. Receipt ${receiptNo}.`,
        payment: { ...payment, amount: money(payment.amount) },
        fee: this.shape(updated),
      };
    });
  }

  async payments(query: { studentId?: string; feeId?: string }) {
    const rows = await this.prisma.feePayment.findMany({
      where: {
        ...(query.feeId ? { feeId: query.feeId } : {}),
        ...(query.studentId ? { fee: { studentId: query.studentId } } : {}),
      },
      include: {
        fee: {
          select: {
            id: true,
            title: true,
            student: { select: { id: true, name: true, studentCode: true } },
          },
        },
        recordedBy: { select: { name: true } },
      },
      orderBy: { paidAt: 'desc' },
      take: 300,
    });
    return rows.map((p) => ({ ...p, amount: money(p.amount) }));
  }

  /** Data for a printable/shareable receipt. */
  async receipt(paymentId: string, requester: AuthUser) {
    const payment = await this.prisma.feePayment.findUnique({
      where: { id: paymentId },
      include: {
        recordedBy: { select: { name: true } },
        fee: {
          include: {
            student: {
              select: {
                id: true,
                name: true,
                studentCode: true,
                course: true,
                phone: true,
                parentName: true,
                batch: { select: { name: true } },
              },
            },
          },
        },
      },
    });
    if (!payment) throw new NotFoundException('Payment not found');
    if (
      requester.role === 'STUDENT' &&
      requester.studentId !== payment.fee.studentId
    ) {
      throw new ForbiddenException('You can only view your own receipts');
    }

    const total = money(payment.fee.totalAmount);
    const paid = money(payment.fee.paidAmount);

    return {
      institute: 'BrightPath Coaching',
      receiptNo: payment.receiptNo,
      paidAt: payment.paidAt,
      amount: money(payment.amount),
      mode: payment.mode,
      reference: payment.reference,
      recordedBy: payment.recordedBy?.name ?? 'System',
      student: payment.fee.student,
      fee: {
        id: payment.fee.id,
        title: payment.fee.title,
        installment: `${payment.fee.installmentNo} of ${payment.fee.totalInstallments}`,
        totalAmount: total,
        paidAmount: paid,
        balance: money(total - paid),
        dueDate: payment.fee.dueDate,
        status: payment.fee.status,
      },
    };
  }

  /** Recompute OVERDUE flags. Cheap enough to call from the dashboard. */
  async refreshOverdue() {
    const result = await this.prisma.fee.updateMany({
      where: {
        dueDate: { lt: new Date() },
        status: { in: [FeeStatus.PENDING, FeeStatus.PARTIAL] },
      },
      data: { status: FeeStatus.OVERDUE },
    });
    return { updated: result.count };
  }

  private async nextReceiptNo(tx: Prisma.TransactionClient) {
    const year = new Date().getFullYear();
    const prefix = `BP-R${year}-`;
    const last = await tx.feePayment.findFirst({
      where: { receiptNo: { startsWith: prefix } },
      orderBy: { receiptNo: 'desc' },
      select: { receiptNo: true },
    });
    const seq = last ? Number(last.receiptNo.slice(prefix.length)) + 1 : 1;
    return `${prefix}${String(seq).padStart(4, '0')}`;
  }
}
