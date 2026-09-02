import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';
import { existsSync } from 'fs';

import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { StudentsModule } from './students/students.module';
import { BatchesModule } from './batches/batches.module';
import { AttendanceModule } from './attendance/attendance.module';
import { FeesModule } from './fees/fees.module';
import { TimetableModule } from './timetable/timetable.module';
import { ExamsModule } from './exams/exams.module';
import { MaterialsModule } from './materials/materials.module';
import { AnnouncementsModule } from './announcements/announcements.module';
import { DashboardModule } from './dashboard/dashboard.module';
import { UploadsModule } from './uploads/uploads.module';
import { ChatModule } from './chat/chat.module';
import { MaintenanceModule } from './maintenance/maintenance.module';

/** Mirrors UploadsService's driver default without importing it (circular). */
function usesDiskStorage(): boolean {
  const configured = process.env.STORAGE_DRIVER;
  if (configured === 'database') return false;
  if (configured === 'disk') return true;
  return process.env.NODE_ENV !== 'production';
}

import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { HealthController } from './health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, cache: true }),
    // Only the disk driver has files on the filesystem to serve. Under the
    // database driver FilesController streams them from Postgres instead, and
    // a serverless host has no writable directory to point at anyway.
    ...(usesDiskStorage()
      ? [
          ServeStaticModule.forRoot({
            rootPath: join(process.cwd(), process.env.UPLOAD_DIR || 'uploads'),
            serveRoot: '/files',
            serveStaticOptions: { index: false, dotfiles: 'deny' },
          }),
        ]
      : []),
    // The compiled Flutter web app, when it has been built into public/.
    // Same origin as the API, so the browser build needs no configuration.
    ...(existsSync(join(process.cwd(), 'public', 'index.html'))
      ? [
          ServeStaticModule.forRoot({
            rootPath: join(process.cwd(), 'public'),
            // Real asset requests are served by the static middleware. This
            // controls only the index.html fallback, so an unmatched /api,
            // /health or /docs path reaches Nest and gets a JSON 404 rather
            // than a page of HTML the mobile client cannot parse.
            renderPath: /^(?!\/api\b|\/health\b|\/docs\b).*$/,
            serveStaticOptions: { index: false },
          }),
        ]
      : []),
    PrismaModule,
    AuthModule,
    UsersModule,
    StudentsModule,
    BatchesModule,
    AttendanceModule,
    FeesModule,
    TimetableModule,
    ExamsModule,
    MaterialsModule,
    AnnouncementsModule,
    DashboardModule,
    UploadsModule,
    ChatModule,
    MaintenanceModule,
  ],
  controllers: [HealthController],
  providers: [
    // Every route is authenticated unless marked @Public().
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
  ],
})
export class AppModule {}
