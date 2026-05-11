import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../../user/entities/user.entity';

export interface JwtPayload {
  sub: string;
  email?: string;
  isAdmin?: boolean;
  type?: 'access' | 'refresh';
  iss?: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private configService: ConfigService,
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get('JWT_SECRET'),
      issuer: 'kids-app',
    });
  }

  async validate(payload: JwtPayload) {
    // refresh 토큰을 보호 라우트에 못 쓰게 차단
    if (payload.type && payload.type !== 'access') {
      throw new UnauthorizedException('access 토큰이 필요합니다.');
    }

    const user = await this.userRepository.findOne({
      where: { id: payload.sub },
    });

    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('유효하지 않은 사용자입니다.');
    }

    return {
      id: user.id,
      email: user.email,
      nickname: user.nickname,
      isAdmin: user.isAdmin,
      isProfileComplete: user.isProfileComplete,
    };
  }
}
