"""
Módulo de push notifications via Firebase Cloud Messaging (FCM).

Configuração necessária:
  1. Crie um projeto Firebase em https://console.firebase.google.com
  2. Gere uma chave de serviço: Project Settings → Service accounts → Generate new private key
  3. Salve o JSON em algum caminho seguro (ex: /secrets/firebase.json)
  4. Defina a variável de ambiente: FIREBASE_CREDENTIALS_JSON=/secrets/firebase.json

Se FIREBASE_CREDENTIALS_JSON não estiver definida, o módulo opera em modo silencioso
(log de aviso, sem exceção) — o restante da API continua funcionando normalmente.
"""

import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)

_initialized = False


def _init() -> bool:
    """Inicializa o firebase-admin na primeira chamada. Retorna True se disponível."""
    global _initialized
    if _initialized:
        return True

    creds_path = os.getenv("FIREBASE_CREDENTIALS_JSON")
    if not creds_path:
        logger.warning("Push notifications desativadas: FIREBASE_CREDENTIALS_JSON não definida.")
        return False

    try:
        import firebase_admin  # type: ignore[import-untyped]
        from firebase_admin import credentials  # type: ignore[import-untyped]

        if not firebase_admin._apps:
            cred = credentials.Certificate(creds_path)
            firebase_admin.initialize_app(cred)

        _initialized = True
        logger.info("Firebase Admin inicializado com sucesso.")
        return True

    except ImportError:
        logger.warning("firebase-admin não instalado. Execute: pip install firebase-admin")
        return False
    except Exception as exc:
        logger.error("Falha ao inicializar Firebase Admin: %s", exc)
        return False


def enviar_push(
    token: str,
    titulo: str,
    corpo: str,
    data: Optional[dict] = None,
) -> bool:
    """
    Envia uma notificação push para um dispositivo via FCM.

    Args:
        token:  Token FCM do dispositivo de destino.
        titulo: Título da notificação.
        corpo:  Texto do corpo da notificação.
        data:   Payload de dados opcional (dict de str→str).

    Returns:
        True se enviada com sucesso, False caso contrário.
    """
    if not _init():
        return False

    try:
        from firebase_admin import messaging  # type: ignore[import-untyped]

        # FCM data payload aceita apenas strings
        str_data = {k: str(v) for k, v in (data or {}).items()}

        msg = messaging.Message(
            notification=messaging.Notification(title=titulo, body=corpo),
            data=str_data,
            android=messaging.AndroidConfig(priority="high"),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default"),
                ),
            ),
            token=token,
        )
        messaging.send(msg)
        logger.info("Push enviado para token %s…", token[:12])
        return True

    except Exception as exc:
        logger.error("Erro ao enviar push: %s", exc)
        return False


def enviar_push_multiplos(
    tokens: list[str],
    titulo: str,
    corpo: str,
    data: Optional[dict] = None,
) -> int:
    """
    Envia push para múltiplos tokens. Retorna quantos foram enviados com sucesso.
    Tokens inválidos/expirados são ignorados silenciosamente.
    """
    if not tokens or not _init():
        return 0

    try:
        from firebase_admin import messaging  # type: ignore[import-untyped]

        str_data = {k: str(v) for k, v in (data or {}).items()}

        messages = [
            messaging.Message(
                notification=messaging.Notification(title=titulo, body=corpo),
                data=str_data,
                android=messaging.AndroidConfig(priority="high"),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(sound="default"),
                    ),
                ),
                token=t,
            )
            for t in tokens
        ]
        response = messaging.send_each(messages)
        successCount = sum(1 for r in response.responses if r.success)
        logger.info("Push enviado: %d/%d dispositivos", successCount, len(tokens))
        return successCount

    except Exception as exc:
        logger.error("Erro ao enviar push em lote: %s", exc)
        return 0
