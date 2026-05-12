import client from './client';
import type { PaginatedResponse } from '../types';

export interface InquiryListItem {
  id: string;
  subject: string;
  message: string;
  reply: string | null;
  status: 'OPEN' | 'REPLIED' | 'CLOSED' | string;
  createdAt: string;
  repliedAt: string | null;
  user: {
    id: string;
    nickname?: string | null;
    email?: string | null;
  };
}

export interface InquiriesQuery {
  page?: number;
  limit?: number;
  status?: string;
}

export const inquiriesApi = {
  getInquiries(
    params: InquiriesQuery,
  ): Promise<PaginatedResponse<InquiryListItem>> {
    return client.get('/admin/inquiries', { params }).then((r) => r.data);
  },

  getInquiry(id: string): Promise<InquiryListItem> {
    return client.get(`/admin/inquiries/${id}`).then((r) => r.data);
  },

  replyInquiry(
    id: string,
    reply: string,
    status: 'REPLIED' | 'CLOSED' = 'REPLIED',
  ): Promise<{ success: boolean }> {
    return client
      .patch(`/admin/inquiries/${id}`, { reply, status })
      .then((r) => r.data);
  },
};
