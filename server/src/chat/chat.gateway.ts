import { Logger, Inject, forwardRef } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import type { ChatMessageView } from './chat.service';
import { ChatService } from './chat.service';

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

  constructor(
    private jwtService: JwtService,
    @Inject(forwardRef(() => ChatService))
    private chatService: ChatService,
  ) {}

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
      // fetchSockets() 는 RemoteSocket.data 만 노출하므로 userId 를 data 에도 저장.
      client.data.userId = payload.sub;
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

  @SubscribeMessage('read')
  async handleRead(
    @ConnectedSocket() client: SocketWithUser,
    @MessageBody() data: { roomId: string; asOf?: string },
  ) {
    if (!client.userId || !data?.roomId) return { ok: false };
    try {
      const { lastReadAt } = await this.chatService.markRoomRead(
        data.roomId,
        client.userId,
        data.asOf,
      );
      return { ok: true, lastReadAt };
    } catch (err) {
      this.logger.warn(`read failed: ${err}`);
      return { ok: false };
    }
  }

  /**
   * Called from ChatService after a message is persisted.
   */
  broadcastMessage(roomId: string, message: ChatMessageView) {
    this.server.to(`room:${roomId}`).emit('message', {
      id: message.id,
      roomId: message.roomId,
      senderId: message.senderId,
      senderNickname: message.senderNickname,
      content: message.content,
      type: message.type,
      createdAt: message.createdAt.toISOString(),
      unreadCount: message.unreadCount,
    });
  }

  /**
   * 현재 해당 채팅방 소켓에 접속해 있는 userId 집합.
   * 채팅 푸시 발송 시 "지금 방을 보고 있는" 사람을 제외하는 데 쓴다.
   */
  async getActiveUserIds(roomId: string): Promise<Set<string>> {
    const ids = new Set<string>();
    try {
      const sockets = await this.server.in(`room:${roomId}`).fetchSockets();
      for (const s of sockets) {
        const uid = (s.data as { userId?: string })?.userId;
        if (uid) ids.add(uid);
      }
    } catch (err) {
      this.logger.warn(`getActiveUserIds failed: ${err}`);
    }
    return ids;
  }

  /**
   * Notify the room that `userId` has read up to `asOf` — other clients use this to
   * decrement their unread badges on messages older than `asOf`.
   */
  broadcastRead(roomId: string, userId: string, asOf: Date) {
    this.server.to(`room:${roomId}`).emit('read', {
      roomId,
      userId,
      lastReadAt: asOf.toISOString(),
    });
  }
}
