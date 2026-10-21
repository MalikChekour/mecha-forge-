import asyncio
import os
import sys
from playwright.async_api import async_playwright

CH = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "cine", "proof_v1190")

async def main():
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
        await page.goto("http://127.0.0.1:8990/index.html")
        print("Loading...")
        sys.stdout.flush()
        await page.wait_for_timeout(20000)
        
        async def click(x, y, wait_ms=1500, desc=""):
            print(f"Click at ({x}, {y}) - {desc}")
            sys.stdout.flush()
            await page.mouse.click(x, y)
            await page.wait_for_timeout(wait_ms)
            
        # 1. Skip intro & open Chapter Select
        await click(1187, 42, 2000, "Skip Opening")
        await click(500, 300, 2000, "Click JOUER")
        
        # 2. Scroll down on chapter select to reveal Chapter 6 (Cryo)
        print("Scrolling to Chapter 6...")
        sys.stdout.flush()
        await page.mouse.move(500, 400)
        await page.mouse.wheel(0, 350)
        await page.wait_for_timeout(1000)
        await page.screenshot(path=os.path.join(OUT_DIR, "chapter_scroll_cryo.png"))
        
        # Deploy Chapter 6
        # Find and click Chapter 6 DEPLOYER button
        await click(835, 380, 2000, "Deploy Chapter 6 (Cryo)")
        await click(1187, 42, 2000, "Skip Biome Intro")
        
        print("Waiting for Chapter 6 gameplay & squad spawn (sniper + garde)...")
        sys.stdout.flush()
        for i in range(8):
            await page.wait_for_timeout(6000)
            shot_path = os.path.join(OUT_DIR, f"ch6_cryo_step_{i+1:02d}.png")
            await page.screenshot(path=shot_path)
            print(f"Captured {shot_path}")
            sys.stdout.flush()
            
        await browser.close()

if __name__ == "__main__":
    asyncio.run(main())
