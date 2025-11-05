import { Controller, Post, Body, UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginUserDto } from './dto/login-user.dto'; 
import { RegisterUserDto } from './dto/register-user.dto'; 
// AuthGuard'ları (korumaları) daha sonra ekleyeceğiz.


@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('login')
  async login(@Body() loginUserDto: LoginUserDto) {
    const user = await this.authService.validateUser(
        loginUserDto.email,
        loginUserDto.password,
    );
    if (!user) {
        throw new UnauthorizedException('Email veya şifre hatalı.');   
    }
    return this.authService.login(user);
  }
@Post('register')
  async register(@Body() registerUserDto: RegisterUserDto) { // DTO'yu kullan
    try {
      return await this.authService.register(registerUserDto);
    } catch (error) {
      if (error.code === 'P2002') { // Prisma'nın unique ihlali hatası
        throw new UnauthorizedException('Bu email adresi zaten kullanılıyor.');
      }
      throw error;
    }
  }
}