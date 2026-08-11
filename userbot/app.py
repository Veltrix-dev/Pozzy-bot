import logging
import os
from contextlib import asynccontextmanager
from typing import Any

from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

from userbot.client import disconnect, ensure_connected, is_connected
from userbot.send_gift import send_gift

logging.basicConfig(level=logging.WARNING)
logger = logging.getLogger(__name__)

_API_SECRET = os.getenv('USERBOT_API_SECRET', '').strip()


class SendGiftRequest(BaseModel):
    gift_id: str = Field(..., min_length=1)
    recipient: str = Field(..., min_length=1)
    stars_cost: int | None = None
    message: str | None = None
    hide_name: bool = True


async def _require_auth(
    x_userbot_secret: str | None = Header(default=None, alias='X-Userbot-Secret'),
) -> None:
    if not _API_SECRET:
        return
    if x_userbot_secret != _API_SECRET:
        raise HTTPException(status_code=401, detail='Unauthorized')


@asynccontextmanager
async def lifespan(_: FastAPI):
    try:
        await ensure_connected()
    except Exception as exc:
        logger.error('Userbot startup connect failed: %s', exc)
    yield
    await disconnect()


app = FastAPI(title='Pozzy Gift Userbot', lifespan=lifespan)


@app.get('/health')
async def health() -> dict[str, Any]:
    connected = is_connected()
    authorized = False
    if connected:
        try:
            client = await ensure_connected()
            authorized = await client.is_user_authorized()
        except Exception:
            authorized = False
    return {
        'ok': connected and authorized,
        'connected': connected,
        'authorized': authorized,
    }


@app.post('/send-gift')
async def send_gift_endpoint(
    body: SendGiftRequest,
    _: None = Depends(_require_auth),
) -> dict[str, Any]:
    return await send_gift(
        gift_id=body.gift_id,
        recipient=body.recipient,
        stars_cost=body.stars_cost,
        message=body.message,
        hide_name=body.hide_name,
    )
