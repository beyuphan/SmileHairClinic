import { Module } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { UsersModule } from '../users/users.module'; // UsersService'i kullanmak için
import { PassportModule } from '@nestjs/passport';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config'; // .env'yi okumak için
import { JwtStrategy } from './jwt.strategy';
import { JwtAuthGuard } from './jwt-auth.guard';
import { RolesGuard } from './roles.guard'


@Module({
  imports: [
    UsersModule,
    PassportModule,
    ConfigModule,
    JwtModule.registerAsync({
      imports: [ConfigModule], // ConfigService'i içeri aktar
      useFactory: async (configService: ConfigService) => ({
        secret: configService.getOrThrow<string>('JWT_SECRET'), // .env'den al
        signOptions: { expiresIn: '1d' }, // Token'lar 1 gün geçerli
      }),
      inject: [ConfigService], // ConfigService'i enjekte et
    }),
    JwtModule,
  ],
  providers: [AuthService, JwtStrategy,JwtAuthGuard, RolesGuard], 
  controllers: [AuthController],
  exports: [JwtModule, AuthService, JwtAuthGuard, RolesGuard], 
})
export class AuthModule {}