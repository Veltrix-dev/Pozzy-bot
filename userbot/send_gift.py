import logging
import re
from typing import Any

from telethon.errors import FloodWaitError, RPCError
from telethon.tl.functions.payments import (
    GetPaymentFormRequest,
    GetStarGiftsRequest,
    SendStarsFormRequest,
)
from telethon.tl.types import InputInvoiceStarGift, TextWithEntities

from userbot.client import ensure_connected, is_connected

logger = logging.getLogger(__name__)

_REAL_GIFT_ID_THRESHOLD = 1_000_000


def _classify_error(exc: Exception) -> dict[str, Any]:
    text = str(exc).upper()
    if 'BALANCE_TOO_LOW' in text or 'STARS' in text and 'INSUFFICIENT' in text:
        return {'success': False, 'error': 'BALANCE_TOO_LOW', 'detail': str(exc)}
    if (
        'PEER_ID_INVALID' in text
        or 'COULD NOT FIND THE INPUT ENTITY' in text
        or 'INPUT ENTITY' in text
    ):
        return {'success': False, 'error': 'PEER_ID_INVALID', 'detail': str(exc)}
    if 'USERNAME_INVALID' in text or 'USERNAME_NOT_OCCUPIED' in text:
        return {'success': False, 'error': 'USERNAME_INVALID', 'detail': str(exc)}
    if 'USER_ID_INVALID' in text:
        return {'success': False, 'error': 'PEER_ID_INVALID', 'detail': str(exc)}
    if 'STARGIFT_USAGE_LIMITED' in text:
        return {'success': False, 'error': 'STARGIFT_USAGE_LIMITED', 'detail': str(exc)}
    if 'STARGIFT_INVALID' in text or 'GIFT' in text and 'INVALID' in text:
        return {'success': False, 'error': 'STARGIFT_INVALID', 'detail': str(exc)}
    if isinstance(exc, FloodWaitError):
        return {
            'success': False,
            'error': 'FLOOD_WAIT',
            'detail': str(exc),
            'wait_seconds': exc.seconds,
        }
    return {'success': False, 'error': 'UNKNOWN', 'detail': str(exc)}


async def _resolve_real_gift_id(
    client,
    gift_id: int,
    stars_cost: int | None,
) -> int:
    if gift_id >= _REAL_GIFT_ID_THRESHOLD:
        return gift_id

    if stars_cost is None:
        raise ValueError('stars_cost is required when gift_id is a catalog index')

    result = await client(GetStarGiftsRequest(hash=0))
    gifts = getattr(result, 'gifts', None) or []
    matching = [
        gift
        for gift in gifts
        if getattr(gift, 'stars', None) == stars_cost
        and not getattr(gift, 'sold_out', False)
    ]

    if not matching:
        raise ValueError(f'No available gifts with stars_cost={stars_cost}')

    index = gift_id
    if 0 <= index < len(matching):
        return int(matching[index].id)
    return int(matching[0].id)


def _parse_recipient(recipient: str) -> str | int:
    value = recipient.strip()
    if value.startswith('@'):
        value = value[1:]
    if re.fullmatch(r'\d+', value):
        return int(value)
    return value


async def _resolve_peer(client, recipient: str):
    parsed = _parse_recipient(recipient)
    try:
        return await client.get_input_entity(parsed)
    except (ValueError, TypeError) as exc:
        if not isinstance(parsed, int):
            raise ValueError(
                f'Cannot resolve recipient {recipient!r}. Use a valid @username.',
            ) from exc

        async for dialog in client.iter_dialogs():
            entity = dialog.entity
            if getattr(entity, 'id', None) == parsed:
                return await client.get_input_entity(entity)

        raise ValueError(
            f'Cannot resolve user id {parsed}. '
            'Userbot does not know this user - use @username instead.',
        ) from exc


async def send_gift(
    *,
    gift_id: str | int | None,
    recipient: str,
    stars_cost: int | None = None,
    message: str | None = None,
    hide_name: bool = True,
) -> dict[str, Any]:
    if not is_connected():
        try:
            await ensure_connected()
        except Exception as exc:
            logger.error('Userbot not connected: %s', exc)
            return {
                'success': False,
                'error': 'USERBOT_NOT_CONNECTED',
                'detail': str(exc),
            }

    if gift_id is None or str(gift_id).strip() == '':
        return {
            'success': False,
            'error': 'GIFT_ID_NOT_FOUND',
            'detail': 'Gift ID not found',
        }

    try:
        client = await ensure_connected()
        parsed_gift_id = int(gift_id)
        real_gift_id = await _resolve_real_gift_id(
            client,
            parsed_gift_id,
            stars_cost,
        )
        peer = await _resolve_peer(client, recipient)

        invoice = InputInvoiceStarGift(
            peer=peer,
            gift_id=real_gift_id,
            hide_name=hide_name,
            message=TextWithEntities(message or '', []) if message else None,
        )

        form = await client(GetPaymentFormRequest(invoice=invoice))
        await client(SendStarsFormRequest(form_id=form.form_id, invoice=invoice))

        return {'success': True, 'real_gift_id': real_gift_id}
    except RPCError as exc:
        logger.error('send_gift RPC error: %s', exc)
        return _classify_error(exc)
    except Exception as exc:
        logger.error('send_gift error: %s', exc)
        return _classify_error(exc)
