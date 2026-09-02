import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { FeeStatus, PaymentMode } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { PaginationDto } from '../../common/dto/pagination.dto';

export class InstallmentDto {
  @ApiProperty({ example: 'Term 1' })
  @IsString()
  @IsNotEmpty({ message: 'Installment title is required' })
  @MaxLength(80)
  title: string;

  @ApiProperty({ example: 15000 })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive({ message: 'Amount must be greater than zero' })
  amount: number;

  @ApiProperty({ example: '2026-10-05' })
  @IsDateString({}, { message: 'Due date must be a valid date' })
  dueDate: string;
}

/** Create a fee plan: one row per installment. */
export class CreateFeePlanDto {
  @ApiProperty()
  @IsUUID('4', { message: 'Select a valid student' })
  studentId: string;

  @ApiProperty({ type: [InstallmentDto] })
  @IsArray()
  @ArrayMinSize(1, { message: 'Add at least one installment' })
  @ValidateNested({ each: true })
  @Type(() => InstallmentDto)
  installments: InstallmentDto[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(300)
  notes?: string;
}

export class CreateFeeDto {
  @ApiProperty()
  @IsUUID('4')
  studentId: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  title: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive({ message: 'Amount must be greater than zero' })
  totalAmount: number;

  @ApiProperty()
  @IsDateString()
  dueDate: string;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  installmentNo?: number;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  totalInstallments?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(300)
  notes?: string;
}

export class UpdateFeeDto extends PartialType(CreateFeeDto) {}

export class RecordPaymentDto {
  @ApiProperty({ example: 5000 })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive({ message: 'Payment amount must be greater than zero' })
  amount: number;

  @ApiPropertyOptional({ enum: PaymentMode, default: PaymentMode.CASH })
  @IsOptional()
  @IsEnum(PaymentMode, { message: 'Invalid payment mode' })
  mode?: PaymentMode;

  @ApiPropertyOptional({ description: 'UPI ref / cheque no / txn id' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  reference?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  paidAt?: string;
}

export class QueryFeesDto extends PaginationDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  studentId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  batchId?: string;

  @ApiPropertyOptional({ enum: FeeStatus })
  @IsOptional()
  @IsEnum(FeeStatus)
  status?: FeeStatus;
}
