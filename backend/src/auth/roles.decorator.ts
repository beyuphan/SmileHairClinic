// backend/src/auth/roles.decorator.ts
import { SetMetadata } from '@nestjs/common';
import { Role } from '@prisma/client'; // schema.prisma'dan gelen enum

export const ROLES_KEY = 'roles';
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);