import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AnnouncementAudience, AttendanceStatus, FeeStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { FeesService } from '../fees/fees.service';
import { TimetableService } from '../timetable/timetable.service';

function todayUtc(): Date {
  const n = new Date();
  return new Date(Date.UTC(n.getUTCFullYear(), n.getUTCMonth(), n.getUTCDate()));
}

@Injectable()
export class DashboardService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly fees: FeesService,
    private readonly timetable: TimetableService,
  ) {}

  async admin() {
    // Keep OVERDUE accurate before reporting on it.
    await this.fees.refreshOverdue();

    const today = todayUtc();

    const [
      totalStudents,
      activeStudents,
      totalBatches,
      activeBatches,
      todayGrouped,
      feeAgg,
      pendingFees,
      overdueCount,
      announcements,
      upcomingExams,
      materialCount,
    ] = await Promise.all([
      this.prisma.student.count(),
      this.prisma.student.count({ where: { isActive: true } }),
      this.prisma.batch.count(),
      this.prisma.batch.count({ where: { isActive: true } }),
      this.prisma.attendance.groupBy({
        by: ['status'],
        where: { date: today },
        _count: { _all: true },
      }),
      this.prisma.fee.aggregate({
        _sum: { totalAmount: true, paidAmount: true },
      }),
      this.prisma.fee.count({
        where: { status: { in: [FeeStatus.PENDING, FeeStatus.PARTIAL, FeeStatus.OVERDUE] } },
      }),
      this.prisma.fee.count({ where: { status: FeeStatus.OVERDUE } }),
      this.prisma.announcement.findMany({
        include: {
          batch: { select: { id: true, name: true } },
          author: { select: { name: true } },
        },
        orderBy: [{ isPinned: 'desc' }, { createdAt: 'desc' }],
        take: 5,
      }),
      this.prisma.exam.findMany({
        where: { examDate: { gte: new Date() } },
        include: { batch: { select: { name: true } } },
        orderBy: { examDate: 'asc' },
        take: 5,
      }),
      this.prisma.studyMaterial.count(),
    ]);

    const counts = { PRESENT: 0, ABSENT: 0, LATE: 0, LEAVE: 0 };
    for (const g of todayGrouped) counts[g.status] = g._count._all;
    const markedToday = Object.values(counts).reduce((a, b) => a + b, 0);
    const consideredToday = markedToday - counts.LEAVE;

    const totalFee = Number(feeAgg._sum.totalAmount ?? 0);
    const collected = Number(feeAgg._sum.paidAmount ?? 0);

    const overdueSum = await this.prisma.fee.findMany({
      where: { status: FeeStatus.OVERDUE },
      select: { totalAmount: true, paidAmount: true },
    });
    const overdueAmount = overdueSum.reduce(
      (s, f) => s + (Number(f.totalAmount) - Number(f.paidAmount)),
      0,
    );

    return {
      students: {
        total: totalStudents,
        active: activeStudents,
        inactive: totalStudents - activeStudents,
      },
      batches: { total: totalBatches, active: activeBatches },
      todayAttendance: {
        date: today.toISOString().slice(0, 10),
        ...counts,
        marked: markedToday,
        expected: activeStudents,
        percentage:
          consideredToday > 0
            ? Number(
                (((counts.PRESENT + counts.LATE) / consideredToday) * 100).toFixed(1),
              )
            : 0,
        isMarked: markedToday > 0,
      },
      fees: {
        totalFee: Number(totalFee.toFixed(2)),
        collected: Number(collected.toFixed(2)),
        pending: Number((totalFee - collected).toFixed(2)),
        overdueAmount: Number(overdueAmount.toFixed(2)),
        pendingInstallments: pendingFees,
        overdueInstallments: overdueCount,
        collectionRate:
          totalFee > 0 ? Number(((collected / totalFee) * 100).toFixed(1)) : 0,
      },
      recentAnnouncements: announcements,
      upcomingExams,
      materialCount,
    };
  }

  async student(studentId: string | null | undefined) {
    if (!studentId) {
      throw new BadRequestException('No student profile linked to this account');
    }

    await this.fees.refreshOverdue();

    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      include: {
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
      },
    });
    if (!student) throw new NotFoundException('Student profile not found');

    const today = todayUtc();

    const [attGrouped, todayRecord, fees, announcements, results, materials] =
      await Promise.all([
        this.prisma.attendance.groupBy({
          by: ['status'],
          where: { studentId },
          _count: { _all: true },
        }),
        this.prisma.attendance.findUnique({
          where: { student_date_unique: { studentId, date: today } },
        }),
        this.prisma.fee.findMany({
          where: { studentId },
          orderBy: { dueDate: 'asc' },
        }),
        this.prisma.announcement.findMany({
          where: {
            OR: [
              { audience: AnnouncementAudience.ALL },
              ...(student.batchId
                ? [
                    {
                      audience: AnnouncementAudience.BATCH,
                      batchId: student.batchId,
                    },
                  ]
                : []),
            ],
          },
          include: { batch: { select: { name: true } } },
          orderBy: [{ isPinned: 'desc' }, { createdAt: 'desc' }],
          take: 5,
        }),
        this.prisma.examResult.findMany({
          where: { studentId, exam: { isPublished: true } },
          include: {
            exam: { select: { id: true, name: true, examDate: true } },
          },
          orderBy: { exam: { examDate: 'desc' } },
          take: 3,
        }),
        this.prisma.studyMaterial.count({
          where: student.batchId
            ? { OR: [{ batchId: student.batchId }, { batchId: null }] }
            : { batchId: null },
        }),
      ]);

    const counts = { PRESENT: 0, ABSENT: 0, LATE: 0, LEAVE: 0 };
    for (const g of attGrouped) counts[g.status] = g._count._all;
    const total = Object.values(counts).reduce((a, b) => a + b, 0);
    const considered = total - counts.LEAVE;

    const totalFee = fees.reduce((s, f) => s + Number(f.totalAmount), 0);
    const paid = fees.reduce((s, f) => s + Number(f.paidAmount), 0);
    const nextDue = fees.find((f) => f.status !== FeeStatus.PAID);
    const overdue = fees
      .filter((f) => f.status === FeeStatus.OVERDUE)
      .reduce((s, f) => s + (Number(f.totalAmount) - Number(f.paidAmount)), 0);

    const nextClass = student.batchId
      ? await this.timetable.nextClass(student.batchId)
      : null;

    return {
      student: {
        id: student.id,
        name: student.name,
        studentCode: student.studentCode,
        course: student.course,
        batch: student.batch,
        admissionDate: student.admissionDate,
      },
      attendance: {
        ...counts,
        total,
        percentage:
          considered > 0
            ? Number((((counts.PRESENT + counts.LATE) / considered) * 100).toFixed(1))
            : 0,
        todayStatus: (todayRecord?.status as AttendanceStatus) ?? null,
      },
      fees: {
        totalFee: Number(totalFee.toFixed(2)),
        paid: Number(paid.toFixed(2)),
        due: Number((totalFee - paid).toFixed(2)),
        overdue: Number(overdue.toFixed(2)),
        nextDueDate: nextDue?.dueDate ?? null,
        nextDueAmount: nextDue
          ? Number(
              (Number(nextDue.totalAmount) - Number(nextDue.paidAmount)).toFixed(2),
            )
          : 0,
        nextDueTitle: nextDue?.title ?? null,
      },
      nextClass,
      recentAnnouncements: announcements,
      recentResults: results.map((r) => ({
        id: r.id,
        exam: r.exam,
        obtained: Number(r.obtained),
        totalMarks: r.totalMarks,
        percentage: Number(r.percentage),
        grade: r.grade,
        rank: r.rank,
      })),
      materialCount: materials,
    };
  }
}
