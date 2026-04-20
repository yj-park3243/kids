import client from './client';
import type { PaginatedResponse, RoomListItem, Room } from '../types';

export interface RoomsQuery {
  page?: number;
  limit?: number;
  search?: string;
  status?: string;
}

export const roomsApi = {
  getRooms(params: RoomsQuery): Promise<PaginatedResponse<RoomListItem>> {
    return client.get('/admin/rooms', { params }).then((res) => res.data);
  },

  getRoom(id: string): Promise<Room> {
    return client.get(`/admin/rooms/${id}`).then((res) => res.data);
  },

  deleteRoom(id: string): Promise<{ success: boolean }> {
    return client.delete(`/admin/rooms/${id}`).then((res) => res.data);
  },
};
