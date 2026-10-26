extends Node
## Rewarded-ad plumbing.
##
## PROVIDER_LIVE is the single switch. While it is FALSE there is no ad network in the build, so
## a "rewarded" placement simply GRANTS its reward: no fake ad screen, and no UI anywhere may say
## "pub". Showing a full-screen placeholder titled PUBLICITE that is not an ad is a Play policy
## risk (Deceptive Behavior / Misrepresentation), which is why the old simulated overlay was
## deleted rather than kept behind a flag.
##
## Everything around the provider is final: daily caps, the reward callback, the cancel path,
## and every call site. Going live with AdMob means:
##   1. add the Godot AdMob plugin (poingstudios) and set gradle_build/use_gradle_build=true on
##      BOTH Android presets — without a gradle build no Android plugin can load at all
##   2. add com.google.android.gms.ads.APPLICATION_ID to the manifest (its absence crashes the
##      app on boot) and put the real ids in UNIT_IDS below
##   3. run the UMP consent flow BEFORE MobileAds.initialize()
##   4. rewrite _provider_show() to load+show and forward the plugin's rewarded/dismissed signals
##      into _finish(), then set PROVIDER_LIVE = true
## Nothing else in the game needs to change — the labels pick the wording up from is_live().

signal ad_finished(placement: String, rewarded: bool)

## Flip to true ONLY once a real network actually shows ads (see the header).
const PROVIDER_LIVE: bool = false

const CAPS: Dictionary = {"revive": 2, "double_scrap": 3, "free_pull": 2, "skill_points": 3}
const LABELS: Dictionary = {
	"revive": "REVIVRE", "double_scrap": "DOUBLER LA FERRAILLE", "free_pull": "INVOCATION GRATUITE"}
## Real AdMob rewarded unit ids go here (currently Google's public TEST ids — never ship these).
const UNIT_IDS: Dictionary = {
	"revive": "ca-app-pub-3940256099942544/5224354917",
	"double_scrap": "ca-app-pub-3940256099942544/5224354917",
	"free_pull": "ca-app-pub-3940256099942544/5224354917",
}

var _showing: bool = false
var _cb: Callable = Callable()
var _placement: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # must run while the game tree is paused

## Whether a real ad network is behind these placements. UI wording keys off this so no screen
## can ever promise a "pub" that will not play.
func is_live() -> bool:
	return PROVIDER_LIVE

## True when this placement can still be used today (and none is already in flight).
func available(placement: String) -> bool:
	if _showing:
		return false
	return SaveManager.ads_used(placement) < int(CAPS.get(placement, 0))

func remaining(placement: String) -> int:
	return maxi(0, int(CAPS.get(placement, 0)) - SaveManager.ads_used(placement))

## Request a rewarded grant. on_reward is called with true only if the reward was actually earned.
func show_rewarded(placement: String, on_reward: Callable) -> void:
	if not available(placement):
		if on_reward.is_valid():
			on_reward.call(false)
		return
	_showing = true
	_cb = on_reward
	_placement = placement
	_provider_show(placement)

## THE ONLY PART THAT CHANGES WHEN A REAL NETWORK IS PLUGGED IN.
## Today: grant straight away, deferred one frame so the caller's own UI rebuild happens after
## show_rewarded() has returned — the same async shape a real SDK callback would have.
func _provider_show(_placement_id: String) -> void:
	_finish.call_deferred(true)

## Single exit point: consumes a daily cap only on an earned reward, then fires the callback.
## Ordering matters — the cap is consumed BEFORE the callback so a UI rebuild inside the callback
## reads the updated remaining() count.
func _finish(rewarded: bool) -> void:
	if not _showing:
		return
	_showing = false
	if rewarded:
		SaveManager.ads_consume(_placement)
	var cb: Callable = _cb
	var p: String = _placement
	_cb = Callable()
	_placement = ""
	ad_finished.emit(p, rewarded)
	if cb.is_valid():
		cb.call(rewarded)
