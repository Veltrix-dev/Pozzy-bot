import os

import uvicorn


def main() -> None:
    host = os.getenv('USERBOT_HOST', '127.0.0.1')
    port = int(os.getenv('USERBOT_PORT', '8090'))
    uvicorn.run('userbot.app:app', host=host, port=port, reload=False)


if __name__ == '__main__':
    main()
