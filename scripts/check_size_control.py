import asyncio
from sqlalchemy import select, or_, and_
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

# Load env
load_dotenv()
DB_DSN = os.getenv("DB_DSN")

# Model (minimal)
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String

Base = declarative_base()

class SizeControl(Base):
    __tablename__ = 'size_control'
    id = Column(Integer, primary_key=True)
    dim1 = Column(Integer)
    dim2 = Column(Integer)
    formula_1_1k = Column(String)
    formula_2_1k = Column(String)
    formula_1_2k = Column(String)
    formula_2_2k = Column(String)
    formula_1_3k = Column(String)
    formula_2_3k = Column(String)

async def check_data():
    engine = create_async_engine(DB_DSN)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with async_session() as session:
        stmt = select(SizeControl).where(
            or_(
                and_(SizeControl.dim1 == 1200, SizeControl.dim2 == 1200),
                and_(SizeControl.dim1 == 1200, SizeControl.dim2 == 1200) # Simplified
            )
        )
        result = await session.execute(stmt)
        rules = result.scalars().all()
        for rule in rules:
            print(f"Rule ID: {rule.id}, {rule.dim1}x{rule.dim2}")
            print(f"  1k: {rule.formula_1_1k}, {rule.formula_2_1k}")
            print(f"  2k: {rule.formula_1_2k}, {rule.formula_2_2k}")
            print(f"  3k: {rule.formula_1_3k}, {rule.formula_2_3k}")

if __name__ == "__main__":
    asyncio.run(check_data())
