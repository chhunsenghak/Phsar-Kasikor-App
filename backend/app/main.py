from fastapi import FastAPI, Request, HTTPException
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.encoders import jsonable_encoder
from sqlalchemy.exc import SQLAlchemyError
import logging
import traceback

from app.api.v1.api import api_router
from app.core import errors
from app.core.config import settings
from app.core.database import engine
from app.models.base import Base

class ColoredFormatter(logging.Formatter):
    """
    Custom logging formatter that adds ANSI escape sequences to colorize
    log messages based on the logging severity level.
    """
    GREY = "\x1b[38;20m"
    BLUE = "\x1b[34;20m"
    YELLOW = "\x1b[33;20m"
    RED = "\x1b[31;20m"
    BOLD_RED = "\x1b[31;1m"
    RESET = "\x1b[0m"

    format_str = "%(asctime)s [%(levelname)s] (%(filename)s:%(lineno)d in %(funcName)s): %(message)s"

    FORMATS = {
        logging.DEBUG: GREY + format_str + RESET,
        logging.INFO: BLUE + format_str + RESET,
        logging.WARNING: YELLOW + format_str + RESET,
        logging.ERROR: RED + format_str + RESET,
        logging.CRITICAL: BOLD_RED + format_str + RESET
    }

    def format(self, record):
        log_fmt = self.FORMATS.get(record.levelno, self.format_str)
        formatter = logging.Formatter(log_fmt, datefmt="%Y-%m-%d %H:%M:%S")
        return formatter.format(record)


# Setup clean, colorful, and detailed logging configuration
root_logger = logging.getLogger()
root_logger.setLevel(logging.INFO)

# Clear existing handlers
for handler in root_logger.handlers[:]:
    root_logger.removeHandler(handler)

console_handler = logging.StreamHandler()
console_handler.setFormatter(ColoredFormatter())
root_logger.addHandler(console_handler)

logger = logging.getLogger("app")

# Create database tables automatically if they don't exist
try:
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables initialized successfully.")
except Exception as e:
    logger.error("Failed to initialize database tables.", exc_info=e)

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def format_clean_traceback(exc: Exception) -> str:
    """
    Filter the exception traceback to only output stack frames from our 'app' directory,
    excluding any boilerplate/framework wrappers (e.g. starlette, anyio, uvicorn).
    """
    tb_list = traceback.extract_tb(exc.__traceback__)
    clean_frames = []
    for frame in tb_list:
        if "app" in frame.filename:
            clean_frames.append(
                f"  File \"{frame.filename}\", line {frame.lineno}, in {frame.name}\n"
                f"    {frame.line}"
            )
    clean_tb_str = "\n".join(clean_frames)
    return (
        f"App Traceback (Cleaned):\n"
        f"{clean_tb_str}\n"
        f"{type(exc).__name__}: {str(exc)}"
    )


# --- Exception Handlers for Clean Console Logs and Client Responses ---

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """
    Handle standard HTTPExceptions (e.g. auth failures, duplicate emails)
    and output them in our unified error response schema.
    """
    message = exc.detail
    if message == "Not authenticated":
        message = errors.NOT_AUTHENTICATED

    logger.warning(
        f"HTTP exception on {request.method} {request.url.path} "
        f"| Status: {exc.status_code} | Message: {message}"
    )
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error_code": exc.status_code,
            "message": message
        },
    )

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """
    Log request validation failures cleanly in the console and return
    a structured list of error dictionaries in the detail field.
    """
    serialized_errors = jsonable_encoder(exc.errors())
    logger.warning(
        f"Validation failed on {request.method} {request.url.path} "
        f"| Errors: {serialized_errors}"
    )
    return JSONResponse(
        status_code=422,
        content={
            "error_code": 422,
            "message": errors.VALIDATION_ERROR,
            "detail": serialized_errors
        },
    )

@app.exception_handler(SQLAlchemyError)
async def sqlalchemy_exception_handler(request: Request, exc: SQLAlchemyError):
    """
    Log database errors cleanly, keeping console logs informative while
    returning the stable DATABASE_ERROR constant as the message.
    """
    logger.error(
        f"Database operation failed on {request.method} {request.url.path} "
        f"| Details: {str(exc)}"
    )
    return JSONResponse(
        status_code=500,
        content={
            "error_code": 500,
            "message": errors.DATABASE_ERROR
        },
    )

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    Fallback handler for any unhandled runtime exceptions. It logs a clean,
    filtered traceback in the console and returns the stable INTERNAL_SERVER_ERROR constant.
    """
    clean_tb = format_clean_traceback(exc)
    logger.error(
        f"Unhandled error during request {request.method} {request.url.path} \n{clean_tb}"
    )
    return JSONResponse(
        status_code=500,
        content={
            "error_code": 500,
            "message": errors.INTERNAL_SERVER_ERROR
        },
    )

# Include versioned API routers
app.include_router(api_router, prefix=settings.API_V1_STR)