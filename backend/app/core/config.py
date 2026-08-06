from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "Phsar Kasikor App Backend"

    # Security
    SECRET_KEY: str = "e8a5b2e0430db8dfa2e6f43e595304b4d6676ba54580bfb9f8f415392e21b79f"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 11520  # 8 days

    # Database
    DATABASE_URL: str = "postgresql://postgres:postgres@db:5432/phsarkasikor"

    # Push notifications (Firebase Cloud Messaging) — empty disables sending;
    # notifications still save to the DB either way.
    FIREBASE_SERVICE_ACCOUNT_PATH: str = ""

    # Email (SMTP) — password reset + verification codes
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USERNAME: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM_EMAIL: str = ""
    SMTP_USE_TLS: bool = True

    # Bakong KHQR payment gateway. QR *generation* needs only the merchant
    # fields below and works fully offline. BAKONG_BEARER_TOKEN is only used
    # to check whether a generated QR has actually been paid — it's short-
    # lived and optional; leave it empty to skip automatic verification.
    BAKONG_API_BASE_URL: str = "https://api-bakong.nbc.gov.kh"
    BAKONG_BEARER_TOKEN: str = ""
    BAKONG_MERCHANT_ACCOUNT_ID: str = ""
    BAKONG_MERCHANT_NAME: str = ""
    BAKONG_MERCHANT_CITY: str = ""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        env_ignore_empty=True,
        extra="ignore"
    )


settings = Settings()
