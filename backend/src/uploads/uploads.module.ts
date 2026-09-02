import { Module } from '@nestjs/common';
import { UploadsController } from './uploads.controller';
import { FilesController } from './files.controller';
import { UploadsService } from './uploads.service';
import { FileInterceptor } from './file.interceptor';

@Module({
  controllers: [UploadsController, FilesController],
  providers: [UploadsService, FileInterceptor],
  exports: [UploadsService, FileInterceptor],
})
export class UploadsModule {}
