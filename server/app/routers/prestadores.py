"""Prestadores router — subcategorias, CRUD, avaliacoes."""

from datetime import datetime, timezone
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from ..db import get_session
from ..models import User, Prestador, Avaliacao
from ..schemas import (
    PrestadorCreate, PrestadorRead, PrestadorUpdate,
    AvaliacaoCreate, AvaliacaoRead, PrestadorDetalheRead,
)
from ..enums import CategoriaPrestador, SubcategoriaPrestadorServico, SubcategoriaMateriais
from ..auth import get_current_user
from ..subscription import get_plan_config

router = APIRouter(prefix="/api/prestadores", tags=["prestadores"])

SUBCATEGORIAS_MAP: dict[str, list[str]] = {
    CategoriaPrestador.PRESTADOR_SERVICO.value: [e.value for e in SubcategoriaPrestadorServico],
    CategoriaPrestador.MATERIAIS.value: [e.value for e in SubcategoriaMateriais],
}

NOTAS_SERVICO = ["nota_qualidade_servico", "nota_cumprimento_prazos", "nota_fidelidade_projeto"]
NOTAS_MATERIAL = ["nota_prazo_entrega", "nota_qualidade_material"]


@router.get("/subcategorias")
def listar_subcategorias() -> dict:
    """Retorna as subcategorias válidas por categoria."""
    return SUBCATEGORIAS_MAP


@router.post("", response_model=PrestadorRead)
def criar_prestador(
    payload: PrestadorCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> dict:
    """Cadastra um novo prestador de serviço ou fornecedor de materiais."""
    if payload.categoria not in SUBCATEGORIAS_MAP:
        raise HTTPException(status_code=422, detail="Categoria invalida")
    if payload.subcategoria not in SUBCATEGORIAS_MAP[payload.categoria]:
        raise HTTPException(status_code=422, detail="Subcategoria invalida para esta categoria")

    prestador = Prestador(**payload.model_dump())
    session.add(prestador)
    session.commit()
    session.refresh(prestador)
    return PrestadorRead(
        **prestador.model_dump(),
        nota_geral=None,
        total_avaliacoes=0,
    )


@router.get("", response_model=List[PrestadorRead])
def listar_prestadores(
    categoria: str | None = None,
    subcategoria: str | None = None,
    regiao: str | None = None,
    q: str | None = None,
    limit: int = 50,
    offset: int = 0,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[dict]:
    """Lista prestadores com filtros opcionais e nota média."""
    query = select(Prestador)
    if categoria:
        query = query.where(Prestador.categoria == categoria)
    if subcategoria:
        query = query.where(Prestador.subcategoria == subcategoria)
    if regiao:
        query = query.where(Prestador.regiao.ilike(f"%{regiao}%"))
    if q:
        query = query.where(Prestador.nome.ilike(f"%{q}%"))

    query = query.order_by(Prestador.nome).offset(offset).limit(min(limit, 100))
    prestadores = session.exec(query).all()

    if not prestadores:
        return []

    prestador_ids = [p.id for p in prestadores]
    avaliacoes = session.exec(
        select(Avaliacao).where(Avaliacao.prestador_id.in_(prestador_ids))
    ).all()

    avaliacoes_por_prestador: dict = {}
    for av in avaliacoes:
        avaliacoes_por_prestador.setdefault(av.prestador_id, []).append(av)

    resultado: list[PrestadorRead] = []
    for p in prestadores:
        avs = avaliacoes_por_prestador.get(p.id, [])
        total = len(avs)
        nota_geral = None
        if total > 0:
            if p.categoria == CategoriaPrestador.PRESTADOR_SERVICO.value:
                campos = NOTAS_SERVICO
            else:
                campos = NOTAS_MATERIAL
            todas_notas = []
            for av in avs:
                for campo in campos:
                    val = getattr(av, campo)
                    if val is not None:
                        todas_notas.append(val)
            if todas_notas:
                nota_geral = round(sum(todas_notas) / len(todas_notas), 1)

        resultado.append(PrestadorRead(
            **p.model_dump(),
            nota_geral=nota_geral,
            total_avaliacoes=total,
        ))

    resultado.sort(key=lambda r: (r.nota_geral is None, -(r.nota_geral or 0)))

    config = get_plan_config(current_user)
    if config["prestadores_limit"] is not None:
        resultado = resultado[:config["prestadores_limit"]]
    if not config["prestadores_show_contact"]:
        for r in resultado:
            r.telefone = None
            r.email = None
    return resultado


@router.get("/{prestador_id}", response_model=PrestadorDetalheRead)
def obter_prestador(
    prestador_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> PrestadorDetalheRead:
    """Retorna um prestador com todas as avaliações e médias por tópico."""
    prestador = session.get(Prestador, prestador_id)
    if not prestador:
        raise HTTPException(status_code=404, detail="Prestador nao encontrado")

    avaliacoes = session.exec(
        select(Avaliacao)
        .where(Avaliacao.prestador_id == prestador_id)
        .order_by(Avaliacao.created_at.desc())
    ).all()

    if prestador.categoria == CategoriaPrestador.PRESTADOR_SERVICO.value:
        campos = NOTAS_SERVICO
    else:
        campos = NOTAS_MATERIAL

    medias: dict[str, float] = {}
    for campo in campos:
        notas = [getattr(av, campo) for av in avaliacoes if getattr(av, campo) is not None]
        if notas:
            medias[campo] = round(sum(notas) / len(notas), 1)

    total = len(avaliacoes)
    todas_notas_flat = []
    for av in avaliacoes:
        for campo in campos:
            val = getattr(av, campo)
            if val is not None:
                todas_notas_flat.append(val)
    nota_geral = round(sum(todas_notas_flat) / len(todas_notas_flat), 1) if todas_notas_flat else None

    return PrestadorDetalheRead(
        prestador=PrestadorRead(
            **prestador.model_dump(),
            nota_geral=nota_geral,
            total_avaliacoes=total,
        ),
        avaliacoes=[AvaliacaoRead.model_validate(av) for av in avaliacoes],
        medias=medias,
    )


@router.patch("/{prestador_id}", response_model=PrestadorRead)
def atualizar_prestador(
    prestador_id: UUID,
    payload: PrestadorUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> dict:
    """Atualiza dados de um prestador."""
    prestador = session.get(Prestador, prestador_id)
    if not prestador:
        raise HTTPException(status_code=404, detail="Prestador nao encontrado")
    updates = payload.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(prestador, key, value)
    prestador.updated_at = datetime.now(timezone.utc)
    session.add(prestador)
    session.commit()
    session.refresh(prestador)

    avaliacoes = session.exec(
        select(Avaliacao).where(Avaliacao.prestador_id == prestador_id)
    ).all()
    total = len(avaliacoes)
    campos = NOTAS_SERVICO if prestador.categoria == CategoriaPrestador.PRESTADOR_SERVICO.value else NOTAS_MATERIAL
    todas_notas = []
    for av in avaliacoes:
        for campo in campos:
            val = getattr(av, campo)
            if val is not None:
                todas_notas.append(val)
    nota_geral = round(sum(todas_notas) / len(todas_notas), 1) if todas_notas else None

    return PrestadorRead(
        **prestador.model_dump(),
        nota_geral=nota_geral,
        total_avaliacoes=total,
    )


@router.post("/{prestador_id}/avaliacoes", response_model=AvaliacaoRead)
def criar_avaliacao(
    prestador_id: UUID,
    payload: AvaliacaoCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> Avaliacao:
    """Cria uma avaliação para um prestador, validando os tópicos pela categoria."""
    prestador = session.get(Prestador, prestador_id)
    if not prestador:
        raise HTTPException(status_code=404, detail="Prestador nao encontrado")

    if prestador.categoria == CategoriaPrestador.PRESTADOR_SERVICO.value:
        campos_validos = NOTAS_SERVICO
        campos_invalidos = NOTAS_MATERIAL
    else:
        campos_validos = NOTAS_MATERIAL
        campos_invalidos = NOTAS_SERVICO

    for campo in campos_invalidos:
        if getattr(payload, campo) is not None:
            raise HTTPException(
                status_code=422,
                detail=f"Campo '{campo}' nao se aplica a categoria '{prestador.categoria}'",
            )

    notas_preenchidas = [getattr(payload, c) for c in campos_validos if getattr(payload, c) is not None]
    if not notas_preenchidas:
        raise HTTPException(status_code=422, detail="Informe ao menos uma nota")

    avaliacao = Avaliacao(prestador_id=prestador_id, **payload.model_dump())
    session.add(avaliacao)
    session.commit()
    session.refresh(avaliacao)
    return avaliacao


@router.get("/{prestador_id}/avaliacoes", response_model=List[AvaliacaoRead])
def listar_avaliacoes(
    prestador_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[Avaliacao]:
    """Lista todas as avaliações de um prestador."""
    prestador = session.get(Prestador, prestador_id)
    if not prestador:
        raise HTTPException(status_code=404, detail="Prestador nao encontrado")
    return session.exec(
        select(Avaliacao)
        .where(Avaliacao.prestador_id == prestador_id)
        .order_by(Avaliacao.created_at.desc())
    ).all()
