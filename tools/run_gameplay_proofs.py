import asyncio
import os
import sys
from playwright.async_api import async_playwright

CH = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "cine", "proof_v1190")
os.makedirs(OUT_DIR, exist_ok=True)

async def main():
    print(f"Launching Chrome with SwiftShader from {CH}...")
    sys.stdout.flush()
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            executable_path=CH,
            headless=True,
            args=[
                "--use-gl=angle",
                "--use-angle=swiftshader",
                "--enable-unsafe-swiftshader",
                "--ignore-gpu-blocklist",
                "--enable-webgl",
                "--disable-gpu-sandbox",
                "--no-sandbox"
            ]
        )
        page = await browser.new_page(viewport={"width": 1280, "height": 720})
        
        logs = []
        page.on("console", lambda msg: logs.append(f"[{msg.type}] {msg.text}"))
        
        print("Loading http://127.0.0.1:8990/index.html ...")
        sys.stdout.flush()
        await page.goto("http://127.0.0.1:8990/index.html")
        
        # 1. Wait for engine load
        print("Waiting 20s for Godot WASM engine...")
        sys.stdout.flush()
        await page.wait_for_timeout(20000)
        
        async def click(x, y, wait_ms=1500, desc=""):
            print(f"Click at ({x}, {y}) - {desc}")
            sys.stdout.flush()
            await page.mouse.click(x, y)
            await page.wait_for_timeout(wait_ms)
            
        # 2. Skip opening story cutscene
        await click(1187, 42, 2000, "Skip Opening Story")
        await page.screenshot(path=os.path.join(OUT_DIR, "01_main_menu.png"))
        print("Saved 01_main_menu.png")
        sys.stdout.flush()
        
        # 3. Click JOUER
        await click(500, 300, 2000, "Click JOUER")
        await page.screenshot(path=os.path.join(OUT_DIR, "02_chapter_select.png"))
        print("Saved 02_chapter_select.png")
        sys.stdout.flush()
        
        # 4. Click Chapter 1 (L'Usine) DEPLOYER button at (835, 255)
        await click(835, 255, 2000, "Deploy Chapter 1")
        
        # 5. Skip Biome Intro Cutscene
        await click(1187, 42, 2000, "Skip Biome Intro")
        await page.screenshot(path=os.path.join(OUT_DIR, "03_arena_start.png"))
        print("Saved 03_arena_start.png")
        sys.stdout.flush()
        
        # 6. Wait for teleport + gameplay + squad spawn (takes ~45-60s in SwiftShader)
        print("Waiting for teleport-in and squad spawn under SwiftShader (~50s)...")
        sys.stdout.flush()
        
        for i in range(10):
            await page.wait_for_timeout(6000)
            shot_name = f"04_gameplay_step_{i+1:02d}.png"
            shot_path = os.path.join(OUT_DIR, shot_name)
            await page.screenshot(path=shot_path)
            print(f"Captured {shot_name} (time elapsed: {(i+1)*6}s)")
            sys.stdout.flush()
            
        print("Finished all captures!")
        await browser.close()

if __name__ == "__main__":
    asyncio.run(main())
