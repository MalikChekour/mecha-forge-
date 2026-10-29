import os
import io
from PIL import Image
from google import genai

key_path = r"C:\Users\Administrator\.imagen_key"
with open(key_path, "r", encoding="utf-8") as f:
    key = f.read().strip()

client = genai.Client(api_key=key)

models_to_test = [
    "gemini-2.5-flash-image",
    "gemini-3.1-flash-lite-image",
    "gemini-3-pro-image",
    "gemini-3.1-flash-image",
]

for mod in models_to_test:
    print(f"Testing model: {mod}")
    try:
        resp = client.models.generate_content(
            model=mod,
            contents="High quality concept art of a futuristic military Gundam mecha, orange cockpit, studio background"
        )
        saved = False
        if resp.candidates and resp.candidates[0].content:
            for part in resp.candidates[0].content.parts:
                if getattr(part, "inline_data", None) and part.inline_data.data:
                    img = Image.open(io.BytesIO(part.inline_data.data))
                    out_name = f"test_{mod}.png"
                    img.save(out_name)
                    print(f"--> SUCCESS with {mod}: saved {out_name} ({img.size})")
                    saved = True
                    break
        if not saved:
            txt = getattr(resp, "text", "") or ""
            print(f"--> No inline image returned from {mod}. Text: {txt[:100]}")
        else:
            break
    except Exception as e:
        print(f"--> ERROR with {mod}: {type(e).__name__} - {e}")
