import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuthService } from '../auth/auth.service';
import { paginate } from '../common/dto/pagination.dto';
import { CreateUserDto, QueryUsersDto, UpdateUserDto } from './dto/user.dto';

const safeSelect = {
  id: true,
  email: true,
  name: true,
  role: true,
  phone: true,
  avatarUrl: true,
  isActive: true,
  lastLoginAt: true,
  createdAt: true,
} satisfies Prisma.UserSelect;

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(query: QueryUsersDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const search = query.search?.trim();

    const where: Prisma.UserWhereInput = {
      ...(query.role ? { role: query.role } : {}),
      ...(search
        ? {
            OR: [
              { name: { contains: search, mode: 'insensitive' } },
              { email: { contains: search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [rows, total] = await this.prisma.$transaction([
      this.prisma.user.findMany({
        where,
        select: safeSelect,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.user.count({ where }),
    ]);
    return paginate(rows, total, page, limit);
  }

  async findOne(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: safeSelect,
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async create(dto: CreateUserDto) {
    const email = dto.email.toLowerCase().trim();
    if (await this.prisma.user.findUnique({ where: { email } })) {
      throw new BadRequestException('A user with this email already exists');
    }
    if (dto.role === Role.STUDENT) {
      throw new BadRequestException(
        'Create students through the Students module so their profile is set up.',
      );
    }
    return this.prisma.user.create({
      data: {
        email,
        name: dto.name,
        phone: dto.phone ?? null,
        role: dto.role,
        passwordHash: await AuthService.hashPassword(dto.password),
      },
      select: safeSelect,
    });
  }

  async update(id: string, dto: UpdateUserDto) {
    await this.findOne(id);
    return this.prisma.user.update({
      where: { id },
      data: {
        ...(dto.name ? { name: dto.name } : {}),
        ...(dto.phone !== undefined ? { phone: dto.phone } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        ...(dto.password
          ? {
              passwordHash: await AuthService.hashPassword(dto.password),
              refreshToken: null,
            }
          : {}),
      },
      select: safeSelect,
    });
  }

  async remove(id: string, requesterId: string) {
    if (id === requesterId) {
      throw new BadRequestException('You cannot delete your own account');
    }
    await this.findOne(id);
    const admins = await this.prisma.user.count({ where: { role: Role.ADMIN } });
    const target = await this.prisma.user.findUnique({ where: { id } });
    if (target?.role === Role.ADMIN && admins <= 1) {
      throw new BadRequestException('At least one admin must remain');
    }
    await this.prisma.user.delete({ where: { id } });
    return { message: 'User deleted' };
  }
}
