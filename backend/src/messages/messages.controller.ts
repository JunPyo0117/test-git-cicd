import { Controller, Get, Post, Body } from '@nestjs/common';
import { MessagesService } from './messages.service';
import { Message } from './message.entity';

@Controller('messages')
export class MessagesController {
  constructor(private readonly messagesService: MessagesService) {}

  @Get()
  async findAll(): Promise<Message[]> {
    return this.messagesService.findAll();
  }

  @Post()
  async create(@Body() createMessageDto: { text: string }): Promise<Message> {
    return this.messagesService.create(createMessageDto.text);
  }

  @Get('health')
  async healthCheck(): Promise<{ status: string; timestamp: string }> {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
    };
  }
}
