import axios from 'axios';
import { authStore } from '../stores/authStore';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

const client = axios.create({
  baseURL: `${API_BASE_URL}/v1`,
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor: attach JWT token
client.interceptors.request.use(
  (config) => {
    const token = authStore.getToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor: unwrap server response wrapper and handle 401
client.interceptors.response.use(
  (response) => {
    // Server wraps all responses as { success: true, data: ... }
    // Unwrap automatically so API callers receive the inner data directly
    const body = response.data;
    if (body && typeof body === 'object' && 'success' in body && 'data' in body) {
      response.data = body.data;
    }
    return response;
  },
  (error) => {
    if (error.response?.status === 401) {
      authStore.clear();
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default client;
