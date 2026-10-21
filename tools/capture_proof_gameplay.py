import asyncio
import os
import sys
from playwright.async_api import async_playwright

CH = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "cine", "proof_v1190")
os.makedirs(OUT_DIR, exist_ok=True)

async def main():
    print(f"Starting browser with {CH}...")
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
        
        console_logs = []
        page.on("console", lambda msg: console_logs.append(f"[{msg.type}] {msg.text}"))
        
        print("Navigating to http://127.0.0.1:8990/index.html ...")
        sys.stdout.flush()
        await page.goto("http://127.0.0.1:8990/index.html")
        
        print("Waiting 20s for Godot WASM engine & PCK to load...")
        sys.stdout.flush()
        await page.wait_for_timeout(20000)
        
        async def click(x, y, wait_ms=1200):
            print(f"Click at ({x}, {y})")
            sys.stdout.flush()
            await page.mouse.click(x, y)
            await page.wait_for_timeout(wait_ms)
            
        # 1. Skip intro cinematic
        await click(1195, 45, 2000)
        await page.screenshot(path=os.path.join(OUT_DIR, "01_menu_hub.png"))
        print("Captured 01_menu_hub.png")
        sys.stdout.flush()
        
        # 2. Click JOUER (Main Menu -> Chapter Select)
        await click(640, 578, 2000)
        await page.screenshot(path=os.path.join(OUT_DIR, "02_chapter_select.png"))
        print("Captured 02_chapter_select.png")
        sys.stdout.flush()
        
        # 3. Select Chapter 1 (L'Usine)
        await click(640, 226, 1500)
        
        # 4. Skip Biome Intro Cutscene
        await click(1195, 45, 1000)
        await page.screenshot(path=os.path.join(OUT_DIR, "03_run_started.png"))
        print("Captured 03_run_started.png")
        sys.stdout.flush()
        
        # 5. Let the simulation run under SwiftShader (~4x CPU slowdown)
        # Capture progression over 70 real seconds to capture squad spawn and combat
        print("Running gameplay loop and capturing visual proofs of formations, shields, chef...")
        sys.stdout.flush()
        
        # Take shots at regular intervals
        intervals = [10000, 10000, 10000, 10000, 10000, 10000, 10000]
        for idx, wait_t in enumerate(intervals):
            await page.wait_for_timeout(wait_t)
            shot_path = os.path.join(OUT_DIR, f"04_gameplay_{idx+1:02d}.png")
            await page.screenshot(path=shot_path)
            print(f"Captured {shot_path} (step {idx+1}/{len(intervals)})")
            sys.stdout.flush()
            
        print("=== Recent Browser Console Logs ===")
        for log in console_logs[-15:]:
            print(" ", log)
            
        print("All gameplay captures completed successfully!")
        await browser.close()

if __name__ == "__main__":
    asyncio.run(main())
