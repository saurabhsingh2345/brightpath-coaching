import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class SendMessageDto {
  @ApiProperty({ example: 'Sir, I could not follow todays rotation problem.' })
  @IsString()
  @IsNotEmpty({ message: 'Message cannot be empty' })
  @MaxLength(4000, { message: 'Message is too long' })
  body: string;
}

/** Start (or re-open) a 1:1 thread with another user. */
export class StartDirectDto {
  @ApiProperty({ description: 'The other participant (a user id)' })
  @IsUUID('4', { message: 'Pick a valid person to message' })
  userId: string;
}

export class MessagesQueryDto {
  @ApiPropertyOptional({
    description: 'Return messages created before this ISO timestamp',
  })
  @IsOptional()
  @IsString()
  before?: string;

  @ApiPropertyOptional({ default: 40, maximum: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}
