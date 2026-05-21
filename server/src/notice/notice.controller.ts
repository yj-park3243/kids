import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { NoticeService } from './notice.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';

@ApiTags('Notice')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notices')
export class NoticeController {
  constructor(private noticeService: NoticeService) {}

  @Get()
  @ApiOperation({ summary: '공지사항 목록' })
  async findAll(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.noticeService.findPublished(
      page ? parseInt(page, 10) : 1,
      limit ? parseInt(limit, 10) : 20,
    );
  }

  @Get('pinned')
  @ApiOperation({ summary: '홈 노출용 고정 공지' })
  async findPinned() {
    return this.noticeService.findPinned();
  }

  @Get(':id')
  @ApiOperation({ summary: '공지사항 상세' })
  async findOne(@Param('id') id: string) {
    return this.noticeService.findOne(id);
  }
}
