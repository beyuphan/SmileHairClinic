import { Injectable, UnauthorizedException } from '@nestjs/common';
import { UsersService } from '../users/users.service';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
  ) {}

  // 1. Adım: Login Kontrolü
  async validateUser(email: string, pass: string): Promise<any> {
    const user = await this.usersService.findByEmail(email);
    if (user && (await bcrypt.compare(pass, user.passwordHash))) {
      const { passwordHash, ...result } = user;
      return result;
    }
    return null;
  }

  // 2. Adım: Token Oluşturma
  async login(user: any) {
    const payload = { email: user.email, sub: user.id, role: user.role };
    return {
      accessToken: this.jwtService.sign(payload),
    };
  }

  // 3. Adım: Kayıt (Register)
  async register(createUserDto: any) {
    // TODO: DTO (Veri Aktarım Nesnesi) kullan
    return this.usersService.create(createUserDto);
  }

  async verifySocketToken(client: any): Promise<any> {
    const authHeader = client.handshake.headers.authorization;
    if (!authHeader) {
      throw new UnauthorizedException('Authorization header bulunamadı');
    }

    const token = authHeader.split(' ')[1];
    if (!token) {
      throw new UnauthorizedException('Token bulunamadı (Bearer formatı yanlış)');
    }

    try {
      // 1. Token'ı doğrula (JwtService zaten inject edilmişti)
      const payload = await this.jwtService.verifyAsync(token, {
        secret: process.env.JWT_SECRET || 'your-secret-key', // JwtModule'deki secret'ın aynısı
      });

      // 2. Token'dan 'sub' (yani user ID) ile kullanıcıyı bul
      const user = await this.usersService.findById(payload.sub); // Not: users.service'te findById lazım
      if (!user) {
        throw new UnauthorizedException('User not found');
      }
      return user;
    } catch (e) {
      throw new UnauthorizedException('Invalid token');
    }
  }
}