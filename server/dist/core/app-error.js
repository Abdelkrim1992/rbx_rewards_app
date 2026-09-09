export class AppError extends Error {
    isOperational = true;
    constructor(message) {
        super(message);
        Object.setPrototypeOf(this, new.target.prototype);
        Error.captureStackTrace(this, this.constructor);
    }
}
export class ValidationError extends AppError {
    statusCode = 400;
    constructor(message = 'Validation failed') {
        super(message);
    }
}
export class UnauthorizedError extends AppError {
    statusCode = 401;
    constructor(message = 'Unauthorized access') {
        super(message);
    }
}
export class ForbiddenError extends AppError {
    statusCode = 403;
    constructor(message = 'Forbidden resource') {
        super(message);
    }
}
export class NotFoundError extends AppError {
    statusCode = 404;
    constructor(message = 'Requested resource not found') {
        super(message);
    }
}
export class ConflictError extends AppError {
    statusCode = 409;
    constructor(message = 'Conflict state detected') {
        super(message);
    }
}
