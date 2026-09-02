import { ApiProperty } from '@nestjs/swagger';
import {
  IsEmail,
  IsNotEmpty,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: 'admin@brightpath.edu' })
  @IsEmail({}, { message: 'Enter a valid email address' })
  email: string;

  @ApiProperty({ example: 'Admin@123' })
  @IsString()
  @IsNotEmpty({ message: 'Password is required' })
  password: string;
}

export class RefreshDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}

export class ChangePasswordDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  currentPassword: string;

  @ApiProperty({ minLength: 6 })
  @IsString()
  @MinLength(6, { message: 'New password must be at least 6 characters' })
  @MaxLength(64)
  newPassword: string;
}

export class UpdateMeDto {
  @ApiProperty({ required: false })
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  name?: string;

  @ApiProperty({ required: false })
  @IsString()
  @MaxLength(20)
  phone?: string;
}
