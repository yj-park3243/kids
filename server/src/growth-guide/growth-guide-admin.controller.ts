import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  ParseIntPipe,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { GrowthGuideService, GuideView } from './growth-guide.service';
import { CreateGuideDto } from './dto/create-guide.dto';
import { UpdateGuideDto } from './dto/update-guide.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { AdminGuard } from '../common/guards/admin.guard';

@ApiTags('Admin - GrowthGuide')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin/guides')
export class GrowthGuideAdminController {
  constructor(private guideService: GrowthGuideService) {}

  @Get()
  @ApiOperation({ summary: '가이드 전체 목록 (어드민)' })
  async findAll(): Promise<GuideView[]> {
    return this.guideService.findAll();
  }

  @Post()
  @ApiOperation({ summary: '가이드 생성' })
  async create(@Body() dto: CreateGuideDto): Promise<GuideView> {
    return this.guideService.create(dto);
  }

  @Patch(':ageMonth')
  @ApiOperation({ summary: '가이드 수정' })
  async update(
    @Param('ageMonth', ParseIntPipe) ageMonth: number,
    @Body() dto: UpdateGuideDto,
  ): Promise<GuideView> {
    return this.guideService.update(ageMonth, dto);
  }

  @Delete(':ageMonth')
  @ApiOperation({ summary: '가이드 삭제' })
  async delete(@Param('ageMonth', ParseIntPipe) ageMonth: number) {
    return this.guideService.delete(ageMonth);
  }
}
