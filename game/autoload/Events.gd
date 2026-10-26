extends Node
## Global signal bus — decouples systems (player / enemies / pickups / HUD / FX).
## Pattern ported from the reference project; every FX and UI element hangs off this.

signal enemy_killed(pos: Vector2, rank: int)
signal player_damaged(hp: float, max_hp: float)
signal player_died()
signal xp_gained(amount: int)
signal level_up(level: int)
signal scrap_collected(amount: int)
signal draft_requested(cards: Array)
signal run_time_changed(t: float)
signal screen_shake(amount: float)
signal damage_dealt(pos: Vector2, amount: int, crit: bool)
signal hit_spark(pos: Vector2, color: Color)
signal overdrive_changed(value: float)
signal player_transformed(active: bool)
signal run_won()
