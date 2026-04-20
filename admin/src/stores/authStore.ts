const TOKEN_KEY = 'admin_token';
const ADMIN_KEY = 'admin_info';

export interface AdminInfo {
  id: string;
  email: string;
  nickname: string;
  isAdmin: boolean;
}

export const authStore = {
  getToken(): string | null {
    return localStorage.getItem(TOKEN_KEY);
  },

  setToken(token: string): void {
    localStorage.setItem(TOKEN_KEY, token);
  },

  getAdmin(): AdminInfo | null {
    const raw = localStorage.getItem(ADMIN_KEY);
    if (!raw) return null;
    try {
      return JSON.parse(raw);
    } catch {
      return null;
    }
  },

  setAdmin(admin: AdminInfo): void {
    localStorage.setItem(ADMIN_KEY, JSON.stringify(admin));
  },

  clear(): void {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(ADMIN_KEY);
  },

  isLoggedIn(): boolean {
    return !!localStorage.getItem(TOKEN_KEY);
  },
};
