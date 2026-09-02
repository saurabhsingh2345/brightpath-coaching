import { Module } from '@nestjs/common';
import { FeesModule } from '../fees/fees.module';
import { TimetableModule } from '../timetable/timetable.module';
import { DashboardController } from './dashboard.controller';
import { DashboardService } from './dashboard.service';

@Module({
  imports: [FeesModule, TimetableModule],
  controllers: [DashboardController],
  providers: [DashboardService],
})
export class DashboardModule {}
