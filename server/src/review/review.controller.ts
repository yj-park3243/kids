import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { ReviewService } from './review.service';
import { CreateReviewDto } from './dto/create-review.dto';
import { UpdateReviewDto } from './dto/update-review.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Reviews')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller()
export class ReviewController {
  constructor(private reviewService: ReviewService) {}

  @Post('rooms/:roomId/reviews')
  @ApiOperation({ summary: '후기 등록' })
  async create(
    @CurrentUser('id') userId: string,
    @Param('roomId') roomId: string,
    @Body() dto: CreateReviewDto,
  ) {
    return this.reviewService.create(roomId, userId, dto);
  }

  @Patch('reviews/:reviewId')
  @ApiOperation({ summary: '후기 수정 (7일 이내)' })
  async update(
    @CurrentUser('id') userId: string,
    @Param('reviewId') reviewId: string,
    @Body() dto: UpdateReviewDto,
  ) {
    return this.reviewService.update(reviewId, userId, dto);
  }

  @Delete('reviews/:reviewId')
  @ApiOperation({ summary: '후기 삭제 (7일 이내)' })
  async delete(
    @CurrentUser('id') userId: string,
    @Param('reviewId') reviewId: string,
  ) {
    return this.reviewService.delete(reviewId, userId);
  }

  @Get('users/:userId/reviews')
  @ApiOperation({ summary: '받은 후기 집계 (익명)' })
  async getUserReviews(@Param('userId') userId: string) {
    return this.reviewService.getUserReviewsAggregate(userId);
  }
}
