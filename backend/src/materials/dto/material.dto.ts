import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';

/** Multipart body that accompanies the uploaded file. */
export class CreateMaterialDto {
  @ApiProperty({ example: 'Rotational Motion - Class Notes' })
  @IsString()
  @IsNotEmpty({ message: 'Title is required' })
  @MaxLength(120)
  title: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(400)
  description?: string;

  @ApiProperty({ example: 'Physics' })
  @IsString()
  @IsNotEmpty({ message: 'Subject is required' })
  @MaxLength(80)
  subject: string;

  @ApiPropertyOptional({
    description: 'Leave empty to share with every batch',
  })
  @IsOptional()
  @IsUUID('4', { message: 'Select a valid batch' })
  batchId?: string;
}

export class UpdateMaterialDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(120)
  title?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(400)
  description?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(80)
  subject?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  batchId?: string;
}
