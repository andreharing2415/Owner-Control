import os
from sqlmodel import SQLModel, Session, create_engine


def get_database_url() -> str:
    return os.getenv("DATABASE_URL", "postgresql://obramaster:obramaster@localhost:5444/obramaster")


engine = create_engine(get_database_url(), echo=False)


def init_db() -> None:
    SQLModel.metadata.create_all(engine)


def get_session():
    with Session(engine) as session:
        yield session
