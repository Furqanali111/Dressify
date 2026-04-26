import sys
sys.path.insert(0, '.')
import asyncio
import sys as _sys
if _sys.platform == 'win32':
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
from sqlalchemy.ext.asyncio import create_async_engine
from app.config import settings
from sqlalchemy import text

DATABASE_URL = settings.DATABASE_URL.replace("postgres://", "postgresql+psycopg://", 1).replace("postgresql://", "postgresql+psycopg://", 1)
engine = create_async_engine(DATABASE_URL)

async def test():
    async with engine.connect() as conn:
        res = await conn.execute(text("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';"))
        tables = [row[0] for row in res.fetchall()]
        print("TABLES IN DB:", tables)

asyncio.run(test())
