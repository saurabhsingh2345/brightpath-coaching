import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, Weekday } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  CreateTimetableSlotDto,
  UpdateTimetableSlotDto,
} from './dto/timetable.dto';

const WEEKDAYS: Weekday[] = [
  Weekday.SUNDAY,
  Weekday.MONDAY,
  Weekday.TUESDAY,
  Weekday.WEDNESDAY,
  Weekday.THURSDAY,
  Weekday.FRIDAY,
  Weekday.SATURDAY,
];

const toMinutes = (hhmm: string) => {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
};

@Injectable()
export class TimetableService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(batchId?: string, weekday?: Weekday) {
    const where: Prisma.TimetableSlotWhereInput = {
      ...(batchId ? { batchId } : {}),
      ...(weekday ? { weekday } : {}),
    };
    const rows = await this.prisma.timetableSlot.findMany({
      where,
      include: {
        batch: { select: { id: true, name: true, course: true, subject: true } },
      },
      orderBy: [{ weekday: 'asc' }, { startTime: 'asc' }],
    });
    return rows.map((r) => ({
      ...r,
      date: r.date ? r.date.toISOString().slice(0, 10) : null,
    }));
  }

  /** Slots grouped Monday..Sunday - what the mobile weekly view renders. */
  async weekly(batchId: string) {
    const batch = await this.prisma.batch.findUnique({
      where: { id: batchId },
      select: { id: true, name: true, course: true, room: true, timing: true },
    });
    if (!batch) throw new NotFoundException('Batch not found');

    const slots = await this.findAll(batchId);
    const order: Weekday[] = [
      Weekday.MONDAY,
      Weekday.TUESDAY,
      Weekday.WEDNESDAY,
      Weekday.THURSDAY,
      Weekday.FRIDAY,
      Weekday.SATURDAY,
      Weekday.SUNDAY,
    ];

    return {
      batch,
      days: order.map((day) => ({
        weekday: day,
        slots: slots
          .filter((s) => s.weekday === day)
          .sort((a, b) => toMinutes(a.startTime) - toMinutes(b.startTime)),
      })),
    };
  }

  /** Next upcoming class for a batch, relative to now. Used on dashboards. */
  async nextClass(batchId: string) {
    const slots = await this.prisma.timetableSlot.findMany({
      where: { batchId },
      include: { batch: { select: { name: true } } },
    });
    if (slots.length === 0) return null;

    const now = new Date();
    const nowDay = now.getDay();
    const nowMin = now.getHours() * 60 + now.getMinutes();

    let best: { slot: (typeof slots)[number]; inMinutes: number } | null = null;
    for (const slot of slots) {
      const slotDay = WEEKDAYS.indexOf(slot.weekday);
      let dayDiff = (slotDay - nowDay + 7) % 7;
      const startMin = toMinutes(slot.startTime);
      if (dayDiff === 0 && startMin <= nowMin) dayDiff = 7;
      const inMinutes = dayDiff * 1440 + (startMin - nowMin);
      if (!best || inMinutes < best.inMinutes) best = { slot, inMinutes };
    }
    if (!best) return null;

    return {
      id: best.slot.id,
      subject: best.slot.subject,
      teacher: best.slot.teacher,
      weekday: best.slot.weekday,
      startTime: best.slot.startTime,
      endTime: best.slot.endTime,
      room: best.slot.room,
      batchName: best.slot.batch.name,
      startsInMinutes: best.inMinutes,
      isToday: best.inMinutes < 1440 && (WEEKDAYS.indexOf(best.slot.weekday) === nowDay),
    };
  }

  async create(dto: CreateTimetableSlotDto) {
    await this.validate(dto);
    const slot = await this.prisma.timetableSlot.create({
      data: {
        batchId: dto.batchId,
        subject: dto.subject,
        teacher: dto.teacher ?? null,
        weekday: dto.weekday,
        startTime: dto.startTime,
        endTime: dto.endTime,
        room: dto.room,
        date: dto.date ? new Date(dto.date) : null,
      },
    });
    return slot;
  }

  async update(id: string, dto: UpdateTimetableSlotDto) {
    const existing = await this.prisma.timetableSlot.findUnique({
      where: { id },
    });
    if (!existing) throw new NotFoundException('Timetable slot not found');

    const merged = {
      batchId: dto.batchId ?? existing.batchId,
      weekday: dto.weekday ?? existing.weekday,
      startTime: dto.startTime ?? existing.startTime,
      endTime: dto.endTime ?? existing.endTime,
      room: dto.room ?? existing.room,
      subject: dto.subject ?? existing.subject,
    };
    await this.validate(merged as CreateTimetableSlotDto, id);

    return this.prisma.timetableSlot.update({
      where: { id },
      data: {
        ...(dto.batchId ? { batchId: dto.batchId } : {}),
        ...(dto.subject ? { subject: dto.subject } : {}),
        ...(dto.teacher !== undefined ? { teacher: dto.teacher } : {}),
        ...(dto.weekday ? { weekday: dto.weekday } : {}),
        ...(dto.startTime ? { startTime: dto.startTime } : {}),
        ...(dto.endTime ? { endTime: dto.endTime } : {}),
        ...(dto.room ? { room: dto.room } : {}),
        ...(dto.date !== undefined
          ? { date: dto.date ? new Date(dto.date) : null }
          : {}),
      },
    });
  }

  async remove(id: string) {
    const existing = await this.prisma.timetableSlot.findUnique({
      where: { id },
    });
    if (!existing) throw new NotFoundException('Timetable slot not found');
    await this.prisma.timetableSlot.delete({ where: { id } });
    return { message: 'Slot removed' };
  }

  /** Reject inverted times, batch clashes and room double-booking. */
  private async validate(dto: CreateTimetableSlotDto, ignoreId?: string) {
    const batch = await this.prisma.batch.findUnique({
      where: { id: dto.batchId },
    });
    if (!batch) throw new BadRequestException('Selected batch does not exist');

    const start = toMinutes(dto.startTime);
    const end = toMinutes(dto.endTime);
    if (end <= start) {
      throw new BadRequestException('End time must be after start time');
    }

    const sameDay = await this.prisma.timetableSlot.findMany({
      where: {
        weekday: dto.weekday,
        ...(ignoreId ? { NOT: { id: ignoreId } } : {}),
      },
      include: { batch: { select: { name: true } } },
    });

    for (const s of sameDay) {
      const sStart = toMinutes(s.startTime);
      const sEnd = toMinutes(s.endTime);
      const overlaps = start < sEnd && sStart < end;
      if (!overlaps) continue;

      if (s.batchId === dto.batchId) {
        throw new BadRequestException(
          `This batch already has "${s.subject}" at ${s.startTime}-${s.endTime} on ${dto.weekday}`,
        );
      }
      if (s.room.trim().toLowerCase() === dto.room.trim().toLowerCase()) {
        throw new BadRequestException(
          `${dto.room} is already booked by "${s.batch.name}" at ${s.startTime}-${s.endTime} on ${dto.weekday}`,
        );
      }
    }
  }
}
