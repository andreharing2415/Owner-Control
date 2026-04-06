"""PDF rendering — WeasyPrint + Jinja2 with full UTF-8/PT-BR support."""

import os
from typing import Iterable

from jinja2 import Environment, FileSystemLoader, select_autoescape
from weasyprint import HTML

from .models import Obra, Etapa, ChecklistItem

_TEMPLATES_DIR = os.path.join(os.path.dirname(__file__), "templates")
_jinja_env = Environment(
    loader=FileSystemLoader(_TEMPLATES_DIR),
    autoescape=select_autoescape(["html"]),
)


def render_obra_pdf(obra: Obra, etapas: Iterable[Etapa], itens: dict[str, list[ChecklistItem]]) -> bytes:
    """Gera PDF da obra em bytes com acentuação PT-BR preservada."""
    etapas_list = list(etapas)
    template = _jinja_env.get_template("obra_relatorio.html")
    html_content = template.render(
        obra=obra,
        etapas=etapas_list,
        itens=itens,
    )
    return HTML(string=html_content, base_url=_TEMPLATES_DIR).write_pdf()
