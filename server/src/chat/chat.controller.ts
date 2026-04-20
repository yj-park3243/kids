import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ChatService } from './chat.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ListMessagesQueryDto, SendMessageDto } from './dto/chat.dto';

@ApiTags('Chat')
@Controller('chat')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class ChatController {
  constructor(private chatService: ChatService) {}

  @Get('rooms')
  @ApiOperation({ summary: '내가 속한 채팅방 목록' })
  async myRooms(@CurrentUser('id') userId: string) {
    return this.chatService.listMyChatRooms(userId);
  }

  @Get('rooms/:roomId/messages')
  @ApiOperation({ summary: '채팅방 메시지 목록 (커서 페이징)' })
  async messages(
    @Param('roomId') roomId: string,
    @CurrentUser('id') userId: string,
    @Query() query: ListMessagesQueryDto,
  ) {
    return this.chatService.listMessages(roomId, userId, {
      cursor: query.cursor,
      limit: query.limit,
    });
  }

  @Post('rooms/:roomId/messages')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: '메시지 전송 (REST fallback, WS도 가능)' })
  async send(
    @Param('roomId') roomId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: SendMessageDto,
  ) {
    return this.chatService.sendUserMessage(roomId, userId, dto.content);
  }
}
