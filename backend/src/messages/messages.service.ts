import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Message } from './message.entity';

@Injectable()
export class MessagesService {
  constructor(
    @InjectRepository(Message)
    private messagesRepository: Repository<Message>,
  ) {}

  async findAll(): Promise<Message[]> {
    return this.messagesRepository.find({
      order: { timestamp: 'DESC' },
    });
  }

  async create(text: string): Promise<Message> {
    const message = this.messagesRepository.create({ text });
    return this.messagesRepository.save(message);
  }
}
