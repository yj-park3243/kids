import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { NotificationService } from './notification.service';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationController {
  constructor(private notificationService: NotificationService) {}

  @Post('device-token')
  @ApiOperation({ summary: '디바이스 토큰 등록' })
  async registerDeviceToken(
    @CurrentUser('id') userId: string,
    @Body() dto: RegisterDeviceTokenDto,
  ) {
    return this.notificationService.registerDeviceToken(
      userId,
      dto.token,
      dto.platform,
    );
  }

  @Get()
  @ApiOperation({ summary: '알림 목록 조회' })
  async findAll(
    @CurrentUser('id') userId: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: number,
  ) {
    return this.notificationService.findAll(userId, cursor, limit || 20);
  }

  @Patch(':id/read')
  @ApiOperation({ summary: '알림 읽음 처리' })
  async markAsRead(
    @CurrentUser('id') userId: string,
    @Param('id') notificationId: string,
  ) {
    return this.notificationService.markAsRead(userId, notificationId);
  }

  @Patch('read-all')
  @ApiOperation({ summary: '전체 읽음 처리' })
  async markAllAsRead(@CurrentUser('id') userId: string) {
    return this.notificationService.markAllAsRead(userId);
  }

  @Get('unread-count')
  @ApiOperation({ summary: '안읽은 알림 수' })
  async getUnreadCount(@CurrentUser('id') userId: string) {
    return this.notificationService.getUnreadCount(userId);
  }
}
