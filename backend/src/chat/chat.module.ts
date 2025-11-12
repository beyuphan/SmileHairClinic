import { Module } from '@nestjs/common';
import { ChatGateway } from './chat.gateway';
import { AuthModule } from '../auth/auth.module'; // <-- GÜVENLİK İÇİN
import { PrismaModule } from '../prisma/prisma.module'; // <-- VERİTABANI İÇİN
import { ChatController } from './chat.controller';

@Module({
  imports: [AuthModule, PrismaModule], // <-- BU İKİSİNİ EKLE
  providers: [ChatGateway], controllers: [ChatController], // Gateway'i (kapıyı) tanıt
})
export class ChatModule {}