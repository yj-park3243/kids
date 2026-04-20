import client from './client';
import type { DashboardStats } from '../types';

export const dashboardApi = {
  getDashboard(): Promise<DashboardStats> {
    return client.get('/admin/dashboard').then((res) => res.data);
  },
};
