import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { DashboardService } from './dashboard.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Dashboard')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('dashboard')
export class DashboardController {
  constructor(private dashboardService: DashboardService) {}

  @Get('me')
  @ApiOperation({
    summary: '홈 탭 활동 일지 — 누적 통계 + 자주 만나는 친구 + 최근 사진 + 이번 달 모임 날짜',
  })
  async getMyDashboard(@CurrentUser('id') userId: string) {
    return this.dashboardService.getMyDashboard(userId);
  }
}
