"""Read-only Gemini model availability diagnosis; never print raw SDK errors."""
import asyncio
import sys
from pathlib import Path
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'venv' / 'Lib' / 'site-packages'))
sys.path.insert(0, str(root))
from config import settings
from google import genai
from services.llm_providers.diagnostics import error_details

async def main():
    client = genai.Client(api_key=settings.GEMINI_API_KEY)
    try:
        models = await asyncio.wait_for(client.aio.models.list(), 30)
        names = []
        async for model in models:
            if model.name and model.name.startswith('models/gemini-'):
                names.append(model.name)
        target = 'models/' + settings.GEMINI_MODEL.removeprefix('models/')
        print('Configured model listed:', target in names, flush=True)
        print('Available Gemini model IDs:', ', '.join(names), flush=True)
        try:
            await asyncio.wait_for(client.aio.models.get(model=settings.GEMINI_MODEL), 30)
            print('Configured model metadata lookup: success', flush=True)
        except Exception as exc:
            print('Configured model metadata lookup:', error_details(exc), flush=True)
    except Exception as exc:
        print('Model listing:', error_details(exc), flush=True)
    finally:
        try:
            metadata = await asyncio.wait_for(client.aio.models.get(model=settings.GEMINI_MODEL), 30)
            print('Model supports generateContent:', 'generateContent' in (getattr(metadata, 'supported_actions', None) or []), flush=True)
            print('Independent model metadata lookup: success', flush=True)
        except Exception as exc:
            print('Independent model metadata lookup:', error_details(exc), flush=True)
        try:
            result = await asyncio.wait_for(client.aio.models.generate_content(model=settings.GEMINI_MODEL, contents='Reply with the word hello.'), 30)
            print('Minimal Gemini generation: success; text present:', bool(result.text), flush=True)
        except Exception as exc:
            print('Minimal Gemini generation:', error_details(exc), flush=True)
        close = getattr(client.aio, 'aclose', None)
        if close is not None:
            await close()

if __name__ == '__main__':
    asyncio.run(main())
