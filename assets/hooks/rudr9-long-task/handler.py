"""Alert when a worker exceeds N tool-call iterations."""

import os
import httpx

THRESHOLD = 15
BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
CHAT_ID = os.getenv("TELEGRAM_HOME_CHANNEL", "")


async def handle(event_type: str, context: dict):
    iteration = context.get("iteration", 0)
    if iteration == THRESHOLD and BOT_TOKEN and CHAT_ID:
        tools = ", ".join(context.get("tool_names", []))
        text = (
            f"⚠️ RUDR9: Agent hit {THRESHOLD} iterations. "
            f"Last tools: {tools}. Check the Kanban board."
        )
        async with httpx.AsyncClient() as client:
            await client.post(
                f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
                json={"chat_id": CHAT_ID, "text": text},
            )