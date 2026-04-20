import client from './client';
import type { LoginRequest, LoginResponse } from '../types';

export const authApi = {
  login(data: LoginRequest): Promise<LoginResponse> {
    return client.post('/admin/login', data).then((res) => res.data);
  },
};
