from functools import lru_cache

from pydantic import SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "Projeto Automotivo API"
    app_env: str = "development"
    app_debug: bool = False
    api_v1_prefix: str = "/api/v1"
    database_url: str = (
        "postgresql+psycopg://postgres:postgres@localhost:5432/projeto_automotivo"
    )
    allowed_origins: str = ""
    jwt_secret: SecretStr = SecretStr("development-only-change-this-secret")
    access_token_minutes: int = 15
    refresh_token_days: int = 30

    @property
    def allowed_origins_list(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.allowed_origins.split(",")
            if origin.strip()
        ]

    @model_validator(mode="after")
    def validate_production_secret(self) -> "Settings":
        if (
            self.app_env.lower() == "production"
            and self.jwt_secret.get_secret_value()
            == "development-only-change-this-secret"
        ):
            raise ValueError("JWT_SECRET deve ser configurado em producao.")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
