#!/bin/bash
# 14/10 : bake des 4 DIAGONALES (front_right/front_left/back_right/back_left) pour les chassis jouables.
# idle/walk/run/attack suffisent (deplacement + tir) ; hit/die/melee retombent sur les cardinales.
cd /c/Users/Administrator/mecha-forge || exit 1
log(){ echo "[$(date +%H:%M:%S)] $*"; }
log "vortex idle/run/attack"
python tools/build_vortex_anims.py --diag --anims idle,run,attack 2>&1 | grep -E "Saved sprite|Traceback|Error"
for c in bruiser titan vanquisher; do
  log "$c walk (Meshy)"
  python tools/bake_walk_mech.py -- $c --diag 2>&1 | grep -E "saved|Saved|Traceback|Error|wrote|OK"
  log "$c idle/run/attack"
  python tools/build_${c}_anims.py --diag --anims idle,run,attack 2>&1 | grep -E "Saved sprite|Traceback|Error"
done
log "DONE"
