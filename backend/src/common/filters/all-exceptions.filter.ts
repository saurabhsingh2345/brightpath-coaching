import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Request, Response } from 'express';

interface ErrorBody {
  statusCode: number;
  message: string;
  errors?: string[] | Record<string, unknown>;
  path: string;
  timestamp: string;
}

/**
 * Single place that turns anything thrown inside the app into a predictable
 * JSON error body, so the mobile client can always parse `message`.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('Exception');

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const body: ErrorBody = {
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      message: 'Something went wrong. Please try again.',
      path: request.url,
      timestamp: new Date().toISOString(),
    };

    if (exception instanceof HttpException) {
      body.statusCode = exception.getStatus();
      const res = exception.getResponse();
      if (typeof res === 'string') {
        body.message = res;
      } else if (res && typeof res === 'object') {
        const r = res as Record<string, any>;
        // class-validator returns message as string[]
        if (Array.isArray(r.message)) {
          body.message = r.message[0];
          body.errors = r.message;
        } else {
          body.message = r.message ?? exception.message;
        }
      }
    } else if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      const mapped = this.mapPrismaError(exception);
      body.statusCode = mapped.status;
      body.message = mapped.message;
    } else if (exception instanceof Prisma.PrismaClientValidationError) {
      body.statusCode = HttpStatus.BAD_REQUEST;
      body.message = 'Invalid data sent to the database layer.';
    } else if (exception instanceof Prisma.PrismaClientInitializationError) {
      body.statusCode = HttpStatus.SERVICE_UNAVAILABLE;
      body.message = 'Database is unreachable. Check DATABASE_URL.';
    }

    if (body.statusCode >= 500) {
      this.logger.error(
        `${request.method} ${request.url} -> ${body.statusCode}`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    } else {
      this.logger.warn(
        `${request.method} ${request.url} -> ${body.statusCode}: ${body.message}`,
      );
    }

    response.status(body.statusCode).json(body);
  }

  private mapPrismaError(e: Prisma.PrismaClientKnownRequestError) {
    const target = (e.meta?.target as string[] | string | undefined) ?? '';
    const field = Array.isArray(target) ? target.join(', ') : String(target);

    switch (e.code) {
      case 'P2002':
        return {
          status: HttpStatus.CONFLICT,
          message: `A record with this ${field || 'value'} already exists.`,
        };
      case 'P2003':
        return {
          status: HttpStatus.BAD_REQUEST,
          message: 'Related record does not exist.',
        };
      case 'P2025':
        return {
          status: HttpStatus.NOT_FOUND,
          message: 'Record not found.',
        };
      case 'P2014':
        return {
          status: HttpStatus.BAD_REQUEST,
          message: 'This change would break a required relation.',
        };
      default:
        return {
          status: HttpStatus.BAD_REQUEST,
          message: `Database error (${e.code}).`,
        };
    }
  }
}
