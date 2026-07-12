#!/bin/bash
# Re-bake every spawned enemy's loop animation in 4 directions (front/back/left/right).
cd /c/Users/Administrator/mecha-forge || exit 1
EN=game/assets/enemies
log(){ echo "[$(date +%H:%M:%S)] $*"; }

log "raider (rig 4dir)"
python tools/bake_rig.py meshy_in/raider/model.glb $EN/raider_walk.png walk --dirs 4 --frames 8 --res 220 --samples 18 2>&1 | grep -E "RIG walk"

log "crusher (rig 4dir)"
python tools/bake_rig.py meshy_in/crusher/model.glb $EN/crusher_walk.png walk --dirs 4 --legsep 0.22 --armsep 0.37 --frames 8 --res 220 --samples 18 2>&1 | grep -E "RIG walk"

log "spitter (Meshy idle 4dir)"
python tools/bake_anim.py meshy_in/spitter/anim_idle.glb $EN/spitter_walk.png --dirs 4 --frames 8 --res 220 --samples 18 2>&1 | grep -E "SHEET"

log "brute (Meshy walk 4dir)"
python tools/bake_anim.py meshy_in/brute/anim_walk.glb $EN/brute_walk.png --dirs 4 --frames 8 --res 220 --samples 18 2>&1 | grep -E "SHEET"

log "elite (Meshy walk 4dir)"
python tools/bake_anim.py meshy_in/elite/anim_walk.glb $EN/elite_walk.png --dirs 4 --frames 8 --res 220 --samples 18 2>&1 | grep -E "SHEET"

log "shielded (Meshy walk 4dir)"
python tools/bake_anim.py meshy_in/shielded/anim_walk.glb $EN/shielded_walk.png --dirs 4 --frames 8 --res 220 --samples 18 2>&1 | grep -E "SHEET"

log "crawler (proc scuttle 4dir)"
python tools/bake_proc.py meshy_in/crawler/model.glb $EN/crawler_walk.png scuttle --dirs 4 --frames 8 --res 220 --samples 16 2>&1 | grep -E "PROC"

log "drone (proc hover 4dir)"
python tools/bake_proc.py meshy_in/drone/model.glb $EN/drone_hover.png hover --dirs 4 --frames 8 --res 200 --samples 16 2>&1 | grep -E "PROC"

log "rusher (proc spin 4dir)"
python tools/bake_proc.py meshy_in/rusher/model.glb $EN/rusher_spin.png spin --dirs 4 --frames 8 --res 200 --samples 16 2>&1 | grep -E "PROC"

log "DONE 4dir batch"
