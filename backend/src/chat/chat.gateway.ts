import { Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Live message push. The REST API stays the source of truth: the gateway only
 * broadcasts what was already persisted, so a client that misses a socket
 * event still gets everything on its next poll or refresh.
 *
 * Each user joins a private room named `user:<id>`, so a message is delivered
 * by fanning it out to the conversation's participant ids. That avoids having
 * to track room membership as batches change.
 */
@WebSocketGateway({
  namespace: '/chat',
  cors: { origin: true, credentials: true },
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(ChatGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const token =
        (client.handshake.auth?.token as string | undefined) ??
        (client.handshake.query?.token as string | undefined) ??
        (client.handshake.headers.authorization as string | undefined)?.replace(
          /^Bearer\s+/i,
          '',
        );

      if (!token) throw new UnauthorizedException('No token');

      const payload = await this.jwt.verifyAsync<{ sub: string }>(token, {
        secret: this.config.get<string>('JWT_ACCESS_SECRET'),
      });

      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
        select: { id: true, isActive: true },
      });
      if (!user || !user.isActive) throw new UnauthorizedException();

      client.data.userId = user.id;
      await client.join(`user:${user.id}`);
      client.emit('ready', { userId: user.id });
    } catch {
      // Never leave an unauthenticated socket connected.
      client.emit('unauthorized', {
        message: 'Socket authentication failed',
      });
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    if (client.data?.userId) {
      this.logger.debug(`socket closed for ${client.data.userId}`);
    }
  }

  /** Push a persisted message to everyone in the conversation. */
  emitMessage(recipientIds: string[], message: unknown) {
    for (const id of recipientIds) {
      this.server?.to(`user:${id}`).emit('message', message);
    }
  }

  /** Nudge clients to refresh their conversation list / unread badges. */
  emitConversationUpdate(recipientIds: string[], conversationId: string) {
    for (const id of recipientIds) {
      this.server?.to(`user:${id}`).emit('conversation', { conversationId });
    }
  }
}
