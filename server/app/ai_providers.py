"""
Camada de abstração para provedores de IA com fallback chain.

ARQ-07 — Dependency Injection para AI Providers.

Unifica o padrão Gemini -> Claude -> OpenAI em uma interface configurável,
eliminando duplicação de código nos módulos de análise.

Uso:
    from .ai_providers import get_vision_chain, get_text_chain, call_with_fallback

    # Análise de visão (imagens/PDFs)
    result = call_with_fallback(get_vision_chain(), pages, arquivo_nome)

    # Análise de texto (prompts)
    result = call_with_fallback(get_text_chain(), prompt)
"""

import base64
import json
import logging
import os
from typing import Any, Callable, Protocol

from .utils import clean_json_response

logger = logging.getLogger(__name__)


# ─── Protocols ────────────────────────────────────────────────────────────────


class VisionProvider(Protocol):
    """Protocol para provedores que analisam imagens."""

    name: str

    def analyze_vision(
        self,
        content_parts: list[dict],
        max_tokens: int = 4096,
    ) -> str:
        """Envia conteúdo multimodal (texto + imagem) e retorna texto bruto."""
        ...


class TextProvider(Protocol):
    """Protocol para provedores que analisam texto."""

    name: str

    def analyze_text(
        self,
        prompt: str,
        max_tokens: int = 4096,
    ) -> str:
        """Envia prompt de texto e retorna texto bruto."""
        ...


# ─── Implementações concretas ─────────────────────────────────────────────────


class GeminiProvider:
    """Provider Gemini (Google Generative AI)."""

    name = "Gemini"

    def __init__(self, model: str = "gemini-2.5-flash", api_key: str | None = None):
        self._model_name = model
        self._api_key = api_key or os.getenv("GEMINI_API_KEY")

    def _ensure_key(self) -> str:
        if not self._api_key:
            raise ValueError("GEMINI_API_KEY nao configurada")
        return self._api_key

    def analyze_vision(self, content_parts: list[dict], max_tokens: int = 4096) -> str:
        key = self._ensure_key()
        import google.generativeai as genai
        from google.generativeai.types import content_types

        genai.configure(api_key=key)
        model = genai.GenerativeModel(self._model_name)

        parts = []
        for part in content_parts:
            if part["type"] == "text":
                parts.append(part["text"])
            elif part["type"] == "image":
                img_bytes = base64.standard_b64decode(part["data"])
                parts.append(
                    content_types.to_part({
                        "mime_type": part.get("media_type", "image/png"),
                        "data": img_bytes,
                    })
                )

        response = model.generate_content(parts)
        text = response.text
        if not text:
            raise ValueError("Gemini nao retornou resposta valida")
        return text

    def analyze_text(self, prompt: str, max_tokens: int = 4096) -> str:
        key = self._ensure_key()
        import google.generativeai as genai

        genai.configure(api_key=key)
        model = genai.GenerativeModel(self._model_name)
        response = model.generate_content(prompt)
        text = response.text
        if not text:
            raise ValueError("Gemini nao retornou resposta valida")
        return text


class ClaudeProvider:
    """Provider Claude (Anthropic)."""

    name = "Claude"

    def __init__(self, model: str = "claude-sonnet-4-6", api_key: str | None = None):
        self._model = model
        self._api_key = api_key or os.getenv("ANTHROPIC_API_KEY")

    def _ensure_key(self) -> str:
        if not self._api_key:
            raise ValueError("ANTHROPIC_API_KEY nao configurada")
        return self._api_key

    def _get_client(self):
        import anthropic
        return anthropic.Anthropic(api_key=self._ensure_key())

    def analyze_vision(self, content_parts: list[dict], max_tokens: int = 4096) -> str:
        client = self._get_client()
        blocks: list[dict] = []
        for part in content_parts:
            if part["type"] == "text":
                blocks.append({"type": "text", "text": part["text"]})
            elif part["type"] == "image":
                blocks.append({
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": part.get("media_type", "image/png"),
                        "data": part["data"],
                    },
                })

        response = client.messages.create(
            model=self._model,
            max_tokens=max_tokens,
            messages=[{"role": "user", "content": blocks}],
        )
        text = response.content[0].text if response.content else ""
        if not text:
            raise ValueError("Claude nao retornou resposta valida")
        return text

    def analyze_text(self, prompt: str, max_tokens: int = 4096) -> str:
        client = self._get_client()
        response = client.messages.create(
            model=self._model,
            max_tokens=max_tokens,
            messages=[{"role": "user", "content": prompt}],
        )
        text = response.content[0].text if response.content else ""
        if not text:
            raise ValueError("Claude nao retornou resposta valida")
        return text


class OpenAIProvider:
    """Provider OpenAI."""

    name = "OpenAI"

    def __init__(self, model: str = "gpt-4o", api_key: str | None = None):
        self._model = model
        self._api_key = api_key or os.getenv("OPENAI_API_KEY")

    def _ensure_key(self) -> str:
        if not self._api_key:
            raise ValueError("OPENAI_API_KEY nao configurada")
        return self._api_key

    def _get_client(self):
        from openai import OpenAI
        return OpenAI(api_key=self._ensure_key())

    def analyze_vision(self, content_parts: list[dict], max_tokens: int = 4096) -> str:
        client = self._get_client()
        blocks: list[dict] = []
        for part in content_parts:
            if part["type"] == "text":
                blocks.append({"type": "text", "text": part["text"]})
            elif part["type"] == "image":
                media = part.get("media_type", "image/png")
                blocks.append({
                    "type": "image_url",
                    "image_url": {"url": f"data:{media};base64,{part['data']}"},
                })

        response = client.chat.completions.create(
            model=self._model,
            messages=[{"role": "user", "content": blocks}],
            max_tokens=max_tokens,
        )
        text = response.choices[0].message.content or ""
        if not text:
            raise ValueError("OpenAI nao retornou resposta valida")
        return text

    def analyze_text(self, prompt: str, max_tokens: int = 4096) -> str:
        client = self._get_client()
        response = client.chat.completions.create(
            model=self._model,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=max_tokens,
        )
        text = response.choices[0].message.content or ""
        if not text:
            raise ValueError("OpenAI nao retornou resposta valida")
        return text


class OpenAIWebSearchProvider(OpenAIProvider):
    """Provider OpenAI com web search (Responses API)."""

    name = "OpenAI-WebSearch"

    def analyze_text(self, prompt: str, max_tokens: int = 4096) -> str:
        client = self._get_client()
        response = client.responses.create(
            model=self._model,
            tools=[{"type": "web_search_preview"}],
            input=prompt,
        )
        output_text = ""
        for item in response.output:
            if hasattr(item, "content"):
                for block in item.content:
                    if hasattr(block, "text"):
                        output_text = block.text
                        break
            if output_text:
                break
        if not output_text:
            raise ValueError("OpenAI web search nao retornou resposta valida")
        return output_text


# ─── Fallback Chain ──────────────────────────────────────────────────────────


def call_vision_with_fallback(
    providers: list,
    content_parts: list[dict],
    max_tokens: int = 4096,
    task_label: str = "",
) -> dict:
    """Executa análise de visão com fallback chain.

    Args:
        providers: Lista de instâncias com método analyze_vision().
        content_parts: Lista de dicts com type="text"|"image".
        max_tokens: Limite de tokens na resposta.
        task_label: Label para logs.

    Returns:
        Dict parseado do JSON retornado pelo provider.
    """
    last_error = None
    for provider in providers:
        try:
            raw = provider.analyze_vision(content_parts, max_tokens)
            result = json.loads(clean_json_response(raw))
            logger.info("%s concluida via %s", task_label or "Analise", provider.name)
            return result
        except Exception as exc:
            logger.warning(
                "%s falhou via %s: %s",
                task_label or "Analise", provider.name, exc,
            )
            last_error = exc

    raise ValueError(
        f"Todos os providers falharam{f' para {task_label}' if task_label else ''}. "
        f"Ultimo erro: {last_error}"
    )


def call_text_with_fallback(
    providers: list,
    prompt: str,
    max_tokens: int = 4096,
    task_label: str = "",
) -> dict:
    """Executa análise de texto com fallback chain.

    Args:
        providers: Lista de instâncias com método analyze_text().
        prompt: Texto do prompt.
        max_tokens: Limite de tokens na resposta.
        task_label: Label para logs.

    Returns:
        Dict parseado do JSON retornado pelo provider.
    """
    last_error = None
    for provider in providers:
        try:
            raw = provider.analyze_text(prompt, max_tokens)
            result = json.loads(clean_json_response(raw))
            logger.info("%s concluida via %s", task_label or "Chamada IA", provider.name)
            return result
        except Exception as exc:
            logger.warning(
                "%s falhou via %s: %s",
                task_label or "Chamada IA", provider.name, exc,
            )
            last_error = exc

    raise ValueError(
        f"Todos os providers falharam{f' para {task_label}' if task_label else ''}. "
        f"Ultimo erro: {last_error}"
    )


# ─── Factory functions (chains pré-configuradas) ─────────────────────────────


def get_document_vision_chain() -> list:
    """Chain para análise de documentos: Gemini -> Claude -> OpenAI (modelos pesados)."""
    return [
        GeminiProvider(model="gemini-2.5-flash"),
        ClaudeProvider(model="claude-sonnet-4-6"),
        OpenAIProvider(model="gpt-4o"),
    ]


def get_visual_inspection_chain() -> list:
    """Chain para análise visual de fotos: Gemini -> Claude -> OpenAI."""
    return [
        GeminiProvider(model="gemini-2.5-flash"),
        ClaudeProvider(model="claude-sonnet-4-6"),
        OpenAIProvider(model="gpt-4o"),
    ]


def get_checklist_page_chain() -> list:
    """Chain para análise de página de checklist: Gemini -> OpenAI -> Claude (modelos leves)."""
    return [
        GeminiProvider(model="gemini-2.5-flash"),
        OpenAIProvider(model="gpt-4o-mini"),
        ClaudeProvider(model="claude-haiku-4-5-20251001"),
    ]


def get_checklist_generation_chain() -> list:
    """Chain para geração de itens de checklist: Gemini -> OpenAI (com web search)."""
    return [
        GeminiProvider(model="gemini-2.5-flash"),
        OpenAIWebSearchProvider(model="gpt-4o-mini"),
    ]


def get_checklist_enrichment_chain() -> list:
    """Chain para enriquecimento de itens: Gemini -> OpenAI -> Claude (modelos leves)."""
    return [
        GeminiProvider(model="gemini-2.5-flash"),
        OpenAIProvider(model="gpt-4o-mini"),
        ClaudeProvider(model="claude-haiku-4-5-20251001"),
    ]


def get_schedule_text_chain() -> list:
    """Chain para geração de cronograma: Gemini -> OpenAI."""
    return [
        GeminiProvider(model="gemini-2.5-flash"),
        OpenAIProvider(model="gpt-4o"),
    ]
