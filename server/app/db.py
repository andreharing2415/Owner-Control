import os
from sqlmodel import SQLModel, Session, create_engine


def get_database_url() -> str:
    return os.getenv("DATABASE_URL", "postgresql://obramaster:obramaster@localhost:5444/obramaster")


engine = create_engine(
    get_database_url(),
    echo=False,
    pool_size=5,
    max_overflow=10,
    pool_pre_ping=True,
    pool_recycle=1800,
    connect_args={"connect_timeout": 10},
)


def init_db() -> None:
    SQLModel.metadata.create_all(engine)


def get_session():
    with Session(engine) as session:
        yield session
