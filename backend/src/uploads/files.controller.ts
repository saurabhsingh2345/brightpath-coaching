import {
  Controller,
  Get,
  Header,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Res,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Response } from 'express';
import { Public } from '../common/decorators/public.decorator';
import { UploadsService } from './uploads.service';

/**
 * Serves database-stored uploads.
 *
 * Deliberately public: study material is opened by the device's PDF viewer or
 * browser, which cannot attach a bearer token. URLs contain an unguessable
 * uuid, and nothing sensitive is stored here.
 */
@ApiTags('files')
@Controller('files')
export class FilesController {
  constructor(private readonly uploads: UploadsService) {}

  @Public()
  @Get(':id')
  @Header('Cache-Control', 'public, max-age=31536000, immutable')
  @ApiOperation({ summary: 'Download an uploaded document' })
  async download(
    @Param('id', ParseUUIDPipe) id: string,
    @Res() res: Response,
  ) {
    const file = await this.uploads.read(id);
    if (!file) throw new NotFoundException('File not found');

    res.setHeader('Content-Type', file.mimeType);
    res.setHeader('Content-Length', file.size);
    // inline so PDFs open in a viewer instead of forcing a download
    res.setHeader(
      'Content-Disposition',
      `inline; filename="${encodeURIComponent(file.fileName)}"`,
    );
    res.end(file.data);
  }
}
