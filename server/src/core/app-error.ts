export abstract class AppError extends Error {
  public abstract readonly statusCode: number;
  public readonly isOperational: boolean = true;

  constructor(message: string) {
    super(message);
    Object.setPrototypeOf(this, new.target.prototype);
    Error.captureStackTrace(this, this.constructor);
  }
}

export class ValidationError extends AppError {
  public override readonly statusCode = 400;
  constructor(message: string = 'Validation failed') {
    super(message);
  }
}

export class UnauthorizedError extends AppError {
  public override readonly statusCode = 401;
  constructor(message: string = 'Unauthorized access') {
    super(message);
  }
}

export class ForbiddenError extends AppError {
  public override readonly statusCode = 403;
  constructor(message: string = 'Forbidden resource') {
    super(message);
  }
}

export class NotFoundError extends AppError {
  public override readonly statusCode = 404;
  constructor(message: string = 'Requested resource not found') {
    super(message);
  }
}

export class ConflictError extends AppError {
  public override readonly statusCode = 409;
  constructor(message: string = 'Conflict state detected') {
    super(message);
  }
}
