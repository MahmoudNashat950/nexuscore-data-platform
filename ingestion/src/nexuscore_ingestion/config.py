import os

from dotenv import load_dotenv

load_dotenv()


class Settings:
    database_url: str = os.getenv(
        "DATABASE_URL",
        "postgresql://nexuscore:nexuscore_dev_password@localhost:5432/nexuscore",
    )


settings = Settings()