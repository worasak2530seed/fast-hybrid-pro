#!/usr/bin/env python3
"""Send a Telegram message without printing credentials or API response bodies."""
import json
import os
import sys
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

def main() -> int:
    token = os.getenv("TELEGRAM_BOT_TOKEN")
    chat_id = os.getenv("TELEGRAM_CHAT_ID")
    message = " ".join(sys.argv[1:]).strip()
    if not token or not chat_id:
        print("TELEGRAM_NOTIFY_FAILED: required environment variables are missing.", file=sys.stderr)
        return 2
    if not message:
        print("TELEGRAM_NOTIFY_FAILED: message is empty.", file=sys.stderr)
        return 2
    url = "https://api.telegram.org/bot" + token + "/sendMessage"
    body = urlencode({"chat_id": chat_id, "text": message, "disable_web_page_preview": "true"}).encode("utf-8")
    request = Request(url, data=body, headers={"Content-Type": "application/x-www-form-urlencoded"}, method="POST")
    try:
        with urlopen(request, timeout=20) as response:
            payload = json.loads(response.read().decode("utf-8", errors="replace"))
            if response.status == 200 and payload.get("ok") is True:
                print("TELEGRAM_NOTIFY_OK")
                return 0
            print("TELEGRAM_NOTIFY_FAILED: Telegram rejected the message.", file=sys.stderr)
            return 1
    except HTTPError as exc:
        print("TELEGRAM_NOTIFY_FAILED: HTTP " + str(exc.code) + ".", file=sys.stderr)
        return 1
    except (URLError, TimeoutError, OSError, ValueError):
        print("TELEGRAM_NOTIFY_FAILED: network or response error.", file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
