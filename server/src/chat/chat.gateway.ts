import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { ChatMessage } from './entities/chat-message.entity';

interface SocketWithUser extends Socket {
  userId?: string;
}

@WebSocketGateway({
  namespace: '/chat',
  cors: { origin: '*' },
})
export class ChatGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(ChatGateway.name);

  @WebSocketServer()
  server: Server;

  constructor(private jwtService: JwtService) {}

  handleConnection(client: SocketWithUser) {
    try {
      const token =
        (client.handshake.auth?.token as string | undefined) ??
        (client.handshake.headers.authorization as string | undefined)?.replace(
          /^Bearer\s+/i,
          '',
        );
      if (!token) {
        client.disconnect();
        return;
      }
      const payload = this.jwtService.verify(token);
      client.userId = payload.sub;
      this.logger.log(`chat connect ${client.id} user=${payload.sub}`);
    } catch (err) {
      this.logger.warn(`chat auth failed: ${err}`);
      client.disconnect();
    }
  }

  handleDisconnect(client: SocketWithUser) {
    this.logger.log(`chat disconnect ${client.id}`);
  }

  @SubscribeMessage('join')
  handleJoin(
    @ConnectedSocket() client: SocketWithUser,
    @MessageBody() data: { roomId: string },
  ) {
    if (!client.userId || !data?.roomId) return { ok: false };
    client.join(`room:${data.roomId}`);
    return { ok: true };
  }

  @SubscribeMessage('leave')
  handleLeave(
    @ConnectedSocket() client: SocketWithUser,
    @MessageBody() data: { roomId: string },
  ) {
    if (!data?.roomId) return { ok: false };
    client.leave(`room:${data.roomId}`);
    return { ok: true };
  }

  /**
   * Called from ChatService after a message is persisted.
   */
  broadcastMessage(roomId: string, message: ChatMessage) {
    this.server.to(`room:${roomId}`).emit('message', {
      id: message.id,
      roomId: message.roomId,
      senderId: message.senderId,
      senderNickname: message.senderNickname,
      content: message.content,
      type: message.type,
      createdAt: message.createdAt.toISOString(),
    });
  }
}
