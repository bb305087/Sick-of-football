from functools import lru_cache
from typing import Literal
from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    env: Literal["dev", "test", "prod"] = "prod"
    database_url: SecretStr = Field(validation_alias="DATABASE_URL")
    jwt_secret: SecretStr = Field(validation_alias="SICK_OF_FOOTBALL_JWT_SECRET")
    jwt_issuer: str = "sick-of-football"
    jwt_audience: str = "sick-of-football-mobile"
    data_encryption_keys: SecretStr = Field(validation_alias="SICK_OF_FOOTBALL_DATA_ENCRYPTION_KEYS")
    active_encryption_key_id: int = 1
    allowed_origins: list[str] = ["http://localhost"]
    access_token_ttl_min: int = Field(15, ge=1, le=60)
    refresh_token_ttl_days: int = Field(14, ge=1, le=30)

    @model_validator(mode="after")
    def validate_secrets(self) -> "Settings":
        if len(self.jwt_secret.get_secret_value()) < 32:
            raise ValueError("JWT secret must contain at least 32 characters")
        import base64, json
        keys = json.loads(self.data_encryption_keys.get_secret_value())
        if str(self.active_encryption_key_id) not in keys:
            raise ValueError("active encryption key is missing")
        if any(len(base64.b64decode(value)) != 32 for value in keys.values()):
            raise ValueError("encryption keys must be 32 bytes")
        return self

@lru_cache
def get_settings() -> Settings:
    return Settings()
