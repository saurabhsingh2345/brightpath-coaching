import { SetMetadata } from '@nestjs/common';
import { Role } from '@prisma/client';

export const ROLES_KEY = 'roles';

/** Restrict a route (or controller) to the given roles. */
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);
