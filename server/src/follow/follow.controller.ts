import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { FollowService } from './follow.service';
import { CreateFollowDto } from './dto/create-follow.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Follows')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('follows')
export class FollowController {
  constructor(private followService: FollowService) {}

  @Post()
  @ApiOperation({ summary: '팔로우' })
  async follow(@CurrentUser('id') userId: string, @Body() dto: CreateFollowDto) {
    return this.followService.follow(userId, dto.targetUserId);
  }

  @Delete(':targetUserId')
  @ApiOperation({ summary: '언팔로우' })
  @HttpCode(HttpStatus.OK)
  async unfollow(
    @CurrentUser('id') userId: string,
    @Param('targetUserId') targetUserId: string,
  ) {
    return this.followService.unfollow(userId, targetUserId);
  }

  @Get('me')
  @ApiOperation({ summary: '내 팔로잉 목록' })
  async getMyFollowing(@CurrentUser('id') userId: string) {
    return this.followService.getMyFollowing(userId);
  }
}
