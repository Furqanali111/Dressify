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

engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    # Raise pool_size above the default of 5 so concurrent requests under
    # moderate load don't queue waiting for a connection.
    pool_size=20,
    max_overflow=10,
    pool_timeout=30,
    # Verify a connection is still alive before handing it out (avoids
    # "server closed the connection unexpectedly" on Supabase idle timeouts).
    pool_pre_ping=True,
    # Recycle connections older than 10 min so Supabase's 5-min idle timeout
    # never cuts a connection that SQLAlchemy still considers live.
    pool_recycle=600,
)
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)

Base = declarative_base()

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
