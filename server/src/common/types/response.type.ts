export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
  };
}

export interface PaginatedResponse<T = any> {
  items: T[];
  nextCursor: string | null;
  hasMore: boolean;
}
