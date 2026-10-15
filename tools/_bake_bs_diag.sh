#!/bin/bash
cd /c/Users/Administrator/mecha-forge || exit 1
# attend la fin du bake VORTEX (canon de bras)
while pgrep -f build_vortex_gun_anims >/dev/null 2>&1 || tasklist 2>/dev/null | grep -qi "blender"; do sleep 10; done
echo "[$(date +%H:%M:%S)] bluestrike diag"
python tools/bake_eyebase.py --diag 2>&1 | grep -E "SHEET|DONE|Traceback|Error"
for d in front_right front_left back_right back_left; do cp meshy_in/bluestrike_eyebase/walk_$d.png game/assets/mecha/bluestrike_walk_$d.png; done
echo "[$(date +%H:%M:%S)] BS DONE"
