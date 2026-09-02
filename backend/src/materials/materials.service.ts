import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UploadsService } from '../uploads/uploads.service';
import { CreateMaterialDto, UpdateMaterialDto } from './dto/material.dto';

@Injectable()
export class MaterialsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly uploads: UploadsService,
  ) {}

  async findAll(filters: {
    batchId?: string;
    subject?: string;
    search?: string;
    /** When set, also include institute-wide (batchId = null) material. */
    includeGlobal?: boolean;
  }) {
    const search = filters.search?.trim();
    const where: Prisma.StudyMaterialWhereInput = {
      ...(filters.subject ? { subject: filters.subject } : {}),
      ...(search
        ? {
            OR: [
              { title: { contains: search, mode: 'insensitive' } },
              { description: { contains: search, mode: 'insensitive' } },
              { subject: { contains: search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    if (filters.batchId) {
      where.AND = [
        filters.includeGlobal
          ? { OR: [{ batchId: filters.batchId }, { batchId: null }] }
          : { batchId: filters.batchId },
      ];
    } else if (filters.includeGlobal) {
      // Student with no batch: only institute-wide material.
      where.batchId = null;
    }

    return this.prisma.studyMaterial.findMany({
      where,
      include: {
        batch: { select: { id: true, name: true } },
        uploadedBy: { select: { name: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async forStudent(studentId: string, subject?: string, search?: string) {
    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      select: { batchId: true },
    });
    if (!student) throw new NotFoundException('Student not found');
    return this.findAll({
      batchId: student.batchId ?? undefined,
      subject,
      search,
      includeGlobal: true,
    });
  }

  async findOne(id: string) {
    const material = await this.prisma.studyMaterial.findUnique({
      where: { id },
      include: {
        batch: { select: { id: true, name: true } },
        uploadedBy: { select: { name: true } },
      },
    });
    if (!material) throw new NotFoundException('Material not found');
    return material;
  }

  async create(
    dto: CreateMaterialDto,
    file: Express.Multer.File,
    uploadedById: string,
  ) {
    if (!file) {
      throw new BadRequestException('Attach a PDF or document to upload');
    }

    if (dto.batchId) {
      const batch = await this.prisma.batch.findUnique({
        where: { id: dto.batchId },
      });
      if (!batch) {
        await this.uploads.deleteFile(file.filename);
        throw new BadRequestException('Selected batch does not exist');
      }
    }

    const { fileUrl } = await this.uploads.persist(file);

    return this.prisma.studyMaterial.create({
      data: {
        title: dto.title,
        description: dto.description ?? null,
        subject: dto.subject,
        batchId: dto.batchId || null,
        fileName: file.originalname,
        fileUrl,
        fileType: file.mimetype,
        fileSize: file.size,
        uploadedById,
      },
      include: { batch: { select: { id: true, name: true } } },
    });
  }

  async update(id: string, dto: UpdateMaterialDto) {
    await this.findOne(id);
    return this.prisma.studyMaterial.update({
      where: { id },
      data: {
        ...(dto.title ? { title: dto.title } : {}),
        ...(dto.description !== undefined
          ? { description: dto.description }
          : {}),
        ...(dto.subject ? { subject: dto.subject } : {}),
        ...(dto.batchId !== undefined ? { batchId: dto.batchId || null } : {}),
      },
      include: { batch: { select: { id: true, name: true } } },
    });
  }

  async remove(id: string) {
    const material = await this.findOne(id);
    await this.prisma.studyMaterial.delete({ where: { id } });
    await this.uploads.deleteFile(material.fileUrl);
    return { message: 'Material deleted' };
  }
}
