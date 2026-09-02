import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Weekday } from '@prisma/client';
import {
  IsDateString,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
} from 'class-validator';

const HHMM = /^([01]\d|2[0-3]):([0-5]\d)$/;

export class CreateTimetableSlotDto {
  @ApiProperty()
  @IsUUID('4', { message: 'Select a valid batch' })
  batchId: string;

  @ApiProperty({ example: 'Physics' })
  @IsString()
  @IsNotEmpty({ message: 'Subject is required' })
  @MaxLength(80)
  subject: string;

  @ApiPropertyOptional({ example: 'Mr. Verma' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  teacher?: string;

  @ApiProperty({ enum: Weekday })
  @IsEnum(Weekday, { message: 'Pick a valid weekday' })
  weekday: Weekday;

  @ApiProperty({ example: '07:00', description: '24h HH:mm' })
  @Matches(HHMM, { message: 'Start time must be in HH:mm format' })
  startTime: string;

  @ApiProperty({ example: '09:00', description: '24h HH:mm' })
  @Matches(HHMM, { message: 'End time must be in HH:mm format' })
  endTime: string;

  @ApiProperty({ example: 'Room 101' })
  @IsString()
  @IsNotEmpty({ message: 'Room is required' })
  @MaxLength(40)
  room: string;

  @ApiPropertyOptional({
    description: 'Set only for a one-off / extra class on a specific date',
  })
  @IsOptional()
  @IsDateString()
  date?: string;
}

export class UpdateTimetableSlotDto extends PartialType(
  CreateTimetableSlotDto,
) {}
