from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.core.config import settings
from app.main import create_app
from app.models import (  # noqa: F401
    Carro,
    ComentarioEvolucao,
    ConversaDireta,
    ConviteEquipe,
    CurtidaComentarioEvolucao,
    CurtidaEvolucao,
    CarroEquipe,
    Equipe,
    Evento,
    EvolucaoProjeto,
    MidiaEvolucao,
    MensagemDireta,
    MembroEquipe,
    MensagemEquipe,
    LeituraChatEquipe,
    Notificacao,
    ParticipacaoEquipeEvento,
    PresencaEvento,
    Seguidor,
    SessaoRefresh,
    SolicitacaoEquipe,
    Usuario,
)


@pytest.fixture
def client(tmp_path, monkeypatch) -> Generator[TestClient, None, None]:
    monkeypatch.setattr(settings, "media_root", tmp_path / "media")
    app = create_app()
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    testing_session = sessionmaker(
        bind=engine,
        autoflush=False,
        expire_on_commit=False,
    )
    Base.metadata.create_all(engine)

    def override_get_db() -> Generator[Session, None, None]:
        db = testing_session()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()
    Base.metadata.drop_all(engine)
