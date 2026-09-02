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
import { Role } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { AnnouncementsService } from './announcements.service';
import {
  CreateAnnouncementDto,
  UpdateAnnouncementDto,
} from './dto/announcement.dto';

@ApiTags('announcements')
@ApiBearerAuth()
@Controller('announcements')
export class AnnouncementsController {
  constructor(private readonly announcements: AnnouncementsService) {}

  @Roles(Role.ADMIN)
  @Get()
  findAll(
    @Query('batchId') batchId?: string,
    @Query('search') search?: string,
  ) {
    return this.announcements.findAll({ batchId, search });
  }

  @Roles(Role.STUDENT)
  @Get('me')
  @ApiOperation({ summary: 'Announcements visible to this student' })
  mine(@CurrentUser() user: AuthUser) {
    if (!user.studentId) {
      throw new BadRequestException('No student profile linked to this account');
    }
    return this.announcements.forStudent(user.studentId);
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.announcements.findOne(id);
  }

  @Roles(Role.ADMIN)
  @Post()
  @ApiOperation({ summary: 'Send to all students or one batch' })
  create(
    @Body() dto: CreateAnnouncementDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.announcements.create(dto, userId);
  }

  @Roles(Role.ADMIN)
  @Patch(':id')
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateAnnouncementDto,
  ) {
    return this.announcements.update(id, dto);
  }

  @Roles(Role.ADMIN)
  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.announcements.remove(id);
  }
}
