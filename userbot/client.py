import logging
import os
from pathlib import Path

from dotenv import load_dotenv
from telethon import TelegramClient

load_dotenv(Path(__file__).resolve().parent.parent / '.env')

logger = logging.getLogger(__name__)

_api_id = os.getenv('TELEGRAM_API_ID', '').strip()
_api_hash = os.getenv('TELEGRAM_API_HASH', '').strip()
_session_name = os.getenv('USERBOT_SESSION', 'data/userbot').strip()

_client: TelegramClient | None = None


def _require_credentials() -> tuple[int, str]:
    if not _api_id or not _api_hash:
        raise RuntimeError('TELEGRAM_API_ID and TELEGRAM_API_HASH are required')
    return int(_api_id), _api_hash


def get_client() -> TelegramClient:
    global _client
    if _client is None:
        api_id, api_hash = _require_credentials()
        session_path = _session_name
        if not session_path.startswith('/') and ':' not in session_path[:3]:
            session_path = str(Path(__file__).resolve().parent.parent / session_path)
        _client = TelegramClient(session_path, api_id, api_hash)
    return _client


def is_connected() -> bool:
    client = get_client()
    return client.is_connected()


async def ensure_connected() -> TelegramClient:
    client = get_client()
    if not client.is_connected():
        await client.connect()
    if not await client.is_user_authorized():
        raise RuntimeError(
            'Userbot session is not authorized. Run: python -m userbot.login (QR code)',
        )
    return client


async def disconnect() -> None:
    global _client
    if _client is not None and _client.is_connected():
        await _client.disconnect()
