import {
  Controller,
  Get,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { ReportService } from './report.service';
import { ResolveReportDto, AdminReportListQueryDto } from './dto/resolve-report.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { AdminGuard } from '../common/guards/admin.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Admin Reports')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin/reports')
export class ReportAdminController {
  constructor(private reportService: ReportService) {}

  @Get()
  @ApiOperation({ summary: '신고 큐 조회' })
  async findAll(@Query() query: AdminReportListQueryDto) {
    return this.reportService.findAllAdmin(query);
  }

  @Patch(':id')
  @ApiOperation({ summary: '신고 처리' })
  async resolve(
    @Param('id') reportId: string,
    @CurrentUser('id') adminId: string,
    @Body() dto: ResolveReportDto,
  ) {
    return this.reportService.resolveAdmin(reportId, adminId, dto);
  }
}
