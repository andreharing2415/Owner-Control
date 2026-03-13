"""Documentos router — projetos CRUD, analisar, riscos, aplicar-riscos, detalhamento."""

import asyncio
import base64
import json
import logging
import os
from datetime import datetime, timezone
from io import BytesIO
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import Response
from sqlmodel import Session, select

from ..db import get_session
from ..models import (
    User, Obra, Etapa, ChecklistItem, ProjetoDoc, Risco, ObraDetalhamento,
)
from ..schemas import (
    ProjetoDocRead, RiscoRead, AplicarRiscosRequest,
)
from ..enums import ChecklistStatus
from ..auth import get_current_user
from ..subscription import get_plan_config, require_paid
from ..storage import upload_file, download_by_url, extract_object_key
from ..documentos import analisar_documento
from ..helpers import (
    _sanitize_filename, _verify_obra_ownership, _verify_obra_access,
    _RISCO_ETAPA_KEYWORDS,
)
from fastapi import UploadFile, File

logger = logging.getLogger(__name__)

router = APIRouter(tags=["documentos"])


@router.post("/api/obras/{obra_id}/projetos", response_model=ProjetoDocRead)
def upload_projeto(
    obra_id: UUID,
    file: UploadFile = File(...),
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ProjetoDoc:
    """Faz upload de um PDF de projeto e cria o registro para análise."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    config = get_plan_config(current_user)
    # Gate: limite de uploads
    if config["max_doc_uploads"] is not None:
        doc_count = len(session.exec(
            select(ProjetoDoc).where(ProjetoDoc.obra_id == obra_id)
        ).all())
        if doc_count >= config["max_doc_uploads"]:
            raise HTTPException(status_code=403, detail="Limite de documentos atingido para seu plano")
    # Gate: limite de tamanho
    if config["max_doc_size_mb"] is not None:
        file.file.seek(0, os.SEEK_END)
        size_mb = file.file.tell() / (1024 * 1024)
        file.file.seek(0)
        if size_mb > config["max_doc_size_mb"]:
            raise HTTPException(
                status_code=403,
                detail=f"Arquivo excede o limite de {config['max_doc_size_mb']}MB para seu plano",
            )
    if not file.filename:
        raise HTTPException(status_code=400, detail="Nome do arquivo ausente")
    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")
    object_key = f"projetos/{obra_id}/{_sanitize_filename(file.filename)}"
    file.file.seek(0)
    file_url = upload_file(bucket, object_key, file.file, file.content_type)
    projeto = ProjetoDoc(
        obra_id=obra_id,
        arquivo_url=file_url,
        arquivo_nome=file.filename,
        status="pendente",
    )
    session.add(projeto)
    session.commit()
    session.refresh(projeto)
    return projeto


@router.get("/api/obras/{obra_id}/projetos", response_model=List[ProjetoDocRead])
def listar_projetos(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[ProjetoDoc]:
    """Lista todos os projetos PDF enviados para a obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    return session.exec(
        select(ProjetoDoc)
        .where(ProjetoDoc.obra_id == obra_id)
        .order_by(ProjetoDoc.created_at.desc())
    ).all()


@router.get("/api/projetos/{projeto_id}", response_model=ProjetoDocRead)
def obter_projeto(
    projeto_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ProjetoDoc:
    """Retorna os detalhes de um projeto PDF."""
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    obra = session.get(Obra, projeto.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    return projeto


@router.get("/api/projetos/{projeto_id}/pdf")
def download_projeto_pdf(
    projeto_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Serve o PDF do projeto via proxy (resolve CORS com storage)."""
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    obra = session.get(Obra, projeto.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")
    object_key = extract_object_key(projeto.arquivo_url, bucket)
    pdf_bytes = download_by_url(projeto.arquivo_url, bucket, object_key)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'inline; filename="{projeto.arquivo_nome}"'},
    )


@router.delete("/api/projetos/{projeto_id}")
def deletar_projeto(
    projeto_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Remove um projeto PDF e seus riscos associados."""
    if not get_plan_config(current_user).get("can_delete_doc"):
        raise HTTPException(status_code=403, detail="Exclusão de documentos disponível apenas para assinantes")
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    try:
        riscos = session.exec(select(Risco).where(Risco.projeto_id == projeto_id)).all()
        for r in riscos:
            session.delete(r)
        session.flush()
        session.delete(projeto)
        session.commit()
    except Exception as exc:
        session.rollback()
        logger.error("Erro ao deletar projeto %s do banco: %s", projeto_id, exc)
        raise HTTPException(status_code=500, detail=f"Erro ao remover projeto do banco: {exc}")

    bucket = os.getenv("S3_BUCKET")
    if bucket and projeto.arquivo_url:
        try:
            object_key = extract_object_key(projeto.arquivo_url, bucket)
            from ..storage import _use_gcs
            if _use_gcs():
                from ..storage import _get_gcs_client
                client = _get_gcs_client()
                bl = client.bucket(bucket).blob(object_key)
                bl.delete()
            else:
                from ..storage import _get_s3_client
                _get_s3_client().delete_object(Bucket=bucket, Key=object_key)
        except Exception as exc:
            logger.warning("Falha ao remover arquivo do storage para projeto %s: %s", projeto_id, exc)

    return {"ok": True}


@router.post("/api/projetos/{projeto_id}/analisar", response_model=ProjetoDocRead)
async def analisar_projeto(
    projeto_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ProjetoDoc:
    """
    Dispara a análise de IA sobre o PDF do projeto.
    Baixa o PDF do S3, envia ao Claude e persiste os riscos encontrados.
    """
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    if projeto.status == "processando":
        raise HTTPException(status_code=409, detail="Analise ja em andamento")

    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")

    projeto.status = "processando"
    projeto.updated_at = datetime.now(timezone.utc)
    session.add(projeto)
    session.commit()

    try:
        object_key = extract_object_key(projeto.arquivo_url, bucket)

        pdf_bytes = await asyncio.to_thread(download_by_url, projeto.arquivo_url, bucket, object_key)
        resultado = await asyncio.to_thread(analisar_documento, pdf_bytes, projeto.arquivo_nome)

        # Remove riscos anteriores se houver re-análise
        riscos_antigos = session.exec(
            select(Risco).where(Risco.projeto_id == projeto_id)
        ).all()
        for r in riscos_antigos:
            session.delete(r)

        # Persiste os novos riscos (formato "Anjo da Guarda")
        for risco_data in resultado.get("riscos_e_alertas", []):
            dado_projeto = risco_data.get("dado_projeto")
            verificacao = risco_data.get("verificacao_na_obra")
            mensagem_prof = risco_data.get("mensagem_para_o_profissional")
            documentos = risco_data.get("documento_para_exigir")
            severidade_raw = (risco_data.get("severidade") or "BAIXA").upper()
            risco = Risco(
                projeto_id=projeto_id,
                descricao=risco_data.get("descricao_tecnica", ""),
                severidade=severidade_raw,
                disciplina=risco_data.get("disciplina"),
                norma_referencia=risco_data.get("norma_referencia"),
                traducao_leigo=risco_data.get("traducao_para_leigo", ""),
                acao_proprietario=risco_data.get("acao_imediata", ""),
                documentos_a_exigir=json.dumps(documentos, ensure_ascii=False) if documentos else None,
                requer_validacao_profissional=severidade_raw == "ALTA",
                confianca=80,
                dado_projeto=json.dumps(dado_projeto, ensure_ascii=False) if dado_projeto else None,
                verificacoes=json.dumps(verificacao, ensure_ascii=False) if verificacao else None,
                pergunta_engenheiro=json.dumps(mensagem_prof, ensure_ascii=False) if mensagem_prof else None,
            )
            session.add(risco)

        projeto.resumo_geral = resultado.get("resumo_executivo")
        projeto.aviso_legal = resultado.get(
            "aviso_legal",
            "Esta análise é preventiva e educacional. Não substitui o acompanhamento técnico de um profissional com CREA/CAU.",
        )
        projeto.status = "concluido"
        projeto.updated_at = datetime.now(timezone.utc)
        session.add(projeto)
        session.commit()
        session.refresh(projeto)
        return projeto

    except Exception as exc:
        projeto.status = "erro"
        projeto.updated_at = datetime.now(timezone.utc)
        session.add(projeto)
        session.commit()
        raise HTTPException(status_code=502, detail=f"Erro na analise: {exc}")


@router.get("/api/obras/{obra_id}/riscos-pendentes")
def listar_riscos_pendentes(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Retorna riscos de documentos analisados que ainda nao viraram checklist items."""
    docs = session.exec(
        select(ProjetoDoc)
        .where(ProjetoDoc.obra_id == obra_id)
        .where(ProjetoDoc.status == "concluido")
    ).all()

    titulos_existentes: set[str] = set()
    etapas = session.exec(select(Etapa).where(Etapa.obra_id == obra_id)).all()
    etapa_ids = [e.id for e in etapas]
    if etapa_ids:
        items_existentes = session.exec(
            select(ChecklistItem.titulo).where(ChecklistItem.etapa_id.in_(etapa_ids))  # type: ignore[attr-defined]
        ).all()
        titulos_existentes = {t for t in items_existentes}

    riscos_pendentes = []
    for doc in docs:
        riscos = session.exec(
            select(Risco).where(Risco.projeto_id == doc.id)
        ).all()
        for risco in riscos:
            if risco.descricao in titulos_existentes:
                continue
            riscos_pendentes.append({
                "id": str(risco.id),
                "descricao": risco.descricao,
                "severidade": risco.severidade,
                "disciplina": risco.disciplina,
                "norma_referencia": risco.norma_referencia,
                "traducao_leigo": risco.traducao_leigo,
                "documento_nome": doc.arquivo_nome,
            })

    return {"riscos": riscos_pendentes, "total": len(riscos_pendentes)}


@router.post("/api/obras/{obra_id}/aplicar-riscos")
def aplicar_riscos(
    obra_id: UUID,
    body: AplicarRiscosRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Converte riscos selecionados em ChecklistItems nas etapas adequadas."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    risco_ids = body.risco_ids
    if not risco_ids:
        return {"criados": 0}

    etapas = session.exec(select(Etapa).where(Etapa.obra_id == obra_id)).all()
    if not etapas:
        raise HTTPException(status_code=400, detail="Obra sem etapas")

    etapa_map = {e.nome: e for e in etapas}
    etapa_fallback = etapa_map.get("Instalacoes e Acabamentos") or etapas[-1]

    obra_projeto_ids = set(
        p.id for p in session.exec(
            select(ProjetoDoc).where(ProjetoDoc.obra_id == obra_id)
        ).all()
    )

    criados = 0
    for rid in risco_ids:
        risco = session.get(Risco, UUID(rid))
        if not risco or risco.projeto_id not in obra_projeto_ids:
            continue

        etapa_alvo = etapa_fallback
        desc_lower = risco.descricao.lower()
        for keyword, etapa_nomes in _RISCO_ETAPA_KEYWORDS.items():
            if keyword in desc_lower:
                for nome in etapa_nomes:
                    if nome in etapa_map:
                        etapa_alvo = etapa_map[nome]
                        break
                break

        item = ChecklistItem(
            etapa_id=etapa_alvo.id,
            titulo=risco.descricao,
            descricao=risco.traducao_leigo,
            origem="ia",
            severidade=risco.severidade,
            traducao_leigo=risco.traducao_leigo,
            norma_referencia=risco.norma_referencia,
            dado_projeto=risco.dado_projeto,
            verificacoes=risco.verificacoes,
            pergunta_engenheiro=risco.pergunta_engenheiro,
            documentos_a_exigir=risco.documentos_a_exigir,
            confianca=risco.confianca,
            requer_validacao_profissional=risco.requer_validacao_profissional,
        )
        session.add(item)
        criados += 1

    session.commit()
    return {"criados": criados}


# ─── Detalhamento da Obra (cômodos + m²) ────────────────────────────────────


def _clean_ai_json(text: str) -> str:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        lines = cleaned.split("\n")
        cleaned = "\n".join(lines[1:-1]) if lines[-1].strip() == "```" else "\n".join(lines[1:])
    return cleaned


def _detalhamento_result_ok(result: dict) -> bool:
    """Check if AI returned useful data (at least 1 comodo with area)."""
    comodos = result.get("comodos", [])
    if not comodos:
        return False
    return any(
        (c.get("area_liquida_m2") is not None or c.get("area_m2") is not None)
        for c in comodos
    )


def _extrair_detalhamento_vision_single(page: tuple[str, int], prompt: str) -> dict | None:
    """Send a single page to vision AI. Returns parsed dict or None."""
    img_b64, page_num = page
    page_prompt = f"[Pagina {page_num}]\n\n{prompt}"

    # --- Gemini (primary) ---
    gemini_key = os.getenv("GEMINI_API_KEY")
    if gemini_key:
        try:
            import google.generativeai as genai
            from google.generativeai.types import content_types
            genai.configure(api_key=gemini_key)
            model = genai.GenerativeModel("gemini-2.5-flash")
            img_bytes = base64.b64decode(img_b64)
            parts = [
                content_types.to_part({"mime_type": "image/jpeg", "data": img_bytes}),
                page_prompt,
            ]
            response = model.generate_content(parts)
            if response.text:
                return json.loads(_clean_ai_json(response.text))
        except Exception as exc:
            logger.warning("Detalhamento vision pagina %d falhou via Gemini: %s", page_num, exc)

    # --- Claude (fallback) ---
    anthropic_key = os.getenv("ANTHROPIC_API_KEY")
    if anthropic_key:
        try:
            import anthropic as anth
            client = anth.Anthropic(api_key=anthropic_key)
            content_blocks = [
                {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": img_b64}},
                {"type": "text", "text": page_prompt},
            ]
            response = client.messages.create(model="claude-sonnet-4-6", max_tokens=4096, messages=[{"role": "user", "content": content_blocks}])
            text = response.content[0].text if response.content else ""
            if text:
                return json.loads(_clean_ai_json(text))
        except Exception as exc:
            logger.warning("Detalhamento vision pagina %d falhou via Claude: %s", page_num, exc)

    # --- OpenAI (fallback) ---
    openai_key = os.getenv("OPENAI_API_KEY")
    if openai_key:
        try:
            from openai import OpenAI as OAI
            client = OAI(api_key=openai_key)
            content_parts = [
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_b64}"}},
                {"type": "text", "text": page_prompt},
            ]
            response = client.chat.completions.create(model="gpt-4o", messages=[{"role": "user", "content": content_parts}], max_tokens=4096)
            text = response.choices[0].message.content or ""
            if text:
                return json.loads(_clean_ai_json(text))
        except Exception as exc:
            logger.warning("Detalhamento vision pagina %d falhou via OpenAI: %s", page_num, exc)

    return None


@router.get("/api/obras/{obra_id}/detalhamento")
def get_detalhamento(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Retorna o detalhamento da obra (cômodos e metragens extraídas)."""
    _verify_obra_access(obra_id, current_user, session)
    det = session.exec(
        select(ObraDetalhamento)
        .where(ObraDetalhamento.obra_id == obra_id)
        .order_by(ObraDetalhamento.updated_at.desc())
    ).first()
    if not det:
        return {"comodos": [], "area_total_m2": None, "fonte_doc_nome": None, "totais_estimados": None}
    comodos = json.loads(det.comodos) if det.comodos else []
    # Compute totals from stored comodos
    total_pisos = sum(c.get("estimativa_piso_com_sobra_m2") or 0 for c in comodos)
    total_azulejos = sum(c.get("estimativa_azulejo_parede_com_sobra_m2") or 0 for c in comodos)
    return {
        "id": str(det.id),
        "comodos": comodos,
        "area_total_m2": det.area_total_m2,
        "fonte_doc_id": str(det.fonte_doc_id) if det.fonte_doc_id else None,
        "fonte_doc_nome": det.fonte_doc_nome,
        "totais_estimados": {
            "total_pisos_m2": round(total_pisos, 2) if total_pisos else 0,
            "total_azulejos_m2": round(total_azulejos, 2) if total_azulejos else 0,
        },
    }


@router.post("/api/obras/{obra_id}/extrair-detalhamento")
def extrair_detalhamento(
    obra_id: UUID,
    pe_direito: float = 2.70,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_paid),
):
    """Extrai cômodos, metragens e quantitativos dos documentos da obra usando IA vision — página a página com early exit."""
    obra = _verify_obra_ownership(obra_id, current_user, session)

    docs = session.exec(
        select(ProjetoDoc).where(ProjetoDoc.obra_id == obra_id)
    ).all()
    if not docs:
        raise HTTPException(status_code=400, detail="Nenhum documento enviado.")

    from ..pdf_utils import extrair_paginas_como_imagens

    detalhamento_prompt = f"""Voce e um Engenheiro de Custos e Orcamentista senior, especialista em analise de projetos arquitetonicos, eletricos e hidraulicos.
Sua missao e analisar os documentos anexados e extrair um levantamento quantitativo detalhado e preciso, formatado para um proprietario de obra leigo.

INFORMACOES DE CONTEXTO:
- Altura do pe-direito considerada para areas molhadas: {pe_direito:.2f} metros.
- Taxa de perda/sobra para pisos e revestimentos: Adicionar 15% sobre a area liquida para recortes e quebras.

REGRAS DE EXTRACAO:
1. Identifique todos os comodos legiveis na planta.
2. Extraia a area (m2) de cada comodo. Se a area nao estiver escrita, mas houver cotas, estime a area aproximada.
3. Para TODOS os comodos, calcule a estimativa de piso (Area + 15%).
4. Para AREAS MOLHADAS (banheiros, cozinhas, lavanderias, varandas gourmet), calcule a estimativa de revestimento de parede (Perimetro estimado * pe-direito + 15%). Desconte uma area padrao para portas e janelas.
5. Liste os itens de acabamento essenciais identificados na planta para cada ambiente (ex: 1 bacia sanitaria, 2 cubas, 1 chuveiro, bancada de x metros).
6. Se houver projeto eletrico/luminotecnico anexo, conte as tomadas, interruptores e pontos de luz por ambiente.

REGRAS NUMERICAS:
- Leia EXATAMENTE os nomes e metragens escritos na planta (ex: "SUITE MASTER 12,87 m2")
- NAO invente comodos ou areas que nao estejam claramente escritos
- Use o formato brasileiro de numeros (virgula como decimal) convertido para ponto (ex: 12,87 -> 12.87)
- Se esta pagina NAO contem planta baixa com comodos/metragens, retorne {{"comodos": [], "area_total_m2": null}}

FORMATO DE SAIDA (Obrigatorio JSON):
{{
  "resumo_projeto": "Breve descricao do que foi identificado nas pranchas.",
  "pe_direito_utilizado": "{pe_direito:.2f} metros",
  "comodos": [
    {{
      "nome": "Nome do ambiente",
      "area_liquida_m2": 0.0,
      "estimativa_piso_com_sobra_m2": 0.0,
      "area_molhada": true,
      "estimativa_azulejo_parede_com_sobra_m2": 0.0,
      "itens_hidraulicos_e_metais": ["1 bacia sanitaria", "2 torneiras de bancada"],
      "itens_eletricos_e_iluminacao": ["4 tomadas duplas", "1 interruptor simples", "3 spots de LED"]
    }}
  ],
  "totais_estimados": {{
    "total_pisos_m2": 0.0,
    "total_azulejos_m2": 0.0
  }}
}}
Retorne APENAS o JSON valido."""

    fonte_doc = None
    bucket = os.getenv("S3_BUCKET", "")
    # Accumulate comodo data across all pages (merge by room name)
    merged_comodos: dict[str, dict] = {}
    resumo_projeto = None
    pe_direito_utilizado = None
    area_total_override = None
    found_any = False

    for d in docs:
        try:
            object_key = extract_object_key(d.arquivo_url, bucket)
            pdf_bytes = download_by_url(d.arquivo_url, bucket, object_key)
            pages = extrair_paginas_como_imagens(pdf_bytes, dpi=150, max_pages=10)
        except Exception as exc:
            logger.warning("Falha ao baixar PDF %s: %s", d.arquivo_nome, exc)
            continue

        if fonte_doc is None:
            fonte_doc = d

        for page in pages:
            page_result = _extrair_detalhamento_vision_single(page, detalhamento_prompt)
            if not page_result:
                continue
            page_comodos = page_result.get("comodos", [])
            if not page_comodos:
                continue
            logger.info("Detalhamento encontrado na pagina %d do doc %s (%d comodos)", page[1], d.arquivo_nome, len(page_comodos))
            found_any = True
            if not resumo_projeto:
                resumo_projeto = page_result.get("resumo_projeto")
            if not pe_direito_utilizado:
                pe_direito_utilizado = page_result.get("pe_direito_utilizado")
            if area_total_override is None and page_result.get("area_total_m2"):
                area_total_override = page_result.get("area_total_m2")
            # Merge page comodos into accumulated dict by normalized room name
            for c in page_comodos:
                key = (c.get("nome") or "").strip().upper()
                if not key:
                    continue
                if key not in merged_comodos:
                    merged_comodos[key] = c
                else:
                    existing = merged_comodos[key]
                    # Prefer non-null values from new page for missing fields
                    for field in ("area_liquida_m2", "estimativa_piso_com_sobra_m2", "area_molhada", "estimativa_azulejo_parede_com_sobra_m2"):
                        if existing.get(field) is None and c.get(field) is not None:
                            existing[field] = c[field]
                    # Merge list fields (deduplicate)
                    for list_field in ("itens_hidraulicos_e_metais", "itens_eletricos_e_iluminacao"):
                        existing_list = existing.get(list_field) or []
                        new_list = c.get(list_field) or []
                        combined = list(existing_list)
                        for item in new_list:
                            if item not in combined:
                                combined.append(item)
                        if combined:
                            existing[list_field] = combined

    if not found_any:
        raise HTTPException(status_code=500, detail="Nenhuma planta com comodos/metragens encontrada nos documentos.")

    comodos = list(merged_comodos.values())
    # Fallback: calculate derived fields that the AI may have omitted
    PERDA = 0.15  # 15% waste factor
    for c in comodos:
        area = c.get("area_liquida_m2") or c.get("area_m2")
        if area:
            if c.get("estimativa_piso_com_sobra_m2") is None:
                c["estimativa_piso_com_sobra_m2"] = round(area * (1 + PERDA), 2)
            if c.get("area_molhada") is None:
                nome = (c.get("nome") or "").upper()
                c["area_molhada"] = any(w in nome for w in ("BANHO", "BANH", "LAVABO", "WC", "COZINHA", "LAVANDERIA", "VARANDA GOURMET"))
            if c.get("estimativa_azulejo_parede_com_sobra_m2") is None and c.get("area_molhada"):
                perimetro_est = round(4 * (area ** 0.5), 2)  # square approximation
                area_parede = perimetro_est * pe_direito
                area_parede -= 2.0  # descontar porta/janela padrão
                c["estimativa_azulejo_parede_com_sobra_m2"] = round(max(area_parede, 0) * (1 + PERDA), 2)
    # Compute totals
    totais = {
        "total_pisos_m2": sum(c.get("estimativa_piso_com_sobra_m2") or 0 for c in comodos),
        "total_azulejos_m2": sum(c.get("estimativa_azulejo_parede_com_sobra_m2") or 0 for c in comodos),
    }
    area_total = area_total_override
    if area_total is None:
        area_total = sum(c.get("area_liquida_m2") or c.get("area_m2") or 0 for c in comodos) or None

    # Upsert detalhamento
    det = session.exec(
        select(ObraDetalhamento).where(ObraDetalhamento.obra_id == obra_id)
    ).first()
    payload = json.dumps(comodos, ensure_ascii=False)
    if det:
        det.comodos = payload
        det.area_total_m2 = area_total
        det.fonte_doc_id = fonte_doc.id if fonte_doc else None
        det.fonte_doc_nome = fonte_doc.arquivo_nome if fonte_doc else None
        det.updated_at = datetime.now(timezone.utc)
    else:
        det = ObraDetalhamento(
            obra_id=obra_id,
            comodos=payload,
            area_total_m2=area_total,
            fonte_doc_id=fonte_doc.id if fonte_doc else None,
            fonte_doc_nome=fonte_doc.arquivo_nome if fonte_doc else None,
        )
    session.add(det)

    if area_total:
        obra.area_m2 = area_total
        session.add(obra)

    session.commit()
    return {
        "comodos": comodos,
        "area_total_m2": area_total,
        "resumo_projeto": resumo_projeto,
        "pe_direito_utilizado": pe_direito_utilizado,
        "totais_estimados": totais,
        "fonte_doc_nome": fonte_doc.arquivo_nome if fonte_doc else None,
    }
