import {
  Controller,
  Get,
  Post,
  Query,
  Body,
  Res,
  UseGuards,
  HttpCode,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import type { Response } from 'express';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { KcpService } from './kcp.service';

@ApiTags('Auth')
@Controller('auth/kcp')
export class KcpController {
  private readonly logger = new Logger(KcpController.name);

  constructor(private readonly kcpService: KcpService) {}

  // ─── GET /auth/kcp/form — KCP 인증 HTML Form 생성 ───
  @Get('form')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'KCP 본인인증 HTML Form 생성' })
  async getForm(
    @CurrentUser('id') userId: string,
    @Query('returnUrl') returnUrl?: string,
  ) {
    const html = await this.kcpService.generateCertForm(userId, returnUrl);
    return { html };
  }

  // ─── POST /auth/kcp/callback — KCP가 직접 호출하는 콜백 ───
  // 인증 불필요. 결과를 처리해 앱 딥링크로 리다이렉트하는 HTML 응답.
  @Post('callback')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'KCP 본인인증 콜백 (KCP → 서버)' })
  async callback(
    @Body() body: Record<string, any>,
    @Query() query: Record<string, any>,
    @Res() res: Response,
  ) {
    try {
      this.logger.log(
        `[KCP Callback] bodyKeys=${Object.keys(body || {})} queryKeys=${Object.keys(query || {})}`,
      );

      const { userId, kcpData } = await this.kcpService.handleCallback(
        body || {},
        query || {},
      );
      const result = await this.kcpService.verifyCert(userId, kcpData);
      const appUrl = this.kcpService.buildSuccessRedirect(result);
      // [진단] 토큰 발급/딥링크 전달 상태 — 본인인증 후 401(토큰 유실) 원인 추적용.
      this.logger.log(
        `[KCP Callback] redirect urlLen=${appUrl.length} atLen=${result.accessToken?.length ?? 0} rtLen=${result.refreshToken?.length ?? 0} merged=${result.merged === true} next=${result.nextRoute} userId=${result.user?.id}`,
      );

      const html = `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>인증 완료</title></head>
<body>
<script>window.location.href = '${appUrl}';</script>
<p>인증이 완료되었습니다. 앱으로 이동 중...</p>
<a href="${appUrl}">앱으로 이동</a>
</body></html>`;

      res
        .status(200)
        .header('Content-Type', 'text/html; charset=utf-8')
        .send(html);
    } catch (err: any) {
      // raw 메시지 그대로 노출 방지 — PG QueryFailedError (code 23505) 또는
      // typeorm/pg 의 "duplicate key ... unique constraint" 메시지는 친화 문구로.
      const raw = err?.response?.message || err?.message || '';
      const isUniqueViolation =
        err?.code === '23505' ||
        err?.driverError?.code === '23505' ||
        /duplicate key|unique constraint/i.test(String(raw));
      // 사용자가 이미 인증된 계정으로 재시도하는 정상 케이스 — ERROR 알람이 시끄러우니 WARN.
      if (isUniqueViolation) {
        this.logger.warn(`[KCP Callback] 중복 인증 시도 (이미 사용 중)`);
      } else {
        this.logger.error(`[KCP Callback] ${raw || err?.message || 'unknown'}`);
      }
      const message = isUniqueViolation
        ? '이미 다른 계정에서 사용 중인 본인인증 정보입니다. 고객센터에 문의해 주세요.'
        : raw || '인증에 실패했습니다.';
      const appUrl = this.kcpService.buildErrorRedirect(String(message));

      const html = `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>인증 실패</title></head>
<body>
<script>window.location.href = '${appUrl}';</script>
<p>인증에 실패했습니다. 앱으로 이동 중...</p>
<a href="${appUrl}">앱으로 이동</a>
</body></html>`;

      res
        .status(200)
        .header('Content-Type', 'text/html; charset=utf-8')
        .send(html);
    }
  }
}
