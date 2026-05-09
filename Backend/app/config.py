from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List


class Settings(BaseSettings):
    # Supabase Settings
    SUPABASE_URL: str
    SUPABASE_KEY: str
    SUPABASE_SERVICE_KEY: str
    DATABASE_URL: str

    # Auth Settings
    GOOGLE_CLIENT_ID: str
    JWT_SECRET: str
    JWT_ISSUER: str = "dressify-api"
    JWT_TTL_HOURS: int = 24

    @field_validator("JWT_TTL_HOURS")
    @classmethod
    def jwt_ttl_must_be_positive(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("JWT_TTL_HOURS must be a positive integer")
        return v

    # Storage Settings
    CLOTHING_BUCKET: str = "clothing-processed"
    BYPASS_AUTH_FURQAN_54321: bool = False
    BYPASS_AUTH_TOKEN: str = "BYPASS_AUTH_FURQAN_54321"
    ENVIRONMENT: str = "development"  # "production" disables bypass auth

    # Upload retry worker
    RETRY_INTERVAL_SECONDS: int = 300   # how often the worker polls (default 5 min)
    UPLOAD_MAX_RETRIES: int = 3         # permanent failure after this many attempts

    # Virtual Try-On API keys (T3 AI Try-On feature)
    FASHN_API_KEY: str = ""
    REPLICATE_API_KEY: str = ""
    
    # 3D Mesh Reconstruction Settings
    MESH_PROVIDER: str = "local" # options: "local", "replicate", "runpod"
    LOCAL_GPU_WORKER_URL: str = "http://localhost:8080/generate"
    RUNPOD_MESH_ENDPOINT: str = ""

    # AI Settings
    OPENAI_API_KEY: str | None = None
    OPENAI_API_MODEL: str = "gpt-4o-mini"
    OLLAMA_BASE_URL: str = "http://localhost:11434/v1"
    OLLAMA_VISION_MODEL: str = "llama3.2-vision:11b"
    OLLAMA_TEXT_MODEL: str = "llama3.2:latest"

    # Redis (rate-limit backend)
    REDIS_URL: str = "redis://localhost:6379"

    # App Settings
    ALLOWED_ORIGINS: str = "http://localhost:3000"
    LOG_LEVEL: str = "info"

    @property
    def bypass_auth_enabled(self) -> bool:
        return self.BYPASS_AUTH_FURQAN_54321 and self.ENVIRONMENT != "production"

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
