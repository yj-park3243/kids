import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
  Injectable,
} from '@nestjs/common';
import { Request, Response } from 'express';
import {
  TelegramService,
  escapeHtml,
} from '../services/telegram.service';

@Injectable()
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  constructor(private readonly telegramService: TelegramService) {}

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let code = 'INTERNAL_ERROR';
    let message = '서버 내부 오류가 발생했습니다.';
    let stack: string | undefined;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse();

      if (typeof exceptionResponse === 'string') {
        message = exceptionResponse;
      } else if (typeof exceptionResponse === 'object') {
        const resp = exceptionResponse as any;
        message = resp.message || exception.message;
        code = resp.code || resp.error || this.getDefaultCode(status);

        if (Array.isArray(resp.message)) {
          message = resp.message.join(', ');
          code = 'VALIDATION_ERROR';
        }
      }
    } else if (exception instanceof Error) {
      message = exception.message;
      stack = exception.stack;
      this.logger.error(
        `Unhandled exception: ${exception.message}`,
        exception.stack,
      );
    }

    // 4xx 는 디버깅용 warn 로그 (운영 DB 오염 추적용)
    if (status >= 400 && status < 500) {
      const userId = (request as any).user?.id ?? null;
      this.logger.warn(
        `${status} ${request.method} ${request.url} ` +
          `userId=${userId ?? '-'} code=${code} message=${message}`,
      );
    }

    // 서버 측 5xx 또는 HttpException 아닌 발생은 텔레그램 알림
    if (status >= 500) {
      const userId = (request as any).user?.id ?? null;
      void this.telegramService.sendAdminAlert(
        `🚨 <b>서버 ${status} 에러</b>\n` +
          `• 경로: <code>${escapeHtml(request.method)} ${escapeHtml(request.url)}</code>\n` +
          `• userId: ${userId ? `<code>${escapeHtml(userId)}</code>` : '-'}\n` +
          `• message: ${escapeHtml(message.slice(0, 500))}` +
          (stack
            ? `\n• stack:\n<pre>${escapeHtml(stack.slice(0, 1500))}</pre>`
            : ''),
      );
    }

    response.status(status).json({
      success: false,
      error: {
        code,
        message,
      },
    });
  }

  private getDefaultCode(status: number): string {
    switch (status) {
      case 400:
        return 'BAD_REQUEST';
      case 401:
        return 'UNAUTHORIZED';
      case 403:
        return 'FORBIDDEN';
      case 404:
        return 'NOT_FOUND';
      case 409:
        return 'CONFLICT';
      case 422:
        return 'VALIDATION_ERROR';
      default:
        return 'INTERNAL_ERROR';
    }
  }
}
