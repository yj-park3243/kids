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
import { RoomService } from './room.service';
import { RoomParticipationService } from './room-participation.service';
import { CreateRoomDto } from './dto/create-room.dto';
import { UpdateRoomDto } from './dto/update-room.dto';
import { RoomQueryDto, MapQueryDto, MyRoomQueryDto, JoinActionDto } from './dto/room-query.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Rooms')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('rooms')
export class RoomController {
  constructor(
    private roomService: RoomService,
    private roomParticipationService: RoomParticipationService,
  ) {}

  @Post()
  @ApiOperation({ summary: '방 생성' })
  async create(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateRoomDto,
  ) {
    return this.roomService.create(userId, dto);
  }

  @Get('my')
  @ApiOperation({ summary: '내 모임 목록' })
  async getMyRooms(
    @CurrentUser('id') userId: string,
    @Query() query: MyRoomQueryDto,
  ) {
    return this.roomService.getMyRooms(userId, query);
  }

  @Get('map')
  @ApiOperation({ summary: '지도 뷰용 방 조회' })
  async getMapRooms(@Query() query: MapQueryDto) {
    return this.roomService.getMapRooms(query);
  }

  @Get()
  @ApiOperation({ summary: '방 목록 조회 (약속날짜 지난 방 제외)' })
  async findAll(
    @CurrentUser('id') userId: string,
    @Query() query: RoomQueryDto,
  ) {
    return this.roomService.findAll(userId, query);
  }

  @Get(':roomId')
  @ApiOperation({ summary: '방 상세 조회' })
  async getDetail(
    @CurrentUser('id') userId: string,
    @Param('roomId') roomId: string,
  ) {
    return this.roomService.getDetail(roomId, userId);
  }

  @Patch(':roomId')
  @ApiOperation({ summary: '방 수정 (방장)' })
  async update(
    @CurrentUser('id') userId: string,
    @Param('roomId') roomId: string,
    @Body() dto: UpdateRoomDto,
  ) {
    return this.roomService.update(userId, roomId, dto);
  }

  @Delete(':roomId')
  @ApiOperation({ summary: '방 취소 (방장)' })
  async cancel(
    @CurrentUser('id') userId: string,
    @Param('roomId') roomId: string,
  ) {
    return this.roomService.cancel(userId, roomId);
  }

  @Post(':roomId/join')
  @ApiOperation({ summary: '참여 신청' })
  async join(
    @CurrentUser('id') userId: string,
    @Param('roomId') roomId: string,
  ) {
    return this.roomParticipationService.join(userId, roomId);
  }

  @Delete(':roomId/join')
  @ApiOperation({ summary: '참여 취소' })
  async cancelJoin(
    @CurrentUser('id') userId: string,
    @Param('roomId') roomId: string,
  ) {
    return this.roomParticipationService.cancelJoin(userId, roomId);
  }

  @Get(':roomId/join-requests')
  @ApiOperation({ summary: '참여 신청 목록 (방장)' })
  async getJoinRequests(
    @CurrentUser('id') userId: string,
    @Param('roomId') roomId: string,
  ) {
    return this.roomParticipationService.getJoinRequests(userId, roomId);
  }

  @Patch(':roomId/join-requests/:requestId')
  @ApiOperation({ summary: '신청 수락/거절 (방장)' })
  async handleJoinRequest(
    @CurrentUser('id') userId: string,
    @Param('roomId') roomId: string,
    @Param('requestId') requestId: string,
    @Body() dto: JoinActionDto,
  ) {
    return this.roomParticipationService.handleJoinRequest(
      userId,
      roomId,
      requestId,
      dto.action,
    );
  }

  @Delete(':roomId/members/:userId')
  @ApiOperation({ summary: '참여자 강퇴 (방장)' })
  async kickMember(
    @CurrentUser('id') hostUserId: string,
    @Param('roomId') roomId: string,
    @Param('userId') targetUserId: string,
  ) {
    return this.roomParticipationService.kickMember(
      hostUserId,
      roomId,
      targetUserId,
    );
  }
}
