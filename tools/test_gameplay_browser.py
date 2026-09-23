#!/usr/bin/env python3
"""
Playwright browser test script to test real gameplay in Web build:
Navigates: PASSER (1195,45) -> JOUER (640,578) -> NORMAL (640,288) -> Wait 8s in gameplay -> Capture screenshot
"""
import os, sys, time, subprocess
from playwright.sync_api import sync_playwright

CHROME_BIN = r"C:\Users\Administrator\AppData\Local\ms-playwright\chromium-1223\chrome-win64\chrome.exe"
URL = "http://127.0.0.1:8990/index.html"
OUT_IMG = r"C:\Users\Administrator\mecha-forge\meshy_in\previews\gameplay_darkstar.png"
OUT_ROOT = r"C:\Users\Administrator\mecha-forge\web_preview_gameplay.png"

def main():
    print("Launching Playwright Chromium...")
    with sync_playwright() as p:
        browser = p.chromium.launch(
            executable_path=CHROME_BIN,
            headless=True,
            args=[
                "--use-gl=angle",
                "--use-angle=swiftshader",
                "--enable-unsafe-swiftshader",
                "--no-sandbox",
                "--disable-setuid-sandbox",
            ]
        )
        page = browser.new_page(viewport={"width": 1280, "height": 720})
        print(f"Navigating to {URL}...")
        page.goto(URL, wait_until="networkidle")
        time.sleep(3)
        
        # 1. Click PASSER (1195, 45) to skip FTUE / Cutscene modal if open
        print("Clicking PASSER (1195, 45)...")
        page.mouse.click(1195, 45)
        time.sleep(2)
        
        # 2. Click JOUER (640, 578) on MetaScreen Hub
        print("Clicking JOUER (640, 578)...")
        page.mouse.click(640, 578)
        time.sleep(2)
        
        # 3. Click NORMAL (640, 288) on Difficulty modal
        print("Clicking NORMAL (640, 288)...")
        page.mouse.click(640, 288)
        time.sleep(2)
        
        # 4. Wait for gameplay to run for 8 seconds
        print("Waiting 8 seconds in real gameplay...")
        time.sleep(8)
        
        # Capture screenshot
        os.makedirs(os.path.dirname(OUT_IMG), exist_ok=True)
        page.screenshot(path=OUT_IMG)
        page.screenshot(path=OUT_ROOT)
        print(f"Captured gameplay screenshot: {OUT_IMG} and {OUT_ROOT}")
        browser.close()

if __name__ == "__main__":
    main()
