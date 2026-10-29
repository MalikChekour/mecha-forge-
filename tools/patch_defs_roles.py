# -*- coding: utf-8 -*-
from pathlib import Path
import re
p = Path(r"C:\Users\Administrator\mecha-forge\game\systems\EnemySpawner.gd")
text = p.read_text(encoding="utf-8")
changes = []
for n, biome in [(1, "tech"), (2, "desert"), (3, "jungle")]:
    for role in ("swarm", "shield", "sniper"):
        key = "mech%02d_%s" % (n, role)
        chassis_new = "en%02d_%s_%s" % (n, biome, role)
        pat = re.compile(r'("%s"\s*:\s*\{[^}]*?"chassis":\s*")([^"]+)(")' % re.escape(key))
        m = pat.search(text)
        if not m:
            print("MISS", key)
            continue
        old = m.group(2)
        if old == chassis_new:
            print("already", key, old)
            continue
        text, nsub = pat.subn(r"\g<1>%s\g<3>" % chassis_new, text, count=1)
        if nsub:
            changes.append((key, old, chassis_new))
            print("OK", key, old, "->", chassis_new)
        else:
            print("FAIL", key)
p.write_text(text, encoding="utf-8")
print("changes", len(changes))
for line in text.splitlines():
    m = re.search(r'"(mech0[123]_(?:swarm|shield|sniper))".*?"chassis":\s*"([^"]+)"', line)
    if m:
        print(m.group(1), "=>", m.group(2))
