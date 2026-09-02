import { Body, Controller, Get, HttpCode, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { IsIn, IsString } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { MaintenanceService } from './maintenance.service';

/** Typing the phrase is what makes this deliberate rather than a stray tap. */
export class ClearDemoDataDto {
  @ApiProperty({ example: 'CLEAR DEMO DATA' })
  @IsString()
  @IsIn(['CLEAR DEMO DATA'], {
    message: 'Type CLEAR DEMO DATA exactly to confirm',
  })
  confirm: string;
}

@ApiTags('maintenance')
@ApiBearerAuth()
@Roles(Role.ADMIN)
@Controller('maintenance')
export class MaintenanceController {
  constructor(private readonly maintenance: MaintenanceService) {}

  @Get('demo-summary')
  @ApiOperation({ summary: 'What the demo dataset currently contains' })
  summary() {
    return this.maintenance.demoSummary();
  }

  @Post('clear-demo-data')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Delete every seeded demo row. Institute data is never touched.',
  })
  clear(@Body() _dto: ClearDemoDataDto, @CurrentUser() user: AuthUser) {
    return this.maintenance.clearDemoData(user);
  }
}
