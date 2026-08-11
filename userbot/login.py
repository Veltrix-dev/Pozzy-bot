"""One-time QR login: python -m userbot.login."""

import asyncio
import getpass

import qrcode
from telethon.errors import PasswordHashInvalidError, SessionPasswordNeededError

from userbot.client import get_client


def _print_qr(url: str) -> None:
    qr = qrcode.QRCode(border=1)
    qr.add_data(url)
    qr.make(fit=True)
    qr.print_ascii(invert=True)


async def _wait_for_2fa(client) -> None:
    while True:
        password = getpass.getpass('2FA password: ')
        try:
            await client.sign_in(password=password)
            return
        except PasswordHashInvalidError:
            print('Invalid password, try again.')


async def _login_with_qr(client) -> None:
    print('Open Telegram on your phone: Settings -> Devices -> Link Desktop Device')
    print('Scan the QR code below:\n')

    qr_login = await client.qr_login()
    while True:
        _print_qr(qr_login.url)
        print('\nWaiting for scan (60s)...')

        try:
            await qr_login.wait(60)
            return
        except SessionPasswordNeededError:
            await _wait_for_2fa(client)
            return
        except asyncio.TimeoutError:
            print('QR expired, generating a new one...\n')
            await qr_login.recreate()


async def main() -> None:
    client = get_client()
    await client.connect()

    if await client.is_user_authorized():
        me = await client.get_me()
        print(f'Already logged in as {me.username or me.id}')
        await client.disconnect()
        return

    await _login_with_qr(client)

    me = await client.get_me()
    print(f'\nLogged in as {me.username or me.id}')
    await client.disconnect()


if __name__ == '__main__':
    asyncio.run(main())
