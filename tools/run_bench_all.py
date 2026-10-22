"""Script de banc d'equilibre automatique (18 chapitres)
Usage:
  python tools/run_bench_all.py [--start=1] [--end=18] [--secs=900] [--scale=8] [--out=tools/bal_resultats/bal_all6.txt] [--parallel=3]
"""
import sys, os, subprocess, time, argparse, concurrent.futures

GODOT = r"C:\Users\Administrator\godot_ci\Godot_v4.3-stable_win64_console.exe"
REPO_GAME = r"C:\Users\Administrator\mecha-forge\game"

def run_chapter(ch, secs, scale):
    cmd = [GODOT, "--headless", "--path", REPO_GAME, "res://_bal_run.tscn", "--", f"--ch={ch}", f"--secs={secs}", f"--scale={scale}"]
    t0 = time.time()
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="ignore")
    lines = []
    for line in p.stdout:
        if line.startswith("BAL "):
            if not line.endswith("\n"):
                line += "\n"
            lines.append(line)
            print(f"[ch{ch:02d}] {line.strip()}", flush=True)
    p.wait()
    dur = time.time() - t0
    return ch, lines, dur

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--start", type=int, default=1)
    parser.add_argument("--end", type=int, default=18)
    parser.add_argument("--secs", type=int, default=900)
    parser.add_argument("--scale", type=int, default=8)
    parser.add_argument("--parallel", type=int, default=3)
    parser.add_argument("--out", type=str, default=r"tools\bal_resultats\bal_all6.txt")
    args = parser.parse_args()

    print(f"=== BANC EQUILIBRE CH {args.start}..{args.end} (secs={args.secs}, scale={args.scale}, parallel={args.parallel}) ===", flush=True)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    
    chapters = list(range(args.start, args.end + 1))
    results = {}

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.parallel) as executor:
        future_to_ch = {executor.submit(run_chapter, ch, args.secs, args.scale): ch for ch in chapters}
        for future in concurrent.futures.as_completed(future_to_ch):
            ch = future_to_ch[future]
            try:
                ch, lines, dur = future.result()
                results[ch] = lines
                print(f"--> Chapitre {ch} termine en {dur:.1f}s mur ({len(lines)} lignes BAL)", flush=True)
            except Exception as exc:
                print(f"--> Chapitre {ch} a genere une exception: {exc}", flush=True)

    with open(args.out, "w", encoding="utf-8") as f:
        for ch in sorted(results.keys()):
            for line in results[ch]:
                f.write(line)

    print(f"\n=== RESULTATS SAUVEGARDES DANS {args.out} ===", flush=True)
    # Appelle bal_resume sur le fichier produit
    subprocess.run([sys.executable, r"tools\bal_resume.py", args.out])

if __name__ == "__main__":
    main()
