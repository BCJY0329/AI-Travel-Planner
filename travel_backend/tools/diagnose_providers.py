"""Opt-in live diagnosis. Uses configured credentials without displaying them.
Runs synthetic chat only; no itinerary/context lookups. No production timeout changes.
"""
import asyncio
import logging
import sys
import time
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'venv' / 'Lib' / 'site-packages'))
sys.path.insert(0, str(root))
logging.basicConfig(level=logging.WARNING)
logging.getLogger('lemon_ai').setLevel(logging.INFO)

from services.chat_parser import parse_chat
from services.llm_providers.diagnostics import error_details
from models.chat import LemonChatRequest
from config import settings


async def main():
    from fastapi.testclient import TestClient
    from main import app
    with TestClient(app) as client:
        print('Application startup /health:', client.get('/health').status_code, flush=True)
        response = client.post('/lemon/chat', json={'provider': 'mock', 'messages': [{'role': 'user', 'content': 'osaka'}]})
        print('Mock HTTP chat:', response.status_code, 'next_field:', response.json().get('next_field'), flush=True)
    for name in ['groq', 'gemini', 'auto']:
        request = LemonChatRequest(provider=name, messages=[
            {'role': 'assistant', 'content': 'Where would you like to go?'},
            {'role': 'user', 'content': 'osaka'},
            {'role': 'assistant', 'content': 'When would you like to start your trip?'},
            {'role': 'user', 'content': '2026-10-15'},
        ])
        started = time.monotonic()
        try:
            result = await asyncio.wait_for(parse_chat(request), timeout=50)
            print(name, 'PASS', 'next_field=', result.next_field, 'elapsed=', round(time.monotonic()-started, 2), flush=True)
        except Exception as exc:
            print(name, 'FAIL', error_details(exc), 'elapsed=', round(time.monotonic()-started, 2), flush=True)
            if name == 'gemini':
                model = settings.GEMINI_MODEL
                print('Gemini model:', model if re.fullmatch(r'gemini-[a-zA-Z0-9.-]+', model) else '<nonstandard identifier>', flush=True)
                # Inspect SDK text in memory; emit only fixed diagnostic labels.
                message = str(exc).lower()
                print('Gemini flags:', {
                    'model_not_found': 'not found' in message and 'model' in message,
                    'method_not_supported': 'not supported' in message,
                    'mentions_v1beta': 'v1beta' in message,
                }, flush=True)


if __name__ == '__main__':
    asyncio.run(main())
