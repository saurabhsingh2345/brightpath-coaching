import {
  BadRequestException,
  Controller,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from './file.interceptor';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { UploadsService } from './uploads.service';

@ApiTags('uploads')
@ApiBearerAuth()
@Roles(Role.ADMIN)
@Controller('uploads')
export class UploadsController {
  constructor(private readonly uploads: UploadsService) {}

  @Post()
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Upload a single file, returns its public URL' })
  @UseInterceptors(FileInterceptor)
  async upload(@UploadedFile() file: Express.Multer.File) {
    if (!file) throw new BadRequestException('No file was uploaded');
    const { fileUrl, storageKey } = await this.uploads.persist(file);
    return {
      fileName: file.originalname,
      storedName: storageKey,
      fileUrl,
      fileType: file.mimetype,
      fileSize: file.size,
    };
  }
}
