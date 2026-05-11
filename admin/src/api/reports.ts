import client from './client';
import type { PaginatedResponse, ReportDetail, ReportListItem } from '../types';

export interface ReportsQuery {
  page?: number;
  limit?: number;
  status?: string;
  reason?: string;
}

export const reportsApi = {
  getReports(params: ReportsQuery): Promise<PaginatedResponse<ReportListItem>> {
    return client.get('/admin/reports', { params }).then((res) => res.data);
  },

  getReport(id: string): Promise<ReportDetail> {
    return client.get(`/admin/reports/${id}`).then((res) => res.data);
  },
};
