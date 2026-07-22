from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "Phsar Kasikor App Backend"

    # Security
    SECRET_KEY: str = "e8a5b2e0430db8dfa2e6f43e595304b4d6676ba54580bfb9f8f415392e21b79f"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 11520  # 8 days

    # Database
    DATABASE_URL: str = "postgresql://postgres:postgres@db:5432/phsarkasikor"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        env_ignore_empty=True,
        extra="ignore"
    )


settings = Settings()
