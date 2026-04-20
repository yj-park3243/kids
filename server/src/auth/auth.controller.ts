import {
  Controller,
  Post,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { SocialLoginDto } from './dto/social-login.dto';
import { EmailRegisterDto } from './dto/email-register.dto';
import { EmailLoginDto } from './dto/email-login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { PhoneVerifyDto } from './dto/phone-verify.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { Public } from '../common/decorators/public.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('social')
  @Public()
  @ApiOperation({ summary: '소셜 로그인 (카카오/Apple/Google)' })
  @HttpCode(HttpStatus.OK)
  async socialLogin(@Body() dto: SocialLoginDto) {
    return this.authService.socialLogin(dto);
  }

  @Post('email/register')
  @Public()
  @ApiOperation({ summary: '이메일 회원가입' })
  @HttpCode(HttpStatus.CREATED)
  async emailRegister(@Body() dto: EmailRegisterDto) {
    return this.authService.emailRegister(dto);
  }

  @Post('email/login')
  @Public()
  @ApiOperation({ summary: '이메일 로그인' })
  @HttpCode(HttpStatus.OK)
  async emailLogin(@Body() dto: EmailLoginDto) {
    return this.authService.emailLogin(dto);
  }

  @Post('email/reset-password')
  @Public()
  @ApiOperation({ summary: '비밀번호 재설정 메일 발송' })
  @HttpCode(HttpStatus.OK)
  async resetPassword(@Body() dto: ResetPasswordDto) {
    return this.authService.requestPasswordReset(dto.email);
  }

  @Post('refresh')
  @Public()
  @ApiOperation({ summary: '토큰 재발급' })
  @HttpCode(HttpStatus.OK)
  async refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refresh(dto.refreshToken);
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '로그아웃' })
  @HttpCode(HttpStatus.OK)
  async logout(@CurrentUser('id') userId: string) {
    return this.authService.logout(userId);
  }

  @Post('phone/verify')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: '핸드폰 본인 인증 (code 없으면 발송, 있으면 검증)',
  })
  @HttpCode(HttpStatus.OK)
  async verifyPhone(
    @CurrentUser('id') userId: string,
    @Body() dto: PhoneVerifyDto,
  ) {
    return this.authService.verifyPhone(userId, dto.phoneNumber, dto.code);
  }
}
