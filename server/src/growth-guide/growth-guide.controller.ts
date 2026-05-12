import {
  Controller,
  Get,
  Param,
  ParseIntPipe,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { GrowthGuideService, GuideView } from './growth-guide.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('GrowthGuide')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('guides')
export class GrowthGuideController {
  constructor(private guideService: GrowthGuideService) {}

  @Get()
  @ApiOperation({ summary: '발달 가이드 목록' })
  async findAll(): Promise<GuideView[]> {
    return this.guideService.findAll();
  }

  @Get(':ageMonth')
  @ApiOperation({ summary: '발달 가이드 상세 (추천 모임 포함)' })
  async findOne(
    @Param('ageMonth', ParseIntPipe) ageMonth: number,
    @CurrentUser('id') userId: string,
  ) {
    return this.guideService.findByAgeMonth(ageMonth, userId);
  }
}
