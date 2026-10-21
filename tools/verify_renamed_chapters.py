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
        
        async def click(x, y, wait_ms=1500):
            await page.mouse.click(x, y)
            await page.wait_for_timeout(wait_ms)
            
        # 1. Skip intro & open Chapter Select
        await click(1187, 42, 2000)
        await click(500, 300, 2000)
        
        # 2. Capture chapters 1 to 4 (showing Terres Arides & Le Coeur des Ressources)
        await page.screenshot(path=os.path.join(OUT_DIR, "verify_chap_2_and_4.png"))
        print("Captured verify_chap_2_and_4.png")
        sys.stdout.flush()
        
        # 3. Scroll down to chapter 14 (showing Miroir Quantique)
        await page.mouse.move(500, 400)
        for _ in range(22):
            await page.mouse.wheel(0, 500)
            await page.wait_for_timeout(150)
        await page.wait_for_timeout(1500)
        await page.screenshot(path=os.path.join(OUT_DIR, "verify_chap_14_miroir.png"))
        print("Captured verify_chap_14_miroir.png")
        sys.stdout.flush()
        
        await browser.close()

if __name__ == "__main__":
    asyncio.run(main())
