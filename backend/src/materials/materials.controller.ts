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
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiConsumes,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { FileInterceptor } from '../uploads/file.interceptor';
import { MaterialsService } from './materials.service';
import { CreateMaterialDto, UpdateMaterialDto } from './dto/material.dto';

@ApiTags('materials')
@ApiBearerAuth()
@Controller('materials')
export class MaterialsController {
  constructor(private readonly materials: MaterialsService) {}

  @Roles(Role.ADMIN)
  @Get()
  findAll(
    @Query('batchId') batchId?: string,
    @Query('subject') subject?: string,
    @Query('search') search?: string,
  ) {
    return this.materials.findAll({ batchId, subject, search });
  }

  @Roles(Role.STUDENT)
  @Get('me')
  @ApiOperation({ summary: "Material for the student's batch + institute-wide" })
  mine(
    @CurrentUser() user: AuthUser,
    @Query('subject') subject?: string,
    @Query('search') search?: string,
  ) {
    if (!user.studentId) {
      throw new BadRequestException('No student profile linked to this account');
    }
    return this.materials.forStudent(user.studentId, subject, search);
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.materials.findOne(id);
  }

  @Roles(Role.ADMIN)
  @Post()
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Upload a document and assign it to a batch' })
  @UseInterceptors(FileInterceptor)
  create(
    @Body() dto: CreateMaterialDto,
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser('id') userId: string,
  ) {
    return this.materials.create(dto, file, userId);
  }

  @Roles(Role.ADMIN)
  @Patch(':id')
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateMaterialDto,
  ) {
    return this.materials.update(id, dto);
  }

  @Roles(Role.ADMIN)
  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.materials.remove(id);
  }
}
