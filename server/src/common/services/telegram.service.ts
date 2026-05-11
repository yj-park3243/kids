import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * 텔레그램 관리자 알림 서비스 (match 패턴 포팅)
 *
 * - TELEGRAM_BOT_TOKEN, TELEGRAM_ADMIN_CHAT_ID 둘 다 있어야 동작
 * - 비즈니스 로직 깨지지 않도록 fail-silent (catch 후 console.info)
 * - HTML parse_mode 사용: 사용자 입력은 반드시 escapeHtml()
 */

const TG_API_BASE = 'https://api.telegram.org';

@Injectable()
export class TelegramService {
  private readonly logger = new Logger(TelegramService.name);

  constructor(private readonly configService: ConfigService) {}

  private get botToken(): string {
    return this.configService.get<string>('TELEGRAM_BOT_TOKEN', '');
  }

  private get chatId(): string {
    return this.configService.get<string>('TELEGRAM_ADMIN_CHAT_ID', '');
  }

  private isConfigured(): boolean {
    return Boolean(this.botToken && this.chatId);
  }

  /** 관리자 채널/DM 으로 메시지 전송 (fail-silent). */
  async sendAdminAlert(message: string): Promise<void> {
    if (!this.isConfigured()) return;

    try {
      const url = `${TG_API_BASE}/bot${this.botToken}/sendMessage`;
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: this.chatId,
          text: message,
          parse_mode: 'HTML',
          disable_web_page_preview: true,
        }),
      });
      if (!res.ok) {
        const text = await res.text().catch(() => '');
        this.logger.warn(`sendMessage failed: ${res.status} ${text}`);
      }
    } catch (err) {
      this.logger.warn(`send error: ${(err as Error).message}`);
    }
  }

  /** Chat ID 검색용 헬퍼 (bot에 누가 메시지 보낸 다음 1회 호출) */
  async discoverAdminChatId(): Promise<string | null> {
    if (!this.botToken) return null;
    try {
      const url = `${TG_API_BASE}/bot${this.botToken}/getUpdates`;
      const res = await fetch(url);
      const json = (await res.json()) as { ok: boolean; result?: any[] };
      if (!json.ok || !json.result || json.result.length === 0) return null;
      const last = json.result[json.result.length - 1];
      const chatId = last?.message?.chat?.id ?? last?.my_chat_member?.chat?.id;
      return chatId ? String(chatId) : null;
    } catch (err) {
      this.logger.warn(`discoverAdminChatId error: ${(err as Error).message}`);
      return null;
    }
  }
}

/** 텔레그램 HTML mode 에서 위험한 문자 이스케이프 */
export function escapeHtml(input: unknown): string {
  return String(input ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}
