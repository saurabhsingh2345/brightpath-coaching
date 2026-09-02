import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomBytes } from 'crypto';
import { existsSync, mkdirSync, readFileSync, unlinkSync } from 'fs';
import { extname, join, resolve } from 'path';
import { tmpdir } from 'os';
import { PrismaService } from '../prisma/prisma.service';

/** Only document formats a coaching institute actually shares. */
export const ALLOWED_MIME: Record<string, string[]> = {
  'application/pdf': ['.pdf'],
  'application/msword': ['.doc'],
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': [
    '.docx',
  ],
  'application/vnd.ms-powerpoint': ['.ppt'],
  'application/vnd.openxmlformats-officedocument.presentationml.presentation': [
    '.pptx',
  ],
  'application/vnd.ms-excel': ['.xls'],
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': [
    '.xlsx',
  ],
  'text/plain': ['.txt'],
  'image/jpeg': ['.jpg', '.jpeg'],
  'image/png': ['.png'],
  'application/zip': ['.zip'],
};

/**
 * Where uploaded bytes live.
 *
 *  - `database` keeps them in Postgres. Required on serverless hosts, whose
 *    filesystem is ephemeral, and it means a database backup covers files too.
 *  - `disk` writes to UPLOAD_DIR. Nicer locally and on an always-on server.
 *
 * Defaults to `database` in production and `disk` otherwise, so local
 * development keeps behaving the way it always has.
 */
export type StorageDriver = 'database' | 'disk';

@Injectable()
export class UploadsService {
  private readonly logger = new Logger(UploadsService.name);
  readonly uploadRoot: string;
  /** Where multer writes the incoming file before we move it. */
  readonly stagingDir: string;
  readonly driver: StorageDriver;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    const configured = this.config.get<string>('STORAGE_DRIVER');
    this.driver =
      configured === 'database' || configured === 'disk'
        ? configured
        : this.config.get<string>('NODE_ENV') === 'production'
          ? 'database'
          : 'disk';

    this.uploadRoot = resolve(
      process.cwd(),
      this.config.get<string>('UPLOAD_DIR') ?? 'uploads',
    );

    // Multer stages the file on disk before we move it. Under the database
    // driver that staging area is throwaway, so use the OS temp dir - on a
    // serverless host the working directory is read-only and only /tmp is
    // writable.
    this.stagingDir =
      this.driver === 'disk' ? this.uploadRoot : join(tmpdir(), 'brightpath');

    try {
      if (!existsSync(this.stagingDir)) {
        mkdirSync(this.stagingDir, { recursive: true });
      }
    } catch (e) {
      this.logger.error(
        `Cannot create upload staging directory ${this.stagingDir}: ${String(e)}`,
      );
    }
    this.logger.log(
      `File storage driver: ${this.driver} (staging ${this.stagingDir})`,
    );
  }

  get maxBytes() {
    const fallback = this.driver === 'database' ? 8 : 20;
    const mb = Number(
      this.config.get<string>('MAX_UPLOAD_SIZE_MB') ?? fallback,
    );
    return mb * 1024 * 1024;
  }

  /**
   * Random, extension-checked filename. Never trusts the client name for
   * anything on disk, so a `../../etc/passwd` original name is harmless.
   */
  safeFileName(originalName: string, mimetype: string) {
    const allowedExts = ALLOWED_MIME[mimetype];
    if (!allowedExts) {
      throw new BadRequestException(
        `File type "${mimetype}" is not allowed. Upload a PDF, Office document, image or zip.`,
      );
    }
    const ext = extname(originalName).toLowerCase();
    if (!allowedExts.includes(ext)) {
      throw new BadRequestException(
        `Extension "${ext || 'none'}" does not match the file's content type.`,
      );
    }
    return `${Date.now()}-${randomBytes(8).toString('hex')}${ext}`;
  }

  /**
   * Moves a staged upload into permanent storage and returns its public URL.
   * Under the database driver the staging file is removed afterwards.
   */
  async persist(file: Express.Multer.File): Promise<{
    fileUrl: string;
    storageKey: string;
  }> {
    if (this.driver === 'disk') {
      return {
        fileUrl: this.publicUrl(`files/${file.filename}`),
        storageKey: file.filename,
      };
    }

    const bytes = readFileSync(file.path);
    const record = await this.prisma.fileObject.create({
      data: {
        fileName: file.originalname,
        mimeType: file.mimetype,
        size: bytes.length,
        data: bytes,
      },
      select: { id: true },
    });

    // The staged copy is no longer needed once the bytes are in Postgres.
    try {
      unlinkSync(file.path);
    } catch {
      /* a leftover temp file is harmless */
    }

    return {
      fileUrl: this.publicUrl(`api/files/${record.id}`),
      storageKey: record.id,
    };
  }

  /** Streams a stored file back. Returns null when it no longer exists. */
  async read(id: string) {
    const file = await this.prisma.fileObject.findUnique({ where: { id } });
    if (!file) return null;
    return {
      fileName: file.fileName,
      mimeType: file.mimeType,
      size: file.size,
      data: Buffer.from(file.data),
    };
  }

  publicUrl(path: string) {
    const base = (
      this.config.get<string>('PUBLIC_BASE_URL') ?? 'http://localhost:4000'
    ).replace(/\/$/, '');
    return `${base}/${path.replace(/^\//, '')}`;
  }

  /** Best-effort delete; a missing file must not fail the request. */
  async deleteFile(fileUrlOrKey: string) {
    const key = fileUrlOrKey.split('/').pop();
    if (!key) return;

    // Database-stored files are addressed by uuid.
    if (
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        key,
      )
    ) {
      await this.prisma.fileObject
        .delete({ where: { id: key } })
        .catch(() => undefined);
      return;
    }

    const path = join(this.uploadRoot, key);
    // Guard against traversal even though names are generated by us.
    if (!resolve(path).startsWith(this.uploadRoot)) return;
    try {
      if (existsSync(path)) unlinkSync(path);
    } catch (e) {
      this.logger.warn(`Could not delete ${key}: ${String(e)}`);
    }
  }
}
