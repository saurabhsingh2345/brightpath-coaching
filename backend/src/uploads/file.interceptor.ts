import {
  BadRequestException,
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
  mixin,
} from '@nestjs/common';
import { FileInterceptor as NestFileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { UploadsService } from './uploads.service';

/**
 * Thin wrapper so multer's storage/limits can be built from UploadsService
 * (which reads env) instead of being hard-coded at decoration time.
 */
@Injectable()
export class FileInterceptor implements NestInterceptor {
  private inner: NestInterceptor;

  constructor(private readonly uploads: UploadsService) {
    const Impl = NestFileInterceptor('file', {
      storage: diskStorage({
        destination: (_req, _file, cb) => cb(null, uploads.stagingDir),
        filename: (_req, file, cb) => {
          try {
            cb(null, uploads.safeFileName(file.originalname, file.mimetype));
          } catch (e) {
            cb(e as Error, '');
          }
        },
      }),
      limits: { fileSize: uploads.maxBytes, files: 1 },
      fileFilter: (_req, file, cb) => {
        try {
          uploads.safeFileName(file.originalname, file.mimetype);
          cb(null, true);
        } catch (e) {
          cb(e as Error, false);
        }
      },
    });
    this.inner = new (Impl as any)();
  }

  intercept(context: ExecutionContext, next: CallHandler) {
    return this.inner.intercept(context, next);
  }
}
