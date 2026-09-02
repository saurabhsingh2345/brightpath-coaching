import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { AttendanceStatus } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  ValidateNested,
} from 'class-validator';

export class AttendanceEntryDto {
  @ApiProperty()
  @IsUUID('4', { message: 'Invalid student id' })
  studentId: string;

  @ApiProperty({ enum: AttendanceStatus })
  @IsEnum(AttendanceStatus, {
    message: 'Status must be PRESENT, ABSENT, LATE or LEAVE',
  })
  status: AttendanceStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  remarks?: string;
}

export class MarkAttendanceDto {
  @ApiProperty()
  @IsUUID('4', { message: 'Select a valid batch' })
  batchId: string;

  @ApiProperty({ example: '2026-09-02', description: 'YYYY-MM-DD' })
  @IsDateString({}, { message: 'Date must be a valid date' })
  date: string;

  @ApiProperty({ type: [AttendanceEntryDto] })
  @IsArray()
  @ArrayMinSize(1, { message: 'Mark at least one student' })
  @ValidateNested({ each: true })
  @Type(() => AttendanceEntryDto)
  entries: AttendanceEntryDto[];
}

export class AttendanceSheetQueryDto {
  @ApiProperty()
  @IsUUID('4', { message: 'Select a valid batch' })
  batchId: string;

  @ApiProperty({ example: '2026-09-02' })
  @IsDateString({}, { message: 'Date must be a valid date' })
  date: string;
}

export class AttendanceHistoryQueryDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  batchId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  studentId?: string;

  @ApiPropertyOptional({ example: '2026-08-01' })
  @IsOptional()
  @IsDateString()
  from?: string;

  @ApiPropertyOptional({ example: '2026-09-02' })
  @IsOptional()
  @IsDateString()
  to?: string;

  @ApiPropertyOptional({ enum: AttendanceStatus })
  @IsOptional()
  @IsEnum(AttendanceStatus)
  status?: AttendanceStatus;
}
