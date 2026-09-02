import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { AnnouncementAudience } from '@prisma/client';
import {
  IsBoolean,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateAnnouncementDto {
  @ApiProperty({ example: 'Diwali break' })
  @IsString()
  @MinLength(3, { message: 'Title must be at least 3 characters' })
  @MaxLength(120)
  title: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty({ message: 'Message body is required' })
  @MaxLength(2000)
  body: string;

  @ApiProperty({
    enum: AnnouncementAudience,
    description: 'ALL = every student, BATCH = one batch',
  })
  @IsEnum(AnnouncementAudience, { message: 'Audience must be ALL or BATCH' })
  audience: AnnouncementAudience;

  @ApiPropertyOptional({ description: 'Required when audience is BATCH' })
  @IsOptional()
  @IsUUID('4', { message: 'Select a valid batch' })
  batchId?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isPinned?: boolean;
}

export class UpdateAnnouncementDto extends PartialType(
  CreateAnnouncementDto,
) {}
