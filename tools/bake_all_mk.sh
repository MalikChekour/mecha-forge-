#!/bin/bash
# Cuit les 6 versions MK (cardinales + diagonales) puis regenere les .import. Journal : /tmp/bake_mk.log
cd /c/Users/Administrator/mecha-forge || exit 1
for pair in "vortex 2" "bluestrike 2" "vortex 3" "bluestrike 3" "vortex 4" "bluestrike 4"; do
  set -- $pair
  echo "[$(date +%H:%M:%S)] $1 mk$2 cardinales"
  python tools/build_mk_anims.py --base $1 --mk $2 --anims walk,attack 2>&1 | grep -E "BAKED|DONE|Traceback|Error" | tail -3
  echo "[$(date +%H:%M:%S)] $1 mk$2 diagonales"
  python tools/build_mk_anims.py --base $1 --mk $2 --diag --anims walk,attack 2>&1 | grep -E "DONE|Traceback|Error" | tail -3
  echo "[$(date +%H:%M:%S)] $1 mk$2 TERMINE"
done
echo "[$(date +%H:%M:%S)] FINI"
