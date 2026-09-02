import {
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
import { BatchesService } from './batches.service';
import {
  AssignStudentsDto,
  CreateBatchDto,
  QueryBatchesDto,
  UpdateBatchDto,
} from './dto/batch.dto';

@ApiTags('batches')
@ApiBearerAuth()
@Controller('batches')
export class BatchesController {
  constructor(private readonly batches: BatchesService) {}

  /** Students need the batch list too (read-only) for timetable/material filters. */
  @Get()
  findAll(@Query() query: QueryBatchesDto) {
    return this.batches.findAll(query);
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.batches.findOne(id);
  }

  @Roles(Role.ADMIN)
  @Post()
  create(@Body() dto: CreateBatchDto) {
    return this.batches.create(dto);
  }

  @Roles(Role.ADMIN)
  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateBatchDto) {
    return this.batches.update(id, dto);
  }

  @Roles(Role.ADMIN)
  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.batches.remove(id);
  }

  @Roles(Role.ADMIN)
  @Post(':id/students')
  @ApiOperation({ summary: 'Assign students to this batch' })
  assign(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AssignStudentsDto,
  ) {
    return this.batches.assignStudents(id, dto);
  }

  @Roles(Role.ADMIN)
  @Delete(':id/students/:studentId')
  removeStudent(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('studentId', ParseUUIDPipe) studentId: string,
  ) {
    return this.batches.removeStudent(id, studentId);
  }
}
