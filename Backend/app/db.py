from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import declarative_base
from app.config import settings
import sys
import asyncio

if sys.platform == 'win32':
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

# Convert bare postgres URL to psycopg async driver if no driver already specified
DATABASE_URL = settings.DATABASE_URL
_scheme = DATABASE_URL.split("://")[0]
if "+" not in _scheme:
    if _scheme == "postgresql":
        DATABASE_URL = "postgresql+psycopg://" + DATABASE_URL[len("postgresql://"):]
    elif _scheme == "postgres":
        DATABASE_URL = "postgresql+psycopg://" + DATABASE_URL[len("postgres://"):]

engine = create_async_engine(DATABASE_URL, echo=False)
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)

Base = declarative_base()

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
