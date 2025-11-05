import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';
import { User } from '@prisma/client';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  // Yeni kullanıcı yarat (şifreyi hash'leyerek)
  async create(data: any): Promise<Omit<User, 'passwordHash'>> {
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(data.password, salt);

    const user = await this.prisma.user.create({
      data: {
        email: data.email,
        passwordHash: passwordHash,
        role: 'patient', // Varsayılan rol
      },
    });

    // Asla şifreyi geri döndürme
    const { passwordHash: _, ...result } = user;
    return result;
  }

  // Email'e göre kullanıcı bul (login için)
  async findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({
      where: { email },
    });
  }
}