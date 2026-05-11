import {
  Controller,
  Post,
  Body,
  Req,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtService } from '@nestjs/jwt';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { Public } from '../common/decorators/public.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { SupportService } from './support.service';
import {
  CreateErrorLogDto,
  CreateInquiryDto,
  CreateReportDto,
} from './dto/support.dto';

@ApiTags('Support')
@Controller()
export class SupportController {
  constructor(
    private supportService: SupportService,
    private jwtService: JwtService,
  ) {}

  // ─── 앱 에러 리포팅 ── 인증 선택적 ──
  @Post('error-logs')
  @Public()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: '앱 에러 리포팅 (인증 선택)' })
  async createErrorLog(@Body() dto: CreateErrorLogDto, @Req() req: any) {
    // Authorization 헤더 있으면 userId 추출, 없거나 실패하면 null
    let userId: string | null = null;
    const auth: string | undefined = req.headers?.authorization;
    if (auth?.startsWith('Bearer ')) {
      try {
        const payload = this.jwtService.verify<{ sub: string; type?: string }>(
          auth.slice(7),
          { issuer: 'kids-app' },
        );
        if (!payload.type || payload.type === 'access') {
          userId = payload.sub;
        }
      } catch {
        // 토큰 무효해도 에러 로그는 받음
      }
    }
    return this.supportService.createErrorLog(userId, dto);
  }

  @Post('support/inquiry')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: '1:1 문의 작성' })
  async createInquiry(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateInquiryDto,
  ) {
    return this.supportService.createInquiry(userId, dto);
  }

  @Post('support/report')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: '유저/방 신고' })
  async createReport(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateReportDto,
  ) {
    return this.supportService.createReport(userId, dto);
  }
}
