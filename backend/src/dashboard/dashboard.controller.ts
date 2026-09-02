import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { DashboardService } from './dashboard.service';

@ApiTags('dashboard')
@ApiBearerAuth()
@Controller('dashboard')
export class DashboardController {
  constructor(private readonly dashboard: DashboardService) {}

  @Roles(Role.ADMIN)
  @Get('admin')
  @ApiOperation({ summary: 'Institute-wide counters for the admin home screen' })
  admin() {
    return this.dashboard.admin();
  }

  @Roles(Role.STUDENT)
  @Get('student')
  @ApiOperation({ summary: 'Attendance %, fees due, next class, announcements' })
  student(@CurrentUser() user: AuthUser) {
    return this.dashboard.student(user.studentId);
  }
}
