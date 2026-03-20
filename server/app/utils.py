"""Utilidades compartilhadas entre modulos de IA."""


def clean_json_response(text: str) -> str:
    """Remove blocos de markdown se presentes na resposta da IA."""
    cleaned = text.strip()
    if cleaned.startswith("```"):
        lines = cleaned.split("\n")
        cleaned = (
            "\n".join(lines[1:-1])
            if lines[-1].strip() == "```"
            else "\n".join(lines[1:])
        )
    return cleaned
