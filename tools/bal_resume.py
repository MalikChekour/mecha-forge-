"""Resume du banc d'equilibre : python tools/bal_resume.py bal_all.txt"""
import re, sys
cur=None; rows={}; raw_lines={}; kills_tier={}; victoires={}
for l in open(sys.argv[1],encoding="utf-8",errors="ignore"):
    m=re.match(r'BAL chapitre (\d+)',l)
    if m:
        cur=int(m.group(1)); rows[cur]=[]; raw_lines[cur]=[]; kills_tier[cur]=[]; continue
    if cur:
        mk = re.search(r'\[KILL (\w+) en ([\d\.]+) s', l)
        if mk:
            kills_tier[cur].append((mk.group(1), float(mk.group(2))))
        mv = re.search(r'\[VICTOIRE t=(\d+) s', l)
        if mv:
            victoires[cur] = int(mv.group(1))
    m=re.match(r'BAL t=\s*(\d+) niv=\s*(\d+) pv=\s*(\d+)/\s*(\d+) ennemis=\s*(\d+) kills=\s*(\d+) vivant=(\w+).*vit_joueur=(\d+) vit_ennemis_moy=(\d+)',l)
    if m and cur:
        rows[cur].append(m.groups())
        raw_lines[cur].append(l.strip())
for c in sorted(rows):
    r=rows[c]
    if not r: print(c,'rien'); continue
    l=r[-1]
    raw = raw_lines[c][-1]
    pvmin=min(int(x[2])*100//max(1,int(x[3])) for x in r)
    mort = ""
    m_mort = re.search(r'\[mort:([^\]]+)\]', raw)
    if m_mort:
        mort = f" mort={m_mort.group(1)}"
    elif c in victoires:
        mort = f" VICTOIRE@{victoires[c]}s"
    m_deg = re.search(r'\[degats: ([^\]]+)\]', raw)
    deg = f" | {m_deg.group(1)}" if m_deg else ""
    kt = ""
    if kills_tier.get(c):
        kt = " | kills: " + ", ".join(f"{t}:{s:.0f}s" for t, s in kills_tier[c])
    print('ch%02d fin t=%4s niv=%2s pv=%3s/%3s ennemis=%3s kills=%4s vivant=%-5s pv%%min=%3d%s%s%s | niv@120=%s'%((c,)+tuple(l[:7])+(pvmin, mort, deg, kt, next((x[1] for x in r if int(x[0])>=120),'-'))))

