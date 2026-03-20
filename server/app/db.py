import os
from sqlmodel import SQLModel, Session, create_engine


def get_database_url() -> str:
    url = os.getenv("DATABASE_URL")
    if not url:
        raise RuntimeError("DATABASE_URL environment variable not set")
    return url


_connect_args: dict = {"connect_timeout": 10}
# SEC-14: Exigir SSL em produção (Cloud Run, etc.)
if os.getenv("REQUIRE_SSL", "").lower() in ("1", "true", "yes"):
    _connect_args["sslmode"] = "require"

engine = create_engine(
    get_database_url(),
    echo=False,
    pool_size=20,
    max_overflow=40,
    pool_pre_ping=True,
    pool_recycle=1800,
    connect_args=_connect_args,
)


def init_db() -> None:
    SQLModel.metadata.create_all(engine)


def get_session():
    with Session(engine) as session:
        yield session
