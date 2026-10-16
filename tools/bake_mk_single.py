import sys, subprocess, time

def run(cmd):
    t0 = time.time()
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    dt = time.time() - t0
    lines = [l for l in p.stdout.splitlines() if "BAKED" in l or "DONE" in l or "Error" in l or "Traceback" in l]
    print(f"[{time.strftime('%H:%M:%S')}] CMD: {cmd} ({dt:.1f}s)")
    if lines:
        for l in lines[-4:]:
            print("  ", l)
    if p.returncode != 0:
        print("STDERR:", p.stderr[-500:])
        sys.exit(p.returncode)

if __name__ == "__main__":
    base = sys.argv[1]
    mk = sys.argv[2]
    print(f"=== BAKING {base.upper()} MK {mk} ===")
    run(f"python tools/build_mk_anims.py --base {base} --mk {mk} --anims idle,walk,attack")
    run(f"python tools/build_mk_anims.py --base {base} --mk {mk} --diag --anims idle,walk,attack")
    print(f"=== {base.upper()} MK {mk} BAKED SUCCESSFULLY ===")
