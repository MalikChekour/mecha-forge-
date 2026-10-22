"""Resume du banc d'equilibre : python tools/bal_resume.py bal_all.txt"""
import re, sys
cur=None; rows={}
for l in open(sys.argv[1],encoding="utf-8",errors="ignore"):
    m=re.match(r'BAL chapitre (\d+)',l)
    if m: cur=int(m.group(1)); rows[cur]=[]; continue
    m=re.match(r'BAL t=\s*(\d+) niv=\s*(\d+) pv=\s*(\d+)/\s*(\d+) ennemis=\s*(\d+) kills=\s*(\d+) vivant=(\w+).*vit_joueur=(\d+) vit_ennemis_moy=(\d+)',l)
    if m and cur: rows[cur].append(m.groups())
for c in sorted(rows):
    r=rows[c]
    if not r: print(c,'rien'); continue
    l=r[-1]
    pvmin=min(int(x[2])*100//max(1,int(x[3])) for x in r)
    print('ch%02d fin t=%4s niv=%2s pv=%3s/%3s ennemis=%3s kills=%4s vivant=%-5s pv%%min=%3d | niv@120=%s'%((c,)+tuple(l[:7])+(pvmin, next((x[1] for x in r if int(x[0])>=120),'-'))))
