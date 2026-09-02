import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { FeesService } from './fees.service';
import {
  CreateFeeDto,
  CreateFeePlanDto,
  QueryFeesDto,
  RecordPaymentDto,
  UpdateFeeDto,
} from './dto/fee.dto';

@ApiTags('fees')
@ApiBearerAuth()
@Controller('fees')
export class FeesController {
  constructor(private readonly fees: FeesService) {}

  @Roles(Role.ADMIN)
  @Get()
  @ApiOperation({ summary: 'List fee installments (filter by student/batch/status)' })
  findAll(@Query() query: QueryFeesDto) {
    return this.fees.findAll(query);
  }

  @Roles(Role.STUDENT)
  @Get('me')
  @ApiOperation({ summary: "Logged-in student's own fee ledger" })
  mine(@CurrentUser() user: AuthUser) {
    if (!user.studentId) {
      throw new BadRequestException('No student profile linked to this account');
    }
    return this.fees.studentFees(user.studentId, user);
  }

  @Roles(Role.ADMIN)
  @Get('payments')
  payments(
    @Query('studentId') studentId?: string,
    @Query('feeId') feeId?: string,
  ) {
    return this.fees.payments({ studentId, feeId });
  }

  @Get('receipt/:paymentId')
  @ApiOperation({ summary: 'Receipt data for a payment' })
  receipt(
    @Param('paymentId', ParseUUIDPipe) paymentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.fees.receipt(paymentId, user);
  }

  @Get('student/:studentId')
  studentFees(
    @Param('studentId', ParseUUIDPipe) studentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.fees.studentFees(studentId, user);
  }

  @Get(':id')
  findOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.fees.findOne(id, user);
  }

  @Roles(Role.ADMIN)
  @Post('plan')
  @ApiOperation({ summary: 'Create a multi-installment fee plan for a student' })
  createPlan(@Body() dto: CreateFeePlanDto) {
    return this.fees.createPlan(dto);
  }

  @Roles(Role.ADMIN)
  @Post()
  create(@Body() dto: CreateFeeDto) {
    return this.fees.create(dto);
  }

  @Roles(Role.ADMIN)
  @Post(':id/payments')
  @ApiOperation({ summary: 'Record a full or partial payment' })
  recordPayment(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RecordPaymentDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.fees.recordPayment(id, dto, userId);
  }

  @Roles(Role.ADMIN)
  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateFeeDto) {
    return this.fees.update(id, dto);
  }

  @Roles(Role.ADMIN)
  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.fees.remove(id);
  }
}
