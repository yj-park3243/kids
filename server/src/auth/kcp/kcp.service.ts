import {
  Injectable,
  Logger,
  BadRequestException,
  BadGatewayException,
  NotFoundException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../../user/entities/user.entity';
import { RefreshToken } from '../entities/refresh-token.entity';
import { SocialAccount } from '../entities/social-account.entity';
import { TokenService } from '../token.service';
import { encryptJson, decryptJson } from './kcp-crypto';
import { KcpRawResult, KcpVerifyResult } from './kcp.types';

// ─── KCP 본인확인 V2 (API 기반) — match 프로젝트와 동일 키 ───
const KCP_SITE_CD = 'ALQ1Q';
const KCP_ENC_KEY =
  'eaa433b5da2ae426aa0d637e46c5644436c104870fa1eabd4af6e7f26e9536df';
const KCP_CERT_REG_URL = 'https://cert.kcp.co.kr/api/reg/certDataReg.do';
const KCP_CERT_GET_URL = 'https://cert.kcp.co.kr/api/query/getCertData.do';

const ORDER_TTL_MS = 30 * 60 * 1000; // 30분
const FETCH_TIMEOUT_MS = 10000;

type OrderEntry = { userId: string; reg_cert_key: string; expiresAt: number };

@Injectable()
export class KcpService {
  private readonly logger = new Logger(KcpService.name);

  // ordr_idxx → {userId, reg_cert_key} 매핑 (Redis 대체용 인메모리)
  private readonly orderMap = new Map<string, OrderEntry>();

  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(RefreshToken)
    private readonly refreshTokenRepository: Repository<RefreshToken>,
    @InjectRepository(SocialAccount)
    private readonly socialAccountRepository: Repository<SocialAccount>,
    private readonly tokenService: TokenService,
    private readonly configService: ConfigService,
  ) {}

  /** 기본 콜백 URL — 환경변수 미지정 시 prod 서버 IP 기준 */
  private getCallbackUrl(): string {
    return (
      this.configService.get<string>('KCP_RET_URL') ||
      'https://api.growtogether.kr/v1/auth/kcp/callback'
    );
  }

  /** 앱 딥링크 스킴 — kids 전용 */
  private getAppScheme(): string {
    return this.configService.get<string>('KCP_APP_SCHEME') || 'kids';
  }

  // ─── 1. 거래등록 + WebView용 HTML form 반환 ───
  async generateCertForm(userId: string, returnUrl?: string): Promise<string> {
    this.cleanupExpiredOrders();

    const ordr_idxx = `ORD${Date.now()}${Math.floor(Math.random() * 1000)}`;
    const baseRet = returnUrl?.startsWith('http') ? returnUrl : this.getCallbackUrl();
    const ret = `${baseRet}${baseRet.includes('?') ? '&' : '?'}ordr_idxx=${ordr_idxx}`;

    const regPayload = {
      site_cd: KCP_SITE_CD,
      ordr_idxx,
      Ret_URL: ret,
      web_siteid: '',
      param_opt_1: '',
      param_opt_2: '',
      param_opt_3: '',
    };
    const { enc_data, rv } = encryptJson(regPayload, KCP_ENC_KEY, KCP_SITE_CD);

    let regResponse: Response;
    try {
      regResponse = await fetch(KCP_CERT_REG_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          site_cd: KCP_SITE_CD,
          rv,
        },
        body: enc_data,
        signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
      });
    } catch (e: any) {
      this.logger.error(`[KCP CertReg] network error: ${e?.message}`);
      throw new BadGatewayException('KCP 거래등록 서버에 연결할 수 없습니다.');
    }

    const regResult = (await regResponse.json()) as Record<string, any>;
    this.logger.log(`[KCP CertReg] ${JSON.stringify(regResult)}`);

    if (regResult.res_cd !== '0000') {
      throw new BadGatewayException(
        `KCP 거래등록 실패: ${regResult.res_msg || regResult.res_cd}`,
      );
    }

    const call_url: string = regResult.call_url;
    const reg_cert_key: string = regResult.reg_cert_key;

    this.orderMap.set(ordr_idxx, {
      userId,
      reg_cert_key,
      expiresAt: Date.now() + ORDER_TTL_MS,
    });

    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>본인인증</title>
</head>
<body>
  <form id="form_auth" name="form_auth" method="post" action="${call_url}">
    <input type="hidden" name="call_url" value="${call_url}">
    <input type="hidden" name="reg_cert_key" value="${reg_cert_key}">
    <input type="hidden" name="kcp_page_submit_yn" value="Y">
  </form>
  <script>document.getElementById('form_auth').submit();</script>
</body>
</html>`;
  }

  // ─── 2. KCP 콜백 처리 ───
  async handleCallback(
    body: Record<string, any>,
    query: Record<string, any> = {},
  ): Promise<{ userId: string; kcpData: KcpRawResult }> {
    const { res_cd, res_msg } = body;
    const ordr_idxx: string | undefined = query.ordr_idxx || body.ordr_idxx;

    this.logger.log(
      `[KCP Callback] res_cd=${res_cd}, ordr_idxx=${ordr_idxx}, bodyKeys=${Object.keys(body)}`,
    );

    if (res_cd === '9999') {
      throw new BadRequestException('사용자가 본인인증을 취소했습니다.');
    }
    if (res_cd !== '0000') {
      throw new BadRequestException(`KCP 인증 실패: ${res_msg || res_cd}`);
    }
    if (!ordr_idxx) {
      throw new BadRequestException('KCP 콜백 ordr_idxx가 누락되었습니다.');
    }

    const entry = this.orderMap.get(ordr_idxx);
    if (!entry || entry.expiresAt < Date.now()) {
      this.orderMap.delete(ordr_idxx);
      throw new BadRequestException('인증 세션이 만료되었습니다.');
    }

    const decrypted = await this.fetchAndDecryptCertData(
      ordr_idxx,
      entry.reg_cert_key,
    );
    this.orderMap.delete(ordr_idxx);

    return { userId: entry.userId, kcpData: decrypted };
  }

  // ─── 3. 결과 조회 + 복호화 ───
  private async fetchAndDecryptCertData(
    ordr_idxx: string,
    reg_cert_key: string,
  ): Promise<KcpRawResult> {
    const reqBody = { site_cd: KCP_SITE_CD, reg_cert_key, ordr_idxx };

    let response: Response;
    try {
      response = await fetch(KCP_CERT_GET_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          site_cd: KCP_SITE_CD,
        },
        body: JSON.stringify(reqBody),
        signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
      });
    } catch (e: any) {
      this.logger.error(`[KCP CertGet] network error: ${e?.message}`);
      throw new BadGatewayException('KCP 결과 조회 서버에 연결할 수 없습니다.');
    }

    const result = (await response.json()) as Record<string, any>;
    this.logger.log(
      `[KCP CertGet] res_cd=${result.res_cd} res_msg=${result.res_msg}`,
    );

    if (result.res_cd !== '0000') {
      throw new BadGatewayException(
        `KCP 결과 조회 실패: ${result.res_msg || result.res_cd}`,
      );
    }

    const decrypted = decryptJson<Record<string, string>>(
      result.enc_cert_data,
      result.rv,
      KCP_ENC_KEY,
      KCP_SITE_CD,
    );

    const ci = decrypted.CI || '';
    const di = decrypted.DI || '';
    const phoneNumber = decrypted.phone_no || '';
    const realName = decrypted.user_name || '';
    const birthDate = decrypted.birth_day || '';
    const gender =
      decrypted.gender || decrypted.sex_code || decrypted.sex || '';
    const carrier = decrypted.comm_id || decrypted.local_code || '';

    if (!ci && !phoneNumber) {
      this.logger.error(
        `[KCP CertGet] No CI/phone in decrypted: ${Object.keys(decrypted)}`,
      );
      throw new BadRequestException(
        'KCP 인증 결과에서 사용자 정보를 찾을 수 없습니다.',
      );
    }

    return { ci, di, phoneNumber, gender, birthDate, realName, carrier };
  }

  // ─── 4. 유저 정보 저장 + CI 중복 처리 ───
  async verifyCert(
    userId: string,
    kcpData: KcpRawResult,
  ): Promise<KcpVerifyResult> {
    const existingUser = kcpData.ci
      ? await this.userRepository.findOne({ where: { ci: kcpData.ci } })
      : null;

    const currentUser = await this.userRepository.findOne({
      where: { id: userId },
    });
    if (!currentUser) {
      throw new NotFoundException('사용자를 찾을 수 없습니다.');
    }

    if (existingUser && existingUser.id !== userId) {
      return await this.handleDuplicateCi(currentUser, existingUser, kcpData);
    }

    const birthDate = this.parseBirthDate(kcpData.birthDate);
    const gender = this.normalizeGender(kcpData.gender);

    await this.userRepository.update(userId, {
      phoneNumber: kcpData.phoneNumber,
      ci: kcpData.ci || undefined,
      di: kcpData.di || undefined,
      realName: kcpData.realName || undefined,
      carrier: kcpData.carrier || undefined,
      isVerified: true,
      isPhoneVerified: true,
      verifiedAt: new Date(),
      ...(gender ? { gender } : {}),
      ...(birthDate ? { birthDate } : {}),
    });

    const updated = await this.userRepository.findOne({ where: { id: userId } });
    if (!updated) throw new NotFoundException('사용자를 찾을 수 없습니다.');

    const tokens = await this.issueTokens(updated);

    return {
      ...tokens,
      user: {
        id: updated.id,
        nickname: updated.nickname ?? null,
        profileImageUrl: updated.profileImageUrl ?? null,
        isNewUser: !updated.isProfileComplete,
        isVerified: true,
        phoneNumber: kcpData.phoneNumber,
      },
      nextRoute: updated.isProfileComplete ? 'home' : 'profile-setup',
    };
  }

  // ─── CI 중복 처리 ───
  private async handleDuplicateCi(
    currentUser: User,
    existingUser: User,
    kcpData: KcpRawResult,
  ): Promise<KcpVerifyResult> {
    if (existingUser.status === 'BANNED') {
      // 신규 가입 차단 + 임시 유저 정리
      await this.refreshTokenRepository.delete({ userId: currentUser.id });
      await this.userRepository.delete({ id: currentUser.id });
      throw new ForbiddenException('해당 정보로는 가입이 불가합니다.');
    }

    if (existingUser.status === 'WITHDRAWN') {
      // 탈퇴 계정의 unique 컬럼들(ci, phoneNumber)을 비워 같은 사람이
      // 재가입할 때 currentUser 쪽에 동일 ci/phone 부여해도 충돌 안 나게 한다.
      // (이전엔 phoneNumber 만 회피했고 ci 가 그대로라 PASS 재인증 시
      //  UQ_user_ci 위반 → "duplicate key value violates unique constraint" 노출)
      await this.userRepository.update(existingUser.id, {
        ci: null as any,
        di: null as any,
        phoneNumber: existingUser.phoneNumber
          ? `${existingUser.phoneNumber}+0`
          : (null as any),
      });

      const birthDate = this.parseBirthDate(kcpData.birthDate);
      const gender = this.normalizeGender(kcpData.gender);

      await this.userRepository.update(currentUser.id, {
        phoneNumber: kcpData.phoneNumber,
        ci: kcpData.ci || undefined,
        di: kcpData.di || undefined,
        realName: kcpData.realName || undefined,
        carrier: kcpData.carrier || undefined,
        isVerified: true,
        isPhoneVerified: true,
        verifiedAt: new Date(),
        ...(gender ? { gender } : {}),
        ...(birthDate ? { birthDate } : {}),
      });

      const updated = await this.userRepository.findOne({
        where: { id: currentUser.id },
      });
      if (!updated) throw new NotFoundException('사용자를 찾을 수 없습니다.');

      const tokens = await this.issueTokens(updated);
      return {
        ...tokens,
        user: {
          id: updated.id,
          nickname: updated.nickname ?? null,
          profileImageUrl: updated.profileImageUrl ?? null,
          isNewUser: true,
          isVerified: true,
          phoneNumber: kcpData.phoneNumber,
        },
        nextRoute: 'profile-setup',
      };
    }

    // ACTIVE → 기존 계정 로그인 처리 (단순 병합)
    // 임시 유저의 소셜 연결(카카오 등)을 기존 유저로 먼저 이관한다.
    // 이관 없이 delete 하면 social_account 가 CASCADE 로 같이 지워져
    // 다음 소셜 로그인 때 또 임시 유저가 생기고 본인인증을 반복하게 된다.
    await this.socialAccountRepository.update(
      { userId: currentUser.id },
      { userId: existingUser.id },
    );

    // 신규 임시 유저(currentUser) 정리 후 기존 유저로 토큰 발급
    await this.refreshTokenRepository.delete({ userId: currentUser.id });
    await this.userRepository.delete({ id: currentUser.id });

    await this.userRepository.update(existingUser.id, {
      isVerified: true,
      isPhoneVerified: true,
      verifiedAt: new Date(),
    });
    const updatedExisting = await this.userRepository.findOne({
      where: { id: existingUser.id },
    });
    if (!updatedExisting) {
      throw new ConflictException('계정 처리 중 오류가 발생했습니다.');
    }

    const tokens = await this.issueTokens(updatedExisting);
    return {
      ...tokens,
      merged: true,
      user: {
        id: updatedExisting.id,
        nickname: updatedExisting.nickname ?? null,
        profileImageUrl: updatedExisting.profileImageUrl ?? null,
        isNewUser: false,
        isVerified: true,
        phoneNumber: updatedExisting.phoneNumber ?? kcpData.phoneNumber,
      },
      nextRoute: 'home',
    };
  }

  // ─── 토큰 발급 ───
  // TokenService 로 서명해야 iss/type claim 이 붙는다. 이전엔 JwtService 로
  // 직접 서명해 iss 가 빠졌고, JwtStrategy(issuer 검증)가 전부 401 처리 →
  // 인증 직후 홈 로드 실패 + 앱 재시작 시 세션 증발 버그의 원인이었다.
  private async issueTokens(
    user: User,
  ): Promise<{ accessToken: string; refreshToken: string }> {
    const tokens = this.tokenService.issueTokenPair({
      sub: user.id,
      email: user.email,
      isAdmin: user.isAdmin,
    });

    // auth.service.issueAndStoreTokens 와 동일: 1 user 1 active refresh.
    await this.refreshTokenRepository.delete({ userId: user.id });
    await this.refreshTokenRepository.upsert(
      {
        userId: user.id,
        token: tokens.refreshToken,
        expiresAt: this.tokenService.refreshExpiresAt(tokens.refreshToken),
      },
      { conflictPaths: ['token'] },
    );

    return tokens;
  }

  // ─── 앱 리다이렉트 URL 빌드 ───
  buildSuccessRedirect(result: KcpVerifyResult): string {
    const scheme = this.getAppScheme();
    const params = new URLSearchParams({
      status: 'success',
      userId: result.user.id,
      nickname: result.user.nickname ?? '',
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      nextRoute: result.nextRoute,
      isNewUser: String(result.user.isNewUser),
      merged: result.merged === true ? 'true' : 'false',
    });
    return `${scheme}://kcp-cert?${params.toString()}`;
  }

  buildErrorRedirect(message: string): string {
    const scheme = this.getAppScheme();
    const params = new URLSearchParams({ status: 'error', message });
    return `${scheme}://kcp-cert?${params.toString()}`;
  }

  // ─── helpers ───
  private parseBirthDate(yyyymmdd: string): Date | null {
    if (!yyyymmdd || yyyymmdd.length !== 8) return null;
    const year = parseInt(yyyymmdd.slice(0, 4), 10);
    const month = parseInt(yyyymmdd.slice(4, 6), 10) - 1;
    const day = parseInt(yyyymmdd.slice(6, 8), 10);
    const date = new Date(year, month, day);
    if (isNaN(date.getTime())) return null;
    return date;
  }

  private normalizeGender(raw: string): string | null {
    if (raw === 'M' || raw === '1' || raw === '01') return 'MALE';
    if (raw === 'F' || raw === '0' || raw === '02') return 'FEMALE';
    return null;
  }

  private cleanupExpiredOrders(): void {
    const now = Date.now();
    for (const [k, v] of this.orderMap.entries()) {
      if (v.expiresAt < now) this.orderMap.delete(k);
    }
  }
}
