import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { ConversationType, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../common/decorators/current-user.decorator';

/**
 * Removes the seeded walkthrough data so an institute can start clean.
 *
 * Only rows flagged `isDemo` are touched, so anything the institute created
 * itself is untouchable by this operation - the worst case is that the demo
 * is removed twice.
 */
@Injectable()
export class MaintenanceService {
  private readonly logger = new Logger(MaintenanceService.name);

  constructor(private readonly prisma: PrismaService) {}

  /** What a clear would remove, so the UI can spell it out first. */
  async demoSummary() {
    const [students, batches, announcements, materials, admins] =
      await Promise.all([
        this.prisma.user.count({
          where: { isDemo: true, role: Role.STUDENT },
        }),
        this.prisma.batch.count({ where: { isDemo: true } }),
        this.prisma.announcement.count({ where: { isDemo: true } }),
        this.prisma.studyMaterial.count({ where: { isDemo: true } }),
        this.prisma.user.count({ where: { isDemo: true, role: Role.ADMIN } }),
      ]);

    const demoUserIds = (
      await this.prisma.user.findMany({
        where: { isDemo: true },
        select: { id: true },
      })
    ).map((u) => u.id);

    const [attendance, fees, exams, messages] = await Promise.all([
      this.prisma.attendance.count({
        where: { student: { user: { isDemo: true } } },
      }),
      this.prisma.fee.count({
        where: { student: { user: { isDemo: true } } },
      }),
      this.prisma.exam.count({ where: { batch: { isDemo: true } } }),
      demoUserIds.length
        ? this.prisma.message.count({
            where: { senderId: { in: demoUserIds } },
          })
        : Promise.resolve(0),
    ]);

    // What the institute has entered themselves. Shown alongside the removal
    // list so it is obvious this operation cannot touch it.
    const keeps = await this.ownSummary();

    return {
      hasDemoData: students + batches + announcements + materials + admins > 0,
      keeps,
      students,
      demoAdmins: admins,
      batches,
      announcements,
      materials,
      attendanceRecords: attendance,
      feeInstallments: fees,
      exams,
      chatMessages: messages,
    };
  }

  /**
   * Deletes every demo row. Relies on the schema's cascades for the children
   * (attendance, fees, exams, timetable, results) and explicitly removes the
   * direct chat threads, which hang off participants rather than a batch.
   */
  async clearDemoData(requester: AuthUser) {
    const summary = await this.demoSummary();
    if (!summary.hasDemoData) {
      throw new BadRequestException('There is no demo data left to remove.');
    }

    const demoUsers = await this.prisma.user.findMany({
      where: { isDemo: true, NOT: { id: requester.id } },
      select: { id: true },
    });
    const demoUserIds = demoUsers.map((u) => u.id);

    // A direct thread involving a demo account goes with them. Batch threads
    // cascade from the batch itself.
    const directThreads = demoUserIds.length
      ? await this.prisma.conversation.findMany({
          where: {
            type: ConversationType.DIRECT,
            participants: { some: { userId: { in: demoUserIds } } },
          },
          select: { id: true },
        })
      : [];

    await this.prisma.$transaction(async (tx) => {
      if (directThreads.length) {
        await tx.conversation.deleteMany({
          where: { id: { in: directThreads.map((c) => c.id) } },
        });
      }
      // Institute-wide demo rows have no batch to cascade from.
      await tx.announcement.deleteMany({ where: { isDemo: true } });
      await tx.studyMaterial.deleteMany({ where: { isDemo: true } });
      // Cascades timetable, exams + results, batch materials, batch threads.
      await tx.batch.deleteMany({ where: { isDemo: true } });
      // Cascades students -> attendance, fees + payments, exam results.
      if (demoUserIds.length) {
        await tx.user.deleteMany({ where: { id: { in: demoUserIds } } });
      }
    });

    this.logger.warn(
      `Demo data cleared by ${requester.email} (${demoUserIds.length} accounts)`,
    );

    const remaining = await this.instituteSummary();
    return {
      message: 'Demo data removed. The institute is ready for real records.',
      removed: {
        students: summary.students,
        batches: summary.batches,
        announcements: summary.announcements,
        materials: summary.materials,
        attendanceRecords: summary.attendanceRecords,
        feeInstallments: summary.feeInstallments,
        exams: summary.exams,
        accounts: demoUserIds.length,
      },
      remaining,
    };
  }

  /** Rows the institute created themselves - never touched by a clear. */
  async ownSummary() {
    const [admins, students, batches, announcements, materials] =
      await Promise.all([
        this.prisma.user.count({
          where: { isDemo: false, role: Role.ADMIN },
        }),
        this.prisma.student.count({ where: { user: { isDemo: false } } }),
        this.prisma.batch.count({ where: { isDemo: false } }),
        this.prisma.announcement.count({ where: { isDemo: false } }),
        this.prisma.studyMaterial.count({ where: { isDemo: false } }),
      ]);
    return { admins, students, batches, announcements, materials };
  }

  /** What is actually left after a clear - shown as reassurance. */
  async instituteSummary() {
    const [admins, students, batches] = await Promise.all([
      this.prisma.user.count({ where: { role: Role.ADMIN } }),
      this.prisma.student.count(),
      this.prisma.batch.count(),
    ]);
    return { admins, students, batches };
  }
}
