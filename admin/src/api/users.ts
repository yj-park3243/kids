import client from './client';
import type { PaginatedResponse, User, UserDetail } from '../types';

export interface UsersQuery {
  page?: number;
  limit?: number;
  search?: string;
}

export const usersApi = {
  getUsers(params: UsersQuery): Promise<PaginatedResponse<User>> {
    return client.get('/admin/users', { params }).then((res) => res.data);
  },

  getUser(id: string): Promise<UserDetail> {
    return client.get(`/admin/users/${id}`).then((res) => res.data);
  },

  banUser(id: string, banned: boolean): Promise<{ success: boolean; status: string }> {
    return client.patch(`/admin/users/${id}/ban`, { banned }).then((res) => res.data);
  },
};
