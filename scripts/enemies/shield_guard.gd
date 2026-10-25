class_name ShieldGuard
extends Enemy
## Hộ vệ khiên: a tower shield turns aside blows from the front ("guard_arc") while it stands,
## walks or thrusts its spear (not mid shield bash): only "guard_reduction" of the damage and a
## little poise get through, and no status — except Thổ, whose cracks pass the shield. The guard
## wears down ("guard" points per blocked poise); a heavy blow or an emptied guard breaks it,
## leaving the guard reeling. It turns slowly ("turn_rate"), so circling behind it works.

signal guarded(enemy: ShieldGuard, broke: bool)

## Seconds without a blocked blow before the guard starts to recover.
const GUARD_RECOVER_DELAY: float = 3.0

var guard: float = 60.0
var guard_idle: float = 0.0

func setup(entity: Dictionary, library: AssetLibrary, world_manager: WorldManager) -> void:
	super.setup(entity, library, world_manager)
	guard = float(data.get("guard", 60.0))

func _process(delta: float) -> void:
	super._process(delta)
	guard_idle += delta * time_dilation
	if guard_idle > GUARD_RECOVER_DELAY:
		guard = minf(float(data.get("guard", 60.0)), guard + float(data.get("guard", 60.0)) * 0.25 * delta * time_dilation)

func _choose_attack(distance: float) -> String:
	return "thrust" if distance > 2.0 or randf() < 0.4 else "bash"

func shielding(damage: Combat.Damage) -> bool:
	## Whether the shield is up and between this guard and the blow.
	if state in ["dead", "stagger", "hit"] or damage.unblockable or damage.reaction_splash:
		return false
	if state == "attack" and attack_name == "bash":
		return false
	var incoming: Vector3 = -damage.direction
	incoming.y = 0.0
	if incoming.length() < 0.05:
		return false
	return facing.dot(incoming.normalized()) > float(data.get("guard_arc", 0.25))

func take_damage(damage: Combat.Damage) -> Dictionary:
	if not shielding(damage):
		return super.take_damage(damage)
	guard_idle = 0.0
	var spent: float = maxf(damage.poise, 6.0)
	if damage.heavy or guard - spent <= 0.0:
		# A heavy blow (or the last of the guard) bats the shield aside: full damage and a long reel.
		guard = float(data.get("guard", 60.0))
		var result: Dictionary = super.take_damage(damage)
		if state != "dead":
			_break(float(data.get("guard_break", 2.2)))
		emit_signal("guarded", self, true)
		return result
	guard -= spent
	damage.amount *= float(data.get("guard_reduction", 0.15))
	damage.poise *= 0.3
	damage.flinch = false
	if damage.element != "earth":
		damage.status = {}
	var shield: Vector3 = global_position + Vector3.UP * float(data.get("height", 1.9)) * 0.55 + facing * 0.55
	Vfx.burst(get_parent(), shield, Color(1.0, 0.85, 0.55), 12, 5.0, 0.07, 0.25)
	if visual.has_animation("block") and state != "attack":
		visual.play_action("block")
	emit_signal("guarded", self, false)
	var outcome: Dictionary = super.take_damage(damage)
	outcome["guarded"] = true
	return outcome
