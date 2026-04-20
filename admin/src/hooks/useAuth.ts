import { useState, useCallback, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { authStore } from '../stores/authStore';
import type { AdminInfo } from '../stores/authStore';
import { authApi } from '../api/auth';
import { message } from 'antd';

export function useAuth() {
  const [isLoggedIn, setIsLoggedIn] = useState(authStore.isLoggedIn());
  const [admin, setAdmin] = useState<AdminInfo | null>(authStore.getAdmin());
  const navigate = useNavigate();

  useEffect(() => {
    setIsLoggedIn(authStore.isLoggedIn());
    setAdmin(authStore.getAdmin());
  }, []);

  const login = useCallback(
    async (email: string, password: string) => {
      try {
        const res = await authApi.login({ email, password });
        authStore.setToken(res.accessToken);
        authStore.setAdmin(res.user);
        setIsLoggedIn(true);
        setAdmin(res.user);
        message.success('로그인 성공');
        navigate('/dashboard');
      } catch (err: unknown) {
        const error = err as { response?: { data?: { success?: boolean; error?: { code?: string; message?: string } } } };
        const msg = error.response?.data?.error?.message || '로그인에 실패했습니다.';
        message.error(msg);
        throw err;
      }
    },
    [navigate]
  );

  const logout = useCallback(() => {
    authStore.clear();
    setIsLoggedIn(false);
    setAdmin(null);
    message.info('로그아웃되었습니다.');
    navigate('/login');
  }, [navigate]);

  return { isLoggedIn, admin, login, logout };
}
