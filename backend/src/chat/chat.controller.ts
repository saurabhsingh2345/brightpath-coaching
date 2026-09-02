import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { ChatService } from './chat.service';
import { ChatGateway } from './chat.gateway';
import {
  MessagesQueryDto,
  SendMessageDto,
  StartDirectDto,
} from './dto/chat.dto';

@ApiTags('chat')
@ApiBearerAuth()
@Controller('chat')
export class ChatController {
  constructor(
    private readonly chat: ChatService,
    private readonly gateway: ChatGateway,
  ) {}

  @Get('conversations')
  @ApiOperation({
    summary: 'Every thread the caller belongs to, with unread counts',
  })
  list(@CurrentUser() user: AuthUser) {
    return this.chat.list(user);
  }

  @Get('unread')
  @ApiOperation({ summary: 'Total unread messages, for the tab badge' })
  unread(@CurrentUser('id') userId: string) {
    return this.chat.unreadTotal(userId);
  }

  @Get('contacts')
  @ApiOperation({
    summary: 'People the caller may start a direct thread with',
  })
  contacts(
    @CurrentUser() user: AuthUser,
    @Query('search') search?: string,
  ) {
    return this.chat.contacts(user, search);
  }

  @Post('direct')
  @ApiOperation({ summary: 'Open or create a 1:1 thread' })
  startDirect(
    @Body() dto: StartDirectDto,
    @CurrentUser() user: AuthUser,
  ) {
    return this.chat.startDirect(dto.userId, user);
  }

  @Roles(Role.ADMIN)
  @Post('batch/:batchId')
  @ApiOperation({ summary: 'Create/repair the group thread for a batch' })
  async ensureBatch(@Param('batchId', ParseUUIDPipe) batchId: string) {
    const conversation = await this.chat.ensureBatchConversation(batchId);
    return { id: conversation.id };
  }

  @Get('conversations/:id/messages')
  messages(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() query: MessagesQueryDto,
    @CurrentUser() user: AuthUser,
  ) {
    return this.chat.messages(id, user, query);
  }

  @Post('conversations/:id/messages')
  @ApiOperation({ summary: 'Send a message (also pushed over the socket)' })
  async send(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SendMessageDto,
    @CurrentUser() user: AuthUser,
  ) {
    const message = await this.chat.send(id, dto, user);
    const recipients = await this.chat.participantIds(id);

    // The sender already has the message from this response; push to the rest.
    const others = recipients.filter((r) => r !== user.id);
    this.gateway.emitMessage(others, { ...message, isMine: false });
    this.gateway.emitConversationUpdate(recipients, id);

    return message;
  }

  @Patch('conversations/:id/read')
  markRead(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.chat.markRead(id, user);
  }

  @Roles(Role.ADMIN)
  @Patch('conversations/:id/lock')
  lock(@Param('id', ParseUUIDPipe) id: string) {
    return this.chat.setLocked(id, true);
  }

  @Roles(Role.ADMIN)
  @Patch('conversations/:id/unlock')
  unlock(@Param('id', ParseUUIDPipe) id: string) {
    return this.chat.setLocked(id, false);
  }

  @Delete('messages/:messageId')
  @ApiOperation({ summary: 'Soft-delete a message' })
  async remove(
    @Param('messageId', ParseUUIDPipe) messageId: string,
    @CurrentUser() user: AuthUser,
  ) {
    const message = await this.chat.deleteMessage(messageId, user);
    const recipients = await this.chat.participantIds(message.conversationId);
    this.gateway.emitMessage(
      recipients.filter((r) => r !== user.id),
      { ...message, isMine: false },
    );
    return message;
  }
}
