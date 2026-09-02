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
import { ExamsService } from './exams.service';
import {
  BulkResultsDto,
  CreateExamDto,
  EnterResultDto,
  UpdateExamDto,
} from './dto/exam.dto';

@ApiTags('exams')
@ApiBearerAuth()
@Controller('exams')
export class ExamsController {
  constructor(private readonly exams: ExamsService) {}

  @Roles(Role.ADMIN)
  @Get()
  findAll(@Query('batchId') batchId?: string) {
    return this.exams.findAll(batchId);
  }

  @Roles(Role.STUDENT)
  @Get('me')
  @ApiOperation({ summary: "Logged-in student's report card (published only)" })
  mine(@CurrentUser() user: AuthUser) {
    if (!user.studentId) {
      throw new BadRequestException('No student profile linked to this account');
    }
    return this.exams.studentResults(user.studentId, user);
  }

  @Get('student/:studentId')
  studentResults(
    @Param('studentId', ParseUUIDPipe) studentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.exams.studentResults(studentId, user);
  }

  @Roles(Role.ADMIN)
  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.exams.findOne(id);
  }

  @Roles(Role.ADMIN)
  @Get(':id/marks-sheet')
  @ApiOperation({ summary: 'Marks-entry grid for every student in the batch' })
  marksSheet(@Param('id', ParseUUIDPipe) id: string) {
    return this.exams.marksSheet(id);
  }

  @Roles(Role.ADMIN)
  @Post()
  create(@Body() dto: CreateExamDto) {
    return this.exams.create(dto);
  }

  @Roles(Role.ADMIN)
  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateExamDto) {
    return this.exams.update(id, dto);
  }

  @Roles(Role.ADMIN)
  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.exams.remove(id);
  }

  @Roles(Role.ADMIN)
  @Post(':id/results')
  @ApiOperation({ summary: 'Enter/update marks for one student' })
  enterResult(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: EnterResultDto,
  ) {
    return this.exams.enterResult(id, dto);
  }

  @Roles(Role.ADMIN)
  @Post(':id/results/bulk')
  @ApiOperation({ summary: 'Save the whole marks sheet at once' })
  enterBulk(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: BulkResultsDto,
  ) {
    return this.exams.enterBulk(id, dto);
  }

  @Roles(Role.ADMIN)
  @Delete('results/:resultId')
  removeResult(@Param('resultId', ParseUUIDPipe) resultId: string) {
    return this.exams.removeResult(resultId);
  }
}
