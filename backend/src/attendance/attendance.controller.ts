import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AttendanceStatus, Role } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { AttendanceService } from './attendance.service';
import {
  AttendanceEntryDto,
  AttendanceHistoryQueryDto,
  AttendanceSheetQueryDto,
  MarkAttendanceDto,
} from './dto/attendance.dto';

@ApiTags('attendance')
@ApiBearerAuth()
@Controller('attendance')
export class AttendanceController {
  constructor(private readonly attendance: AttendanceService) {}

  @Roles(Role.ADMIN)
  @Get('sheet')
  @ApiOperation({ summary: 'Roster for batch + date, pre-filled if marked' })
  sheet(@Query() query: AttendanceSheetQueryDto) {
    return this.attendance.sheet(query);
  }

  @Roles(Role.ADMIN)
  @Post('mark')
  @ApiOperation({
    summary: 'Bulk mark / re-mark attendance (one record per student per day)',
  })
  mark(@Body() dto: MarkAttendanceDto, @CurrentUser('id') userId: string) {
    return this.attendance.mark(dto, userId);
  }

  @Roles(Role.ADMIN)
  @Get('history')
  history(@Query() query: AttendanceHistoryQueryDto) {
    return this.attendance.history(query);
  }

  @Roles(Role.ADMIN)
  @Get('batch/:batchId/days')
  @ApiOperation({ summary: 'Day-wise attendance roll-up for a batch' })
  batchDays(
    @Param('batchId', ParseUUIDPipe) batchId: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.attendance.batchDays(batchId, from, to);
  }

  @Get('student/:studentId')
  @ApiOperation({ summary: 'Attendance report; students see only their own' })
  studentReport(
    @Param('studentId', ParseUUIDPipe) studentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.attendance.studentReport(studentId, user);
  }

  @Roles(Role.STUDENT)
  @Get('me')
  @ApiOperation({ summary: "Logged-in student's own attendance report" })
  myReport(@CurrentUser() user: AuthUser) {
    if (!user.studentId) {
      throw new BadRequestException('No student profile linked to this account');
    }
    return this.attendance.studentReport(user.studentId, user);
  }

  @Roles(Role.ADMIN)
  @Patch(':id')
  updateOne(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: Omit<AttendanceEntryDto, 'studentId'>,
    @CurrentUser('id') userId: string,
  ) {
    return this.attendance.updateOne(
      id,
      body.status as AttendanceStatus,
      body.remarks,
      userId,
    );
  }

  @Roles(Role.ADMIN)
  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.attendance.remove(id);
  }
}
