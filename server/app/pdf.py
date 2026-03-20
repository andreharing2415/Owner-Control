from typing import Iterable

from fpdf import FPDF

from .models import Obra, Etapa, ChecklistItem


def _safe(text: str) -> str:
    """Remove chars not encodable in latin1 (Helvetica limit)."""
    return text.encode("latin1", errors="replace").decode("latin1")


def render_obra_pdf(obra: Obra, etapas: Iterable[Etapa], itens: dict[str, list[ChecklistItem]]) -> bytes:
    pdf = FPDF()
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.add_page()
    pdf.set_font("Helvetica", size=14)
    pdf.cell(0, 8, _safe("Relatorio da Obra"), new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", size=11)
    pdf.cell(0, 6, _safe(f"Obra: {obra.nome}"), new_x="LMARGIN", new_y="NEXT")
    if obra.localizacao:
        pdf.cell(0, 6, _safe(f"Localizacao: {obra.localizacao}"), new_x="LMARGIN", new_y="NEXT")
    if obra.orcamento is not None:
        pdf.cell(0, 6, _safe(f"Orcamento: {obra.orcamento:.2f}"), new_x="LMARGIN", new_y="NEXT")
    pdf.ln(4)

    for etapa in etapas:
        pdf.set_font("Helvetica", size=12)
        pdf.cell(0, 7, _safe(f"Etapa {etapa.ordem} - {etapa.nome}"), new_x="LMARGIN", new_y="NEXT")
        pdf.set_font("Helvetica", size=10)
        pdf.cell(0, 6, _safe(f"Status: {etapa.status} | Score: {etapa.score or 0:.1f}"), new_x="LMARGIN", new_y="NEXT")
        for item in itens.get(str(etapa.id), []):
            status = item.status
            label = f"  [{status}] {item.titulo}"
            pdf.multi_cell(w=0, h=5, text=_safe(label), new_x="LMARGIN", new_y="NEXT")
        pdf.ln(2)

    return bytes(pdf.output())
