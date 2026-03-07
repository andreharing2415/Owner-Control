from io import BytesIO
from typing import Iterable

from fpdf import FPDF

from .models import Obra, Etapa, ChecklistItem


def render_obra_pdf(obra: Obra, etapas: Iterable[Etapa], itens: dict[str, list[ChecklistItem]]) -> bytes:
    pdf = FPDF()
    pdf.set_auto_page_break(auto=True, margin=12)
    pdf.add_page()
    pdf.set_font("Helvetica", size=14)
    pdf.cell(0, 8, "Relatorio da Obra", ln=True)
    pdf.set_font("Helvetica", size=11)
    pdf.cell(0, 6, f"Obra: {obra.nome}", ln=True)
    if obra.localizacao:
        pdf.cell(0, 6, f"Localizacao: {obra.localizacao}", ln=True)
    if obra.orcamento is not None:
        pdf.cell(0, 6, f"Orcamento: {obra.orcamento:.2f}", ln=True)
    pdf.ln(4)

    for etapa in etapas:
        pdf.set_font("Helvetica", size=12)
        pdf.cell(0, 7, f"Etapa {etapa.ordem} - {etapa.nome}", ln=True)
        pdf.set_font("Helvetica", size=10)
        pdf.cell(0, 6, f"Status: {etapa.status} | Score: {etapa.score or 0:.1f}", ln=True)
        for item in itens.get(str(etapa.id), []):
            status = item.status
            label = f"- [{status}] {item.titulo}"
            pdf.multi_cell(0, 5, label)
        pdf.ln(2)

    pdf_bytes = pdf.output(dest="S").encode("latin1")
    buffer = BytesIO(pdf_bytes)
    return buffer.getvalue()
