export interface SuccessResponse<T> {
  success: true;
  data: T;
  message: string;
}

export interface ErrorDetail {
  field?: string;
  message: string;
}

export interface ErrorResponse {
  success: false;
  error: {
    code: string;
    message: string;
    details?: ErrorDetail[];
  };
}
