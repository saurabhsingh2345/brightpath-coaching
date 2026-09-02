import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { PaginationDto } from '../../common/dto/pagination.dto';

export class CreateBatchDto {
  @ApiProperty({ example: 'JEE Morning A' })
  @IsString()
  @MinLength(2, { message: 'Batch name must be at least 2 characters' })
  @MaxLength(60)
  name: string;

  @ApiProperty({ example: 'JEE Main 2027' })
  @IsString()
  @IsNotEmpty({ message: 'Course is required' })
  @MaxLength(80)
  course: string;

  @ApiProperty({ example: 'Physics, Chemistry, Maths' })
  @IsString()
  @IsNotEmpty({ message: 'Subject is required' })
  @MaxLength(120)
  subject: string;

  @ApiProperty({ example: '07:00 AM - 09:00 AM' })
  @IsString()
  @IsNotEmpty({ message: 'Timing is required' })
  @MaxLength(60)
  timing: string;

  @ApiProperty({ example: 'Room 101' })
  @IsString()
  @IsNotEmpty({ message: 'Room is required' })
  @MaxLength(40)
  room: string;

  @ApiPropertyOptional({ default: 40 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(500)
  capacity?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  startDate?: string;
}

export class UpdateBatchDto extends PartialType(CreateBatchDto) {
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class QueryBatchesDto extends PaginationDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Transform(({ value }) =>
    value === undefined || value === '' ? undefined : value === 'true' || value === true,
  )
  @IsBoolean()
  isActive?: boolean;
}

export class AssignStudentsDto {
  @ApiProperty({ type: [String] })
  @IsString({ each: true })
  studentIds: string[];
}
