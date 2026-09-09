import { AppError } from './app-error.js';
export function errorHandler(err, _req, res, _next) {
    if (err instanceof AppError) {
        res.status(err.statusCode).json({
            success: false,
            error: {
                message: err.message,
                statusCode: err.statusCode,
            },
        });
        return;
    }
    const message = err instanceof Error ? err.message : 'Internal Server Error';
    res.status(500).json({
        success: false,
        error: {
            message: process.env['NODE_ENV'] === 'production' ? 'Internal server error occurred' : message,
            statusCode: 500,
        },
    });
}
