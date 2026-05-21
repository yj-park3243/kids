import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { NoticeService } from './notice.service';
import { CreateNoticeDto } from './dto/create-notice.dto';
import { UpdateNoticeDto } from './dto/update-notice.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { AdminGuard } from '../common/guards/admin.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Admin - Notice')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin/notices')
export class NoticeAdminController {
  constructor(private noticeService: NoticeService) {}

  @Get()
  @ApiOperation({ summary: '공지사항 전체 목록 (어드민)' })
  async findAll(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.noticeService.findAllForAdmin(
      page ? parseInt(page, 10) : 1,
      limit ? parseInt(limit, 10) : 20,
    );
  }

  @Get(':id')
  @ApiOperation({ summary: '공지사항 상세 (어드민)' })
  async findOne(@Param('id') id: string) {
    return this.noticeService.findOne(id);
  }

  @Post()
  @ApiOperation({ summary: '공지사항 생성' })
  async create(
    @Body() dto: CreateNoticeDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.noticeService.create(dto, userId ?? null);
  }

  @Patch(':id')
  @ApiOperation({ summary: '공지사항 수정' })
  async update(@Param('id') id: string, @Body() dto: UpdateNoticeDto) {
    return this.noticeService.update(id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: '공지사항 삭제' })
  async delete(@Param('id') id: string) {
    return this.noticeService.delete(id);
  }
}
