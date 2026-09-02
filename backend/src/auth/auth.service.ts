import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { createHash, randomUUID } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { ChangePasswordDto, LoginDto, UpdateMeDto } from './dto/auth.dto';

const SALT_ROUNDS = 10;

/**
 * bcrypt silently truncates its input at 72 bytes, and two JWTs for the same
 * user share a much longer prefix than that - so hashing a raw refresh token
 * would make any two of them compare equal. Digest first, then hash.
 */
const digest = (token: string) =>
  createHash('sha256').update(token).digest('hex');

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  static hashPassword(plain: string) {
    return bcrypt.hash(plain, SALT_ROUNDS);
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase().trim() },
      include: { student: { select: { id: true, studentCode: true } } },
    });

    // Same message for unknown email and wrong password.
    if (!user || !(await bcrypt.compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid email or password');
    }
    if (!user.isActive) {
      throw new UnauthorizedException(
        'This account has been deactivated. Contact the institute.',
      );
    }

    const tokens = await this.issueTokens(user.id, user.email, user.role);

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        lastLoginAt: new Date(),
        refreshToken: await bcrypt.hash(digest(tokens.refreshToken), SALT_ROUNDS),
      },
    });

    return {
      ...tokens,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        phone: user.phone,
        avatarUrl: user.avatarUrl,
        studentId: user.student?.id ?? null,
        studentCode: user.student?.studentCode ?? null,
      },
    };
  }

  async refresh(refreshToken: string) {
    let payload: { sub: string; email: string; role: string };
    try {
      payload = await this.jwt.verifyAsync(refreshToken, {
        secret: this.config.get<string>('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Session expired. Please log in again.');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
    });
    if (!user || !user.refreshToken || !user.isActive) {
      throw new UnauthorizedException('Session expired. Please log in again.');
    }

    const matches = await bcrypt.compare(digest(refreshToken), user.refreshToken);
    if (!matches) {
      throw new UnauthorizedException('Session expired. Please log in again.');
    }

    const tokens = await this.issueTokens(user.id, user.email, user.role);
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        refreshToken: await bcrypt.hash(digest(tokens.refreshToken), SALT_ROUNDS),
      },
    });
    return tokens;
  }

  async logout(userId: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { refreshToken: null },
    });
    return { message: 'Logged out' };
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        phone: true,
        avatarUrl: true,
        createdAt: true,
        lastLoginAt: true,
        student: {
          include: {
            batch: { select: { id: true, name: true, subject: true, timing: true, room: true } },
          },
        },
      },
    });
    if (!user) throw new UnauthorizedException('Account no longer exists');
    return user;
  }

  async updateMe(userId: string, dto: UpdateMeDto) {
    const data: Record<string, unknown> = {};
    if (dto.name !== undefined) data.name = dto.name;
    if (dto.phone !== undefined) data.phone = dto.phone;
    if (Object.keys(data).length === 0) {
      throw new BadRequestException('Nothing to update');
    }

    const user = await this.prisma.user.update({
      where: { id: userId },
      data,
      select: { id: true, name: true, phone: true, email: true, role: true },
    });

    // Keep the student profile mirror in sync.
    const student = await this.prisma.student.findUnique({ where: { userId } });
    if (student) {
      await this.prisma.student.update({
        where: { id: student.id },
        data: {
          ...(dto.name !== undefined ? { name: dto.name } : {}),
          ...(dto.phone !== undefined ? { phone: dto.phone } : {}),
        },
      });
    }
    return user;
  }

  async changePassword(userId: string, dto: ChangePasswordDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException();

    if (!(await bcrypt.compare(dto.currentPassword, user.passwordHash))) {
      throw new BadRequestException('Current password is incorrect');
    }
    if (dto.currentPassword === dto.newPassword) {
      throw new BadRequestException(
        'New password must be different from the current one',
      );
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        passwordHash: await AuthService.hashPassword(dto.newPassword),
        refreshToken: null, // force re-login on other devices
      },
    });
    return { message: 'Password updated. Please log in again.' };
  }

  private async issueTokens(id: string, email: string, role: string) {
    const payload = { sub: id, email, role };
    const [accessToken, refreshToken] = await Promise.all([
      this.jwt.signAsync(payload, {
        secret: this.config.get<string>('JWT_ACCESS_SECRET'),
        expiresIn: this.config.get<string>('JWT_ACCESS_EXPIRES_IN') ?? '15m',
      }),
      // jti makes every refresh token unique, so rotation invalidates the
      // previous one even when two are issued within the same second.
      this.jwt.signAsync({ ...payload, jti: randomUUID() }, {
        secret: this.config.get<string>('JWT_REFRESH_SECRET'),
        expiresIn: this.config.get<string>('JWT_REFRESH_EXPIRES_IN') ?? '30d',
      }),
    ]);
    return { accessToken, refreshToken };
  }
}
