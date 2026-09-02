import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { paginate } from '../common/dto/pagination.dto';
import {
  AssignStudentsDto,
  CreateBatchDto,
  QueryBatchesDto,
  UpdateBatchDto,
} from './dto/batch.dto';

@Injectable()
export class BatchesService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(query: QueryBatchesDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 50;
    const search = query.search?.trim();

    const where: Prisma.BatchWhereInput = {
      ...(query.isActive !== undefined ? { isActive: query.isActive } : {}),
      ...(search
        ? {
            OR: [
              { name: { contains: search, mode: 'insensitive' } },
              { course: { contains: search, mode: 'insensitive' } },
              { subject: { contains: search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [rows, total] = await this.prisma.$transaction([
      this.prisma.batch.findMany({
        where,
        include: { _count: { select: { students: true } } },
        orderBy: [{ isActive: 'desc' }, { name: 'asc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.batch.count({ where }),
    ]);

    return paginate(
      rows.map(({ _count, ...b }) => ({ ...b, studentCount: _count.students })),
      total,
      page,
      limit,
    );
  }

  async findOne(id: string) {
    const batch = await this.prisma.batch.findUnique({
      where: { id },
      include: {
        students: {
          where: { isActive: true },
          select: {
            id: true,
            name: true,
            studentCode: true,
            phone: true,
            course: true,
          },
          orderBy: { name: 'asc' },
        },
        timetable: { orderBy: [{ weekday: 'asc' }, { startTime: 'asc' }] },
        _count: { select: { students: true, exams: true, materials: true } },
      },
    });
    if (!batch) throw new NotFoundException('Batch not found');
    const { _count, ...rest } = batch;
    return {
      ...rest,
      studentCount: _count.students,
      examCount: _count.exams,
      materialCount: _count.materials,
    };
  }

  create(dto: CreateBatchDto) {
    return this.prisma.batch.create({
      data: {
        name: dto.name.trim(),
        course: dto.course,
        subject: dto.subject,
        timing: dto.timing,
        room: dto.room,
        capacity: dto.capacity ?? 40,
        startDate: dto.startDate ? new Date(dto.startDate) : new Date(),
      },
    });
  }

  async update(id: string, dto: UpdateBatchDto) {
    await this.assertExists(id);
    return this.prisma.batch.update({
      where: { id },
      data: {
        ...(dto.name ? { name: dto.name.trim() } : {}),
        ...(dto.course ? { course: dto.course } : {}),
        ...(dto.subject ? { subject: dto.subject } : {}),
        ...(dto.timing ? { timing: dto.timing } : {}),
        ...(dto.room ? { room: dto.room } : {}),
        ...(dto.capacity !== undefined ? { capacity: dto.capacity } : {}),
        ...(dto.startDate ? { startDate: new Date(dto.startDate) } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
      },
    });
  }

  async remove(id: string) {
    const batch = await this.prisma.batch.findUnique({
      where: { id },
      include: { _count: { select: { students: true } } },
    });
    if (!batch) throw new NotFoundException('Batch not found');
    if (batch._count.students > 0) {
      throw new BadRequestException(
        `${batch._count.students} student(s) are still in this batch. Move them out first, or deactivate the batch instead.`,
      );
    }
    await this.prisma.batch.delete({ where: { id } });
    return { message: 'Batch deleted' };
  }

  async assignStudents(id: string, dto: AssignStudentsDto) {
    const batch = await this.prisma.batch.findUnique({
      where: { id },
      include: { _count: { select: { students: true } } },
    });
    if (!batch) throw new NotFoundException('Batch not found');

    const incoming = await this.prisma.student.count({
      where: { id: { in: dto.studentIds }, batchId: { not: id } },
    });
    if (batch._count.students + incoming > batch.capacity) {
      throw new BadRequestException(
        `Batch capacity is ${batch.capacity}. Cannot add ${incoming} more student(s).`,
      );
    }

    const result = await this.prisma.student.updateMany({
      where: { id: { in: dto.studentIds } },
      data: { batchId: id },
    });
    return { message: `${result.count} student(s) assigned to ${batch.name}` };
  }

  async removeStudent(id: string, studentId: string) {
    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
    });
    if (!student || student.batchId !== id) {
      throw new NotFoundException('Student is not in this batch');
    }
    await this.prisma.student.update({
      where: { id: studentId },
      data: { batchId: null },
    });
    return { message: 'Student removed from batch' };
  }

  private async assertExists(id: string) {
    const found = await this.prisma.batch.findUnique({ where: { id } });
    if (!found) throw new NotFoundException('Batch not found');
    return found;
  }
}
