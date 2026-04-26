from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List


class Settings(BaseSettings):
    # Supabase Settings
    SUPABASE_URL: str
    SUPABASE_KEY: str
    DATABASE_URL: str

    # Auth Settings
    GOOGLE_CLIENT_ID: str
    JWT_SECRET: str
    JWT_ISSUER: str = "dressify-api"
    JWT_TTL_HOURS: int = 24

    # AI Settings
    OPENAI_API_KEY: str | None = None
    OLLAMA_BASE_URL: str = "http://localhost:11434/v1"

    # App Settings
    ALLOWED_ORIGINS: str = "http://localhost:3000"
    LOG_LEVEL: str = "info"

    @property
    def cors_origins(self) -> List[str]:
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",")]

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )


settings = Settings()
