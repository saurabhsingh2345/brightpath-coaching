import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class ExamSubjectDto {
  @ApiProperty({ example: 'Physics' })
  @IsString()
  @IsNotEmpty({ message: 'Subject name is required' })
  @MaxLength(60)
  name: string;

  @ApiProperty({ example: 100 })
  @Type(() => Number)
  @IsInt()
  @Min(1, { message: 'Max marks must be at least 1' })
  @Max(1000)
  maxMarks: number;
}

export class CreateExamDto {
  @ApiProperty()
  @IsUUID('4', { message: 'Select a valid batch' })
  batchId: string;

  @ApiProperty({ example: 'Monthly Test - September' })
  @IsString()
  @IsNotEmpty({ message: 'Exam name is required' })
  @MaxLength(100)
  name: string;

  @ApiProperty({ example: '2026-09-20' })
  @IsDateString({}, { message: 'Exam date must be a valid date' })
  examDate: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(400)
  description?: string;

  @ApiProperty({ type: [ExamSubjectDto] })
  @IsArray()
  @ArrayMinSize(1, { message: 'Add at least one subject' })
  @ValidateNested({ each: true })
  @Type(() => ExamSubjectDto)
  subjects: ExamSubjectDto[];
}

export class UpdateExamDto extends PartialType(CreateExamDto) {
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isPublished?: boolean;
}

export class SubjectMarkDto {
  @ApiProperty({ example: 'Physics' })
  @IsString()
  @IsNotEmpty()
  subject: string;

  @ApiProperty({ example: 78 })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0, { message: 'Marks cannot be negative' })
  marksObtained: number;
}

export class EnterResultDto {
  @ApiProperty()
  @IsUUID('4', { message: 'Select a valid student' })
  studentId: string;

  @ApiProperty({ type: [SubjectMarkDto] })
  @IsArray()
  @ArrayMinSize(1, { message: 'Enter marks for at least one subject' })
  @ValidateNested({ each: true })
  @Type(() => SubjectMarkDto)
  marks: SubjectMarkDto[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  remarks?: string;
}

export class BulkResultsDto {
  @ApiProperty({ type: [EnterResultDto] })
  @IsArray()
  @ArrayMinSize(1, { message: 'Nothing to save' })
  @ValidateNested({ each: true })
  @Type(() => EnterResultDto)
  results: EnterResultDto[];
}
