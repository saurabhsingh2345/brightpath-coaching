import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConversationType, MessageKind, Prisma, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../common/decorators/current-user.decorator';
import { MessagesQueryDto, SendMessageDto } from './dto/chat.dto';

/**
 * Chat rules for a coaching institute:
 *  - DIRECT threads always pair an ADMIN with a STUDENT. Students cannot
 *    message each other, which keeps moderation trivial.
 *  - BATCH threads contain every active student of the batch plus every admin,
 *    and are reconciled on read so newly-added students appear automatically.
 */
@Injectable()
export class ChatService {
  constructor(private readonly prisma: PrismaService) {}

  /** Order-independent key so a pair can only ever have one DIRECT thread. */
  private directKey(a: string, b: string) {
    return [a, b].sort().join(':');
  }

  private async assertParticipant(conversationId: string, userId: string) {
    const participant = await this.prisma.conversationParticipant.findUnique({
      where: {
        conversation_user_unique: { conversationId, userId },
      },
      include: { conversation: true },
    });
    if (!participant) {
      throw new ForbiddenException('You are not part of this conversation');
    }
    return participant;
  }

  /** Ids of everyone who should receive a live push for this conversation. */
  async participantIds(conversationId: string): Promise<string[]> {
    const rows = await this.prisma.conversationParticipant.findMany({
      where: { conversationId },
      select: { userId: true },
    });
    return rows.map((r) => r.userId);
  }

  // ── conversation list ───────────────────────────────────────

  async list(requester: AuthUser) {
    // Make sure the caller is in every batch thread they belong to before
    // listing, so a freshly-assigned student sees their batch chat.
    await this.syncBatchThreadsFor(requester);

    const rows = await this.prisma.conversationParticipant.findMany({
      where: { userId: requester.id },
      include: {
        conversation: {
          include: {
            batch: { select: { id: true, name: true } },
            participants: {
              include: {
                user: {
                  select: {
                    id: true,
                    name: true,
                    role: true,
                    student: { select: { studentCode: true } },
                  },
                },
              },
            },
          },
        },
      },
    });

    const shaped = await Promise.all(
      rows.map(async (p) => {
        const c = p.conversation;
        const unread = await this.prisma.message.count({
          where: {
            conversationId: c.id,
            senderId: { not: requester.id },
            deletedAt: null,
            ...(p.lastReadAt ? { createdAt: { gt: p.lastReadAt } } : {}),
          },
        });

        const others = c.participants
          .filter((x) => x.userId !== requester.id)
          .map((x) => ({
            id: x.user.id,
            name: x.user.name,
            role: x.user.role,
            studentCode: x.user.student?.studentCode ?? null,
          }));

        return {
          id: c.id,
          type: c.type,
          // DIRECT threads are named after the other person.
          title:
            c.type === ConversationType.BATCH
              ? (c.title ?? c.batch?.name ?? 'Batch chat')
              : (others[0]?.name ?? 'Conversation'),
          subtitle:
            c.type === ConversationType.BATCH
              ? `${c.participants.length} members`
              : (others[0]?.role === Role.ADMIN
                  ? 'Administrator'
                  : (others[0]?.studentCode ?? 'Student')),
          batch: c.batch,
          isLocked: c.isLocked,
          lastMessageAt: c.lastMessageAt,
          lastMessageText: c.lastMessageText,
          unreadCount: unread,
          participants: others,
          memberCount: c.participants.length,
        };
      }),
    );

    // Threads with activity first (newest), then untouched ones by name.
    shaped.sort((a, b) => {
      const at = a.lastMessageAt?.getTime() ?? 0;
      const bt = b.lastMessageAt?.getTime() ?? 0;
      if (at !== bt) return bt - at;
      return a.title.localeCompare(b.title);
    });

    return shaped;
  }

  async unreadTotal(userId: string) {
    const parts = await this.prisma.conversationParticipant.findMany({
      where: { userId },
      select: { conversationId: true, lastReadAt: true },
    });
    if (parts.length === 0) return { total: 0 };

    const counts = await Promise.all(
      parts.map((p) =>
        this.prisma.message.count({
          where: {
            conversationId: p.conversationId,
            senderId: { not: userId },
            deletedAt: null,
            ...(p.lastReadAt ? { createdAt: { gt: p.lastReadAt } } : {}),
          },
        }),
      ),
    );
    return { total: counts.reduce((a, b) => a + b, 0) };
  }

  // ── messages ────────────────────────────────────────────────

  async messages(
    conversationId: string,
    requester: AuthUser,
    query: MessagesQueryDto,
  ) {
    const participant = await this.assertParticipant(
      conversationId,
      requester.id,
    );
    const limit = query.limit ?? 40;

    const rows = await this.prisma.message.findMany({
      where: {
        conversationId,
        ...(query.before ? { createdAt: { lt: new Date(query.before) } } : {}),
      },
      include: {
        sender: { select: { id: true, name: true, role: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
    });

    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;

    return {
      conversation: {
        id: participant.conversation.id,
        type: participant.conversation.type,
        isLocked: participant.conversation.isLocked,
      },
      hasMore,
      // Oldest-first so the client can append straight into a list.
      messages: page.reverse().map((m) => this.shape(m, requester.id)),
    };
  }

  async send(
    conversationId: string,
    dto: SendMessageDto,
    requester: AuthUser,
  ) {
    const participant = await this.assertParticipant(
      conversationId,
      requester.id,
    );

    if (
      participant.conversation.isLocked &&
      requester.role !== Role.ADMIN
    ) {
      throw new ForbiddenException(
        'This conversation is read-only. Only staff can post here.',
      );
    }

    const body = dto.body.trim();
    if (!body) throw new BadRequestException('Message cannot be empty');

    const [message] = await this.prisma.$transaction([
      this.prisma.message.create({
        data: {
          conversationId,
          senderId: requester.id,
          body,
          kind: MessageKind.TEXT,
        },
        include: { sender: { select: { id: true, name: true, role: true } } },
      }),
      this.prisma.conversation.update({
        where: { id: conversationId },
        data: {
          lastMessageAt: new Date(),
          lastMessageText: body.length > 120 ? `${body.slice(0, 117)}…` : body,
        },
      }),
      // Sending implies you have read everything before it.
      this.prisma.conversationParticipant.update({
        where: {
          conversation_user_unique: { conversationId, userId: requester.id },
        },
        data: { lastReadAt: new Date() },
      }),
    ]);

    return this.shape(message, requester.id);
  }

  async markRead(conversationId: string, requester: AuthUser) {
    await this.assertParticipant(conversationId, requester.id);
    await this.prisma.conversationParticipant.update({
      where: {
        conversation_user_unique: { conversationId, userId: requester.id },
      },
      data: { lastReadAt: new Date() },
    });
    return { message: 'Marked as read' };
  }

  async deleteMessage(messageId: string, requester: AuthUser) {
    const message = await this.prisma.message.findUnique({
      where: { id: messageId },
    });
    if (!message) throw new NotFoundException('Message not found');
    if (message.senderId !== requester.id && requester.role !== Role.ADMIN) {
      throw new ForbiddenException('You can only delete your own messages');
    }
    const updated = await this.prisma.message.update({
      where: { id: messageId },
      data: { deletedAt: new Date(), body: '' },
      include: { sender: { select: { id: true, name: true, role: true } } },
    });
    return this.shape(updated, requester.id);
  }

  // ── starting conversations ──────────────────────────────────

  /**
   * Open (or create) the 1:1 thread between the requester and [otherUserId].
   * Enforces the admin<->student rule in both directions.
   */
  async startDirect(otherUserId: string, requester: AuthUser) {
    if (otherUserId === requester.id) {
      throw new BadRequestException('You cannot message yourself');
    }

    const other = await this.prisma.user.findUnique({
      where: { id: otherUserId },
      select: { id: true, name: true, role: true, isActive: true },
    });
    if (!other) throw new NotFoundException('That person no longer exists');
    if (!other.isActive) {
      throw new BadRequestException('That account has been deactivated');
    }
    if (requester.role === Role.STUDENT && other.role !== Role.ADMIN) {
      throw new ForbiddenException(
        'Students can only message institute staff',
      );
    }

    const directKey = this.directKey(requester.id, otherUserId);
    const existing = await this.prisma.conversation.findUnique({
      where: { directKey },
    });
    if (existing) return { id: existing.id, created: false };

    const created = await this.prisma.conversation.create({
      data: {
        type: ConversationType.DIRECT,
        directKey,
        participants: {
          create: [{ userId: requester.id }, { userId: otherUserId }],
        },
      },
    });
    return { id: created.id, created: true };
  }

  /** People the requester is allowed to start a new DIRECT thread with. */
  async contacts(requester: AuthUser, search?: string) {
    const term = search?.trim();
    const where: Prisma.UserWhereInput = {
      isActive: true,
      NOT: { id: requester.id },
      // Students may only reach admins; admins may reach anyone.
      ...(requester.role === Role.STUDENT ? { role: Role.ADMIN } : {}),
      ...(term
        ? {
            OR: [
              { name: { contains: term, mode: 'insensitive' } },
              { email: { contains: term, mode: 'insensitive' } },
              {
                student: {
                  studentCode: { contains: term, mode: 'insensitive' },
                },
              },
            ],
          }
        : {}),
    };

    const users = await this.prisma.user.findMany({
      where,
      select: {
        id: true,
        name: true,
        role: true,
        student: {
          select: {
            studentCode: true,
            batch: { select: { id: true, name: true } },
          },
        },
      },
      orderBy: [{ role: 'asc' }, { name: 'asc' }],
      take: 100,
    });

    return users.map((u) => ({
      id: u.id,
      name: u.name,
      role: u.role,
      studentCode: u.student?.studentCode ?? null,
      batchName: u.student?.batch?.name ?? null,
    }));
  }

  /** Ensure a batch thread exists and has the right membership. */
  async ensureBatchConversation(batchId: string) {
    const batch = await this.prisma.batch.findUnique({
      where: { id: batchId },
      select: {
        id: true,
        name: true,
        students: {
          where: { isActive: true },
          select: { userId: true },
        },
      },
    });
    if (!batch) throw new NotFoundException('Batch not found');

    let conversation = await this.prisma.conversation.findFirst({
      where: { type: ConversationType.BATCH, batchId },
    });

    if (!conversation) {
      conversation = await this.prisma.conversation.create({
        data: {
          type: ConversationType.BATCH,
          batchId,
          title: batch.name,
        },
      });
    } else if (conversation.title !== batch.name) {
      conversation = await this.prisma.conversation.update({
        where: { id: conversation.id },
        data: { title: batch.name },
      });
    }

    const admins = await this.prisma.user.findMany({
      where: { role: Role.ADMIN, isActive: true },
      select: { id: true },
    });

    const shouldBeIn = new Set<string>([
      ...admins.map((a) => a.id),
      ...batch.students.map((s) => s.userId),
    ]);

    const current = await this.prisma.conversationParticipant.findMany({
      where: { conversationId: conversation.id },
      select: { userId: true },
    });
    const currentIds = new Set(current.map((c) => c.userId));

    const toAdd = [...shouldBeIn].filter((id) => !currentIds.has(id));
    const toRemove = [...currentIds].filter((id) => !shouldBeIn.has(id));

    if (toAdd.length) {
      await this.prisma.conversationParticipant.createMany({
        data: toAdd.map((userId) => ({
          conversationId: conversation!.id,
          userId,
        })),
        skipDuplicates: true,
      });
    }
    if (toRemove.length) {
      await this.prisma.conversationParticipant.deleteMany({
        where: { conversationId: conversation.id, userId: { in: toRemove } },
      });
    }

    return conversation;
  }

  async setLocked(conversationId: string, isLocked: boolean) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    if (conversation.type !== ConversationType.BATCH) {
      throw new BadRequestException('Only batch chats can be locked');
    }
    await this.prisma.conversation.update({
      where: { id: conversationId },
      data: { isLocked },
    });
    return {
      message: isLocked
        ? 'Batch chat is now read-only for students'
        : 'Students can post in this batch chat again',
    };
  }

  /**
   * Reconcile the caller's batch-thread membership. Cheap: one batch for a
   * student, all active batches for an admin.
   */
  private async syncBatchThreadsFor(requester: AuthUser) {
    if (requester.role === Role.ADMIN) {
      const batches = await this.prisma.batch.findMany({
        where: { isActive: true },
        select: { id: true },
      });
      for (const b of batches) {
        await this.ensureBatchConversation(b.id);
      }
      return;
    }

    if (!requester.studentId) return;
    const student = await this.prisma.student.findUnique({
      where: { id: requester.studentId },
      select: { batchId: true },
    });
    if (student?.batchId) {
      await this.ensureBatchConversation(student.batchId);
    }
  }

  private shape(m: any, requesterId: string) {
    return {
      id: m.id,
      conversationId: m.conversationId,
      body: m.deletedAt ? 'This message was deleted' : m.body,
      kind: m.kind,
      isDeleted: m.deletedAt != null,
      isMine: m.senderId === requesterId,
      senderId: m.senderId,
      senderName: m.sender?.name ?? 'Unknown',
      senderRole: m.sender?.role ?? null,
      createdAt: m.createdAt,
      editedAt: m.editedAt,
    };
  }
}
