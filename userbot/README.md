# Pozzy Gift Userbot

The MTProto service sends Telegram Star Gifts on behalf of an authorized
Telegram account. The Dart bot communicates with it over a local HTTP API.

## Setup

1. Create `TELEGRAM_API_ID` and `TELEGRAM_API_HASH` at `my.telegram.org`.
2. Install dependencies from the project root:

   ```bash
   pip install -r userbot/requirements.txt
   ```

3. Fill the `USERBOT_*` and `TELEGRAM_*` variables in `.env`.
4. Authorize the Telegram account once:

   ```bash
   python -m userbot.login
   ```

5. Start the service:

   ```bash
   python -m userbot
   ```

## API

- `GET /health` returns connection and authorization state.
- `POST /send-gift` accepts `gift_id`, `recipient`, optional `message`, and
  `hide_name`.

Keep `USERBOT_HOST=127.0.0.1` unless the service is placed behind a secured
private network. Always configure a strong `USERBOT_API_SECRET`.
