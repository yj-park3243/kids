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
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { AdminService } from './admin.service';
import { AdminLoginDto } from './dto/admin-login.dto';
import { AdminUserQueryDto, AdminRoomQueryDto, BanUserDto } from './dto/admin-query.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { AdminGuard } from '../common/guards/admin.guard';
import { Public } from '../common/decorators/public.decorator';

@ApiTags('Admin')
@Controller('admin')
export class AdminController {
  constructor(private adminService: AdminService) {}

  @Post('login')
  @Public()
  @ApiOperation({ summary: '관리자 로그인' })
  @HttpCode(HttpStatus.OK)
  async login(@Body() dto: AdminLoginDto) {
    return this.adminService.login(dto);
  }

  @Get('dashboard')
  @UseGuards(JwtAuthGuard, AdminGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '대시보드 통계' })
  async getDashboard() {
    return this.adminService.getDashboard();
  }

  @Get('users')
  @UseGuards(JwtAuthGuard, AdminGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '유저 목록 (페이징 + 검색)' })
  async getUsers(@Query() query: AdminUserQueryDto) {
    return this.adminService.getUsers(query);
  }

  @Get('users/:id')
  @UseGuards(JwtAuthGuard, AdminGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '유저 상세' })
  async getUserDetail(@Param('id') userId: string) {
    return this.adminService.getUserDetail(userId);
  }

  @Patch('users/:id/ban')
  @UseGuards(JwtAuthGuard, AdminGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '유저 정지/해제' })
  async banUser(@Param('id') userId: string, @Body() dto: BanUserDto) {
    return this.adminService.banUser(userId, dto.banned);
  }

  @Get('rooms')
  @UseGuards(JwtAuthGuard, AdminGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '방 목록 (페이징 + 검색)' })
  async getRooms(@Query() query: AdminRoomQueryDto) {
    return this.adminService.getRooms(query);
  }

  @Get('rooms/:id')
  @UseGuards(JwtAuthGuard, AdminGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '방 상세' })
  async getRoomDetail(@Param('id') roomId: string) {
    return this.adminService.getRoomDetail(roomId);
  }

  @Delete('rooms/:id')
  @UseGuards(JwtAuthGuard, AdminGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '방 강제 삭제' })
  async deleteRoom(@Param('id') roomId: string) {
    return this.adminService.deleteRoom(roomId);
  }
}
