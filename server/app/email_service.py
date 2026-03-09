"""Serviço de envio de e-mail para convites (magic link)."""

import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)


def enviar_email_convite(
    destinatario: str,
    obra_nome: str,
    dono_nome: str,
    papel: str,
    token: str,
) -> bool:
    """Envia e-mail de convite com magic link.

    Usa SendGrid se SENDGRID_API_KEY estiver configurado.
    Caso contrário, loga o link (para desenvolvimento).
    """
    base_url = os.getenv(
        "APP_BASE_URL",
        "https://mestreobra-backend-530484413221.us-central1.run.app",
    )
    # Deep link para o app Flutter (será interceptado pelo app)
    magic_link = f"{base_url}/api/convites/aceitar?token={token}"

    subject = f"Convite para acompanhar a obra: {obra_nome}"
    body_html = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #1a73e8;">Mestre da Obra</h2>
        <p>Olá!</p>
        <p><strong>{dono_nome}</strong> convidou você para acompanhar a obra
           <strong>"{obra_nome}"</strong> como <strong>{papel}</strong>.</p>
        <p>Com este convite você poderá:</p>
        <ul>
            <li>Acompanhar todas as etapas da obra</li>
            <li>Preencher e criar itens do checklist</li>
            <li>Enviar fotos e documentos como evidência</li>
            <li>Adicionar comentários nas etapas</li>
        </ul>
        <p style="margin: 30px 0;">
            <a href="{magic_link}"
               style="background-color: #1a73e8; color: white; padding: 14px 28px;
                      text-decoration: none; border-radius: 8px; font-size: 16px;">
                Aceitar Convite
            </a>
        </p>
        <p style="color: #666; font-size: 12px;">
            Este link expira em 7 dias. Se você não reconhece este convite, ignore este e-mail.
        </p>
    </div>
    """
    body_text = (
        f"{dono_nome} convidou você para acompanhar a obra \"{obra_nome}\" como {papel}.\n\n"
        f"Aceite o convite acessando: {magic_link}\n\n"
        f"Este link expira em 7 dias."
    )

    sendgrid_key = os.getenv("SENDGRID_API_KEY")
    if sendgrid_key:
        return _send_via_sendgrid(sendgrid_key, destinatario, subject, body_html, body_text)

    resend_key = os.getenv("RESEND_API_KEY")
    if resend_key:
        return _send_via_resend(resend_key, destinatario, subject, body_html)

    # Fallback: log para desenvolvimento
    logger.info(
        "EMAIL DE CONVITE (dev mode):\n  Para: %s\n  Obra: %s\n  Link: %s",
        destinatario, obra_nome, magic_link,
    )
    return True


def _send_via_sendgrid(
    api_key: str,
    to_email: str,
    subject: str,
    html_content: str,
    text_content: str,
) -> bool:
    """Envia e-mail via SendGrid."""
    try:
        import httpx
        resp = httpx.post(
            "https://api.sendgrid.com/v3/mail/send",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "personalizations": [{"to": [{"email": to_email}]}],
                "from": {"email": os.getenv("EMAIL_FROM", "noreply@mestreobra.com.br"), "name": "Mestre da Obra"},
                "subject": subject,
                "content": [
                    {"type": "text/plain", "value": text_content},
                    {"type": "text/html", "value": html_content},
                ],
            },
            timeout=10,
        )
        if resp.status_code in (200, 201, 202):
            return True
        logger.error("SendGrid error: %s %s", resp.status_code, resp.text)
        return False
    except Exception as exc:
        logger.error("SendGrid exception: %s", exc)
        return False


def _send_via_resend(
    api_key: str,
    to_email: str,
    subject: str,
    html_content: str,
) -> bool:
    """Envia e-mail via Resend."""
    try:
        import httpx
        resp = httpx.post(
            "https://api.resend.com/emails",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "from": os.getenv("EMAIL_FROM", "Mestre da Obra <noreply@mestreobra.com.br>"),
                "to": [to_email],
                "subject": subject,
                "html": html_content,
            },
            timeout=10,
        )
        if resp.status_code in (200, 201):
            return True
        logger.error("Resend error: %s %s", resp.status_code, resp.text)
        return False
    except Exception as exc:
        logger.error("Resend exception: %s", exc)
        return False
