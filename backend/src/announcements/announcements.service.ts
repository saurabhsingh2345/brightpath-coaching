import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AnnouncementAudience, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  CreateAnnouncementDto,
  UpdateAnnouncementDto,
} from './dto/announcement.dto';

const include = {
  batch: { select: { id: true, name: true } },
  author: { select: { id: true, name: true } },
} satisfies Prisma.AnnouncementInclude;

@Injectable()
export class AnnouncementsService {
  constructor(private readonly prisma: PrismaService) {}

  findAll(filters: { batchId?: string; search?: string; take?: number }) {
    const search = filters.search?.trim();
    return this.prisma.announcement.findMany({
      where: {
        ...(filters.batchId ? { batchId: filters.batchId } : {}),
        ...(search
          ? {
              OR: [
                { title: { contains: search, mode: 'insensitive' } },
                { body: { contains: search, mode: 'insensitive' } },
              ],
            }
          : {}),
      },
      include,
      orderBy: [{ isPinned: 'desc' }, { createdAt: 'desc' }],
      take: filters.take ?? 100,
    });
  }

  /** ALL announcements + the ones targeting this student's batch. */
  async forStudent(studentId: string, take = 50) {
    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      select: { batchId: true },
    });
    if (!student) throw new NotFoundException('Student not found');

    return this.prisma.announcement.findMany({
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
      include,
      orderBy: [{ isPinned: 'desc' }, { createdAt: 'desc' }],
      take,
    });
  }

  async findOne(id: string) {
    const found = await this.prisma.announcement.findUnique({
      where: { id },
      include,
    });
    if (!found) throw new NotFoundException('Announcement not found');
    return found;
  }

  async create(dto: CreateAnnouncementDto, authorId: string) {
    const batchId = await this.resolveBatch(dto.audience, dto.batchId);
    return this.prisma.announcement.create({
      data: {
        title: dto.title,
        body: dto.body,
        audience: dto.audience,
        batchId,
        isPinned: dto.isPinned ?? false,
        authorId,
      },
      include,
    });
  }

  async update(id: string, dto: UpdateAnnouncementDto) {
    const existing = await this.findOne(id);
    const audience = dto.audience ?? existing.audience;
    const batchId =
      dto.audience !== undefined || dto.batchId !== undefined
        ? await this.resolveBatch(
            audience,
            dto.batchId ?? existing.batchId ?? undefined,
          )
        : existing.batchId;

    return this.prisma.announcement.update({
      where: { id },
      data: {
        ...(dto.title ? { title: dto.title } : {}),
        ...(dto.body ? { body: dto.body } : {}),
        audience,
        batchId,
        ...(dto.isPinned !== undefined ? { isPinned: dto.isPinned } : {}),
      },
      include,
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.announcement.delete({ where: { id } });
    return { message: 'Announcement deleted' };
  }

  private async resolveBatch(
    audience: AnnouncementAudience,
    batchId?: string | null,
  ) {
    if (audience === AnnouncementAudience.ALL) return null;
    if (!batchId) {
      throw new BadRequestException(
        'Pick a batch when sending to a specific batch',
      );
    }
    const batch = await this.prisma.batch.findUnique({
      where: { id: batchId },
    });
    if (!batch) throw new BadRequestException('Selected batch does not exist');
    return batchId;
  }
}
