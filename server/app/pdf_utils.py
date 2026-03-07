"""Utilitário para extrair páginas de PDFs como imagens base64 para análise por IA."""

import base64
import logging
from typing import Generator

logger = logging.getLogger(__name__)

MAX_PAGES = 30


def extrair_paginas_como_imagens(
    pdf_bytes: bytes, dpi: int = 150, max_pages: int = MAX_PAGES
) -> list[tuple[str, int]]:
    """
    Converte cada página do PDF em imagem JPEG base64.

    Returns:
        Lista de tuplas (base64_jpeg, numero_pagina) — 1-indexed
    """
    import fitz  # pymupdf
    import gc

    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    total = min(len(doc), max_pages)
    paginas: list[tuple[str, int]] = []

    for i in range(total):
        page = doc[i]
        mat = fitz.Matrix(dpi / 72, dpi / 72)
        pix = page.get_pixmap(matrix=mat)
        jpeg_bytes = pix.tobytes("jpeg")
        b64 = base64.standard_b64encode(jpeg_bytes).decode("utf-8")
        paginas.append((b64, i + 1))
        logger.debug("Página %d/%d extraída (%d bytes JPEG)", i + 1, total, len(jpeg_bytes))
        del pix, jpeg_bytes
        gc.collect()

    if len(doc) > max_pages:
        logger.warning("PDF tem %d páginas, apenas %d extraídas", len(doc), max_pages)

    doc.close()
    del doc
    gc.collect()
    return paginas


def extrair_pagina_individual(
    pdf_bytes: bytes, page_index: int, dpi: int = 150
) -> tuple[str, int]:
    """
    Extrai UMA página específica do PDF como JPEG base64.
    Libera memória imediatamente.

    Returns:
        Tupla (base64_jpeg, numero_pagina) — 1-indexed
    """
    import fitz
    import gc

    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    page = doc[page_index]
    mat = fitz.Matrix(dpi / 72, dpi / 72)
    pix = page.get_pixmap(matrix=mat)
    jpeg_bytes = pix.tobytes("jpeg")
    b64 = base64.standard_b64encode(jpeg_bytes).decode("utf-8")
    page_num = page_index + 1

    del pix, jpeg_bytes
    doc.close()
    del doc
    gc.collect()

    return b64, page_num


def contar_paginas(pdf_bytes: bytes) -> int:
    """Conta páginas de um PDF sem extrair imagens."""
    import fitz
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    count = len(doc)
    doc.close()
    return count
