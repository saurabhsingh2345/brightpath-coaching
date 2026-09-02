import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';
import { PaginationDto } from '../../common/dto/pagination.dto';

export class CreateStudentDto {
  @ApiProperty({ example: 'Aarav Sharma' })
  @IsString()
  @MinLength(2, { message: 'Name must be at least 2 characters' })
  @MaxLength(80)
  name: string;

  @ApiPropertyOptional({
    description: 'Leave blank to auto-generate (BP2026001 style)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(24)
  studentCode?: string;

  @ApiProperty({ example: '9876543210' })
  @IsString()
  @MinLength(6, { message: 'Enter a valid phone number' })
  @MaxLength(20)
  phone: string;

  @ApiProperty({ example: 'aarav@example.com' })
  @IsEmail({}, { message: 'Enter a valid email address' })
  email: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty({ message: 'Parent name is required' })
  @MaxLength(80)
  parentName: string;

  @ApiProperty()
  @IsString()
  @MinLength(6, { message: 'Enter a valid parent phone number' })
  @MaxLength(20)
  parentPhone: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty({ message: 'Address is required' })
  @MaxLength(240)
  address: string;

  @ApiProperty({ example: 'JEE Main 2027' })
  @IsString()
  @IsNotEmpty({ message: 'Course is required' })
  @MaxLength(80)
  course: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4', { message: 'Select a valid batch' })
  batchId?: string;

  @ApiPropertyOptional({ description: 'ISO date. Defaults to today.' })
  @IsOptional()
  @IsDateString({}, { message: 'Admission date must be a valid date' })
  admissionDate?: string;

  @ApiPropertyOptional({
    description: 'Login password. Defaults to Student@123.',
  })
  @IsOptional()
  @IsString()
  @MinLength(6)
  password?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}

export class UpdateStudentDto extends PartialType(CreateStudentDto) {
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class QueryStudentsDto extends PaginationDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  batchId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  course?: string;

  @ApiPropertyOptional({ description: 'true | false | omit for all' })
  @IsOptional()
  @Transform(({ value }) =>
    value === undefined || value === '' ? undefined : value === 'true' || value === true,
  )
  @IsBoolean()
  isActive?: boolean;
}
