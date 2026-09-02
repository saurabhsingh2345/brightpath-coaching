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
import { StudentsService } from './students.service';
import {
  CreateStudentDto,
  QueryStudentsDto,
  UpdateStudentDto,
} from './dto/student.dto';

@ApiTags('students')
@ApiBearerAuth()
@Roles(Role.ADMIN)
@Controller('students')
export class StudentsController {
  constructor(private readonly students: StudentsService) {}

  @Get()
  @ApiOperation({ summary: 'List / search students (paginated)' })
  findAll(@Query() query: QueryStudentsDto) {
    return this.students.findAll(query);
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.students.findOne(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create a student (also creates their login)' })
  create(@Body() dto: CreateStudentDto) {
    return this.students.create(dto);
  }

  @Patch(':id')
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateStudentDto,
  ) {
    return this.students.update(id, dto);
  }

  @Patch(':id/deactivate')
  @ApiOperation({ summary: 'Deactivate (soft delete) - keeps all history' })
  deactivate(@Param('id', ParseUUIDPipe) id: string) {
    return this.students.setActive(id, false);
  }

  @Patch(':id/activate')
  activate(@Param('id', ParseUUIDPipe) id: string) {
    return this.students.setActive(id, true);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Permanently delete a student and their records' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.students.remove(id);
  }
}
