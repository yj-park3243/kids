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
import { UserService } from './user.service';
import { CreateProfileDto } from './dto/create-profile.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { DeleteUserDto } from './dto/delete-user.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UserController {
  constructor(private userService: UserService) {}

  @Post('profile')
  @ApiOperation({ summary: '프로필 초기 설정' })
  async createProfile(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateProfileDto,
  ) {
    return this.userService.createProfile(userId, dto);
  }

  @Get('me')
  @ApiOperation({ summary: '내 프로필 조회' })
  async getMe(@CurrentUser('id') userId: string) {
    return this.userService.getMe(userId);
  }

  @Patch('me')
  @ApiOperation({ summary: '내 프로필 수정' })
  async updateMe(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.userService.updateMe(userId, dto);
  }

  @Get('check-nickname')
  @ApiOperation({ summary: '닉네임 중복 체크' })
  async checkNickname(@Query('nickname') nickname: string) {
    return this.userService.checkNickname(nickname);
  }

  @Get(':userId')
  @ApiOperation({ summary: '다른 유저 프로필 조회' })
  async getUserById(@Param('userId') userId: string) {
    return this.userService.getUserById(userId);
  }

  @Delete('me')
  @ApiOperation({ summary: '회원 탈퇴' })
  async deleteMe(
    @CurrentUser('id') userId: string,
    @Body() dto: DeleteUserDto,
  ) {
    return this.userService.deleteMe(userId, dto.reason);
  }
}
