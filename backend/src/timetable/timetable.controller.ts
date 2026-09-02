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
import { Role, Weekday } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { TimetableService } from './timetable.service';
import {
  CreateTimetableSlotDto,
  UpdateTimetableSlotDto,
} from './dto/timetable.dto';

@ApiTags('timetable')
@ApiBearerAuth()
@Controller('timetable')
export class TimetableController {
  constructor(
    private readonly timetable: TimetableService,
    private readonly prisma: PrismaService,
  ) {}

  @Get()
  findAll(
    @Query('batchId') batchId?: string,
    @Query('weekday') weekday?: Weekday,
  ) {
    return this.timetable.findAll(batchId, weekday);
  }

  @Roles(Role.STUDENT)
  @Get('me')
  @ApiOperation({ summary: "Weekly timetable for the student's own batch" })
  async mine(@CurrentUser() user: AuthUser) {
    if (!user.studentId) {
      throw new BadRequestException('No student profile linked to this account');
    }
    const student = await this.prisma.student.findUnique({
      where: { id: user.studentId },
      select: { batchId: true },
    });
    if (!student?.batchId) {
      return { batch: null, days: [] };
    }
    return this.timetable.weekly(student.batchId);
  }

  @Get('batch/:batchId')
  @ApiOperation({ summary: 'Weekly timetable grouped by weekday' })
  weekly(@Param('batchId', ParseUUIDPipe) batchId: string) {
    return this.timetable.weekly(batchId);
  }

  @Get('batch/:batchId/next')
  nextClass(@Param('batchId', ParseUUIDPipe) batchId: string) {
    return this.timetable.nextClass(batchId);
  }

  @Roles(Role.ADMIN)
  @Post()
  create(@Body() dto: CreateTimetableSlotDto) {
    return this.timetable.create(dto);
  }

  @Roles(Role.ADMIN)
  @Patch(':id')
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateTimetableSlotDto,
  ) {
    return this.timetable.update(id, dto);
  }

  @Roles(Role.ADMIN)
  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.timetable.remove(id);
  }
}
