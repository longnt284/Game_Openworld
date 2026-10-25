class_name Wolf
extends Enemy
## Sói sương: fast pack hunters. They circle at a distance while the camp's attack slots are
## taken, pounce from mid range (a leaping lunge, data "lunge") and snap when close; their bites
## chill. The pack leader ("howl" in its attacks) howls once it is hurt and then every
## "howl_every" seconds, maddening every wolf of its camp nearby (Cuồng nộ) and frosting the air.

signal howled(enemy: Wolf)

## The first howl comes this soon into a fight, later ones every "howl_every" seconds.
var howl_timer: float = 9.0
var hurt_howl: bool = false

func _choose_attack(distance: float) -> String:
	var options: Array = data.get("attacks", ["bite"])
	if options.has("howl") and howl_timer <= 0.0:
		return "howl"
	if options.has("howl") and not hurt_howl and health < max_health * 0.7:
		hurt_howl = true
		return "howl"
	if distance > float(data.get("bite_range", 2.0)) and options.has("pounce"):
		return "pounce"
	return "bite"

func _physics_chase(delta: float) -> void:
	howl_timer -= delta
	if target != null and not target.is_dead() and cooldown <= 0.0:
		var distance: float = _flat_distance(target.global_position)
		var reach: float = float(data.get("attack_range", 6.0))
		# A pounce launches from anywhere inside its reach, not only at arm's length.
		if distance <= reach and distance >= float(data.get("pounce_min", 3.0)) and _take_token():
			_begin_attack(_choose_attack(distance))
			return
		if distance <= float(data.get("bite_range", 2.0)) + 0.2 and _take_token():
			_begin_attack(_choose_attack(distance))
			return
	super._physics_chase(delta)

func _attack_window(t: float, hit_start: float, hit_end: float) -> void:
	if attack_name != "howl":
		super._attack_window(t, hit_start, hit_end)
		return
	if attack_hits.has("howled"):
		return
	attack_hits["howled"] = true
	howl_timer = float(data.get("howl_every", 18.0))
	var reach: float = float(attack_data.get("rally_radius", 18.0))
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var other: Enemy = node as Enemy
		if other and not other.is_dead() and (other == self or (other.camp == camp and camp != "")) and other.global_position.distance_to(global_position) <= reach:
			other.apply_status("enemy_rage", 1)
			Vfx.ring(get_parent(), other.global_position + Vector3.UP * 0.2, 1.4, Color("bfefff"), 0.4, 0.14)
	Vfx.ring(get_parent(), global_position + Vector3.UP * 0.3, reach * 0.5, Color("bfefff"), 0.7, 0.3)
	Vfx.shards(get_parent(), global_position, Color("dff8ff"), 10, 3.5, 1.4, 1.0)
	if target and target.global_position.distance_to(global_position) <= float(attack_data.get("frost_radius", 6.0)):
		target.apply_status("chill", 1)
	emit_signal("howled", self)
