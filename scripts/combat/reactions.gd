class_name Reactions
extends RefCounted
## Elemental reactions: a blow whose element (or a heavy swing) meets a status already on an
## enemy sets off the first matching rule in data/reactions.json "reactions" (file order is
## priority). Enemy.take_damage asks before the blow lands and before its status roll. Rule fields:
##   id, name, color, hint      the floating "Name!" label, burst, sound "sfx", first-time hint
##   needs                      statuses on the target; any one of them is enough
##   element | trigger "heavy"  the incoming element, or any blow tagged "heavy" in attacks.json
##   mult, poise_mult, break    this blow × mult (its bonus grown by reaction_dmg) and × poise_mult;
##                              "break" lets the poise damage knock a staggered (frozen) foe down
##   consume                    statuses the reaction uses up
##   apply {status, stacks}     replaces the blow's own status roll on the target; "fallback" when
##                              it cannot take (a boss never freezes)
##   radius, splash, chain      other enemies within radius take splash × the blow (before the
##                              reaction's bonus); "chain" hops nearest-first instead of all at once
##   spread_needs, splash_status  splash only targets carrying one of these; status they all get
## Splash packets keep the original source (kill credit) but reach take_damage directly, never
## through PlayerController.strike, so they grant no lifesteal, meter or hit numbers of their own;
## they are marked reaction_splash and can never set off another reaction.

static func list() -> Array:
	return (ContentDB.get_data("reactions") as Dictionary).get("reactions", [])

static func find(id: String) -> Dictionary:
	for reaction: Dictionary in list():
		if String(reaction.get("id", "")) == id:
			return reaction
	return {}

static func check(statuses: StatusEffects, damage: Combat.Damage) -> Dictionary:
	## The reaction this blow sets off on a target carrying `statuses`, or {} for none.
	if damage.reaction_splash or damage.reaction != "":
		return {}
	for reaction: Dictionary in list():
		if String(reaction.get("trigger", "")) == "heavy":
			if not damage.heavy:
				continue
		elif damage.element == "" or damage.element != String(reaction.get("element", "")):
			continue
		for id: Variant in reaction.get("needs", []):
			if statuses.has(String(id)):
				return reaction
	return {}

static func bonus_mult(reaction: Dictionary, reaction_dmg: float) -> float:
	## The reacting blow's multiplier: the rule's bonus over 1, grown by the source's reaction_dmg.
	return 1.0 + (float(reaction.get("mult", 1.0)) - 1.0) * maxf(0.0, 1.0 + reaction_dmg)

static func apply(holder: Enemy, damage: Combat.Damage, reaction: Dictionary) -> Array[Enemy]:
	## Sets the reaction off on `holder`: reshapes this blow in place (one packet per target,
	## as strike makes them), consumes statuses and splashes the other enemies it reaches.
	## Returns the enemies the splash hit, each once.
	var base: float = damage.amount
	var base_poise: float = damage.poise
	damage.reaction = String(reaction.get("id", ""))
	damage.amount *= bonus_mult(reaction, damage.reaction_dmg)
	damage.poise *= float(reaction.get("poise_mult", 1.0))
	if reaction.has("apply"):
		damage.status = {}
	holder.statuses.cleanse(reaction.get("consume", []))
	var targets: Array[Enemy] = splash_targets(holder, reaction)
	var from: Vector3 = holder.global_position
	for other: Enemy in targets:
		_splash(other, damage, reaction, base, base_poise, from)
		if int(reaction.get("chain", 0)) > 0:
			from = other.global_position
	_show(holder, reaction, targets)
	return targets

static func apply_status(holder: Enemy, reaction: Dictionary, power: float) -> String:
	## The reaction's own status on the target that reacted, in place of the blow's roll: it
	## always lands (resistance only shortens it). Returns the status that started.
	var started: String = _give(holder, reaction.get("apply", {}), power)
	if started == "" and reaction.has("fallback"):
		started = _give(holder, reaction["fallback"], power)
	return started

static func splash_targets(holder: Enemy, reaction: Dictionary) -> Array[Enemy]:
	## Living enemies besides `holder` the splash reaches: everyone within "radius" carrying one of
	## "spread_needs" (any when empty), or a nearest-first "chain" of hops each within radius.
	var radius: float = float(reaction.get("radius", 0.0))
	var picked: Array[Enemy] = []
	if radius <= 0.0:
		return picked
	var needs: Array = reaction.get("spread_needs", [])
	var hops: int = int(reaction.get("chain", 0))
	if hops <= 0:
		for other: Enemy in nearby(holder, holder.global_position, radius):
			if _carries(other, needs):
				picked.append(other)
		return picked
	var from: Vector3 = holder.global_position
	for _hop: int in range(hops):
		var best: Enemy = null
		for other: Enemy in nearby(holder, from, radius):
			if picked.has(other) or not _carries(other, needs):
				continue
			if best == null or from.distance_to(other.global_position) < from.distance_to(best.global_position):
				best = other
		if best == null:
			break
		picked.append(best)
		from = best.global_position
	return picked

static func nearby(holder: Enemy, center: Vector3, radius: float) -> Array[Enemy]:
	## Living enemies other than `holder` whose hurtboxes reach within radius of center.
	var found: Array[Enemy] = []
	for entity: Node in Combat.entities_in(holder, center + Vector3.UP * 0.8, radius, Combat.LAYER_HURT_ENEMY):
		var enemy: Enemy = entity as Enemy
		if enemy != null and enemy != holder and not enemy.is_dead():
			found.append(enemy)
	return found

static func _carries(enemy: Enemy, needs: Array) -> bool:
	if needs.is_empty():
		return true
	for id: Variant in needs:
		if enemy.statuses.has(String(id)):
			return true
	return false

static func _give(holder: Enemy, rule: Dictionary, power: float) -> String:
	if rule.is_empty():
		return ""
	return holder.apply_status(String(rule.get("status", "")), int(rule.get("stacks", 1)), power)

static func _splash(other: Enemy, damage: Combat.Damage, reaction: Dictionary, base: float, base_poise: float, from: Vector3) -> void:
	## One splash, spread or chain hit: a share of the original blow in its element, from its source.
	if other.invulnerable:
		return
	var share: float = float(reaction.get("splash", 0.0))
	if share > 0.0:
		var hit: Combat.Damage = Combat.Damage.new()
		hit.amount = base * share * maxf(0.0, 1.0 + damage.reaction_dmg)
		hit.poise = base_poise * share
		hit.knockback = float(reaction.get("knockback", 1.0))
		hit.source = damage.source
		hit.attack = damage.attack
		hit.element = damage.element
		hit.status_power = damage.status_power
		hit.armor_pen = damage.armor_pen
		hit.hitstop = 0.03
		hit.reaction = damage.reaction
		hit.reaction_splash = true
		var away: Vector3 = other.global_position - from
		away.y = 0.0
		hit.direction = away.normalized() if away.length() > 0.05 else damage.direction
		hit.position = other.global_position + Vector3.UP
		other.take_damage(hit)
	if not other.is_dead():
		_give(other, reaction.get("splash_status", {}), damage.status_power)

static func _show(holder: Enemy, reaction: Dictionary, targets: Array[Enemy]) -> void:
	## "Điện Giật!" over the target, a burst in the reaction colour and the rule's own effect.
	var parent: Node = holder.get_parent()
	var color: Color = Color(String(reaction.get("color", "ffffff")))
	var height: float = float(holder.data.get("height", 1.8))
	var center: Vector3 = holder.global_position
	Vfx.label(parent, center + Vector3.UP * (height + 0.3), String(reaction.get("name", "")) + "!", color)
	Vfx.burst(parent, center + Vector3.UP * height * 0.6, color, 26, 7.0, 0.11, 0.45)
	var radius: float = float(reaction.get("radius", 0.0))
	if radius > 0.0 and int(reaction.get("chain", 0)) <= 0:
		Vfx.ring(parent, center + Vector3.UP * 0.2, radius, color, 0.45, 0.2)
	match String(reaction.get("vfx", "")):
		"bolt":
			var from: Vector3 = center + Vector3.UP * height * 0.6
			for other: Enemy in targets:
				var to: Vector3 = other.global_position + Vector3.UP * float(other.data.get("height", 1.8)) * 0.6
				Vfx.bolt(parent, from, to, color)
				if int(reaction.get("chain", 0)) > 0:
					from = to
		"flames":
			Vfx.flames(parent, center, maxf(radius, 1.0) * 0.55, 0.7, 36)
			Vfx.tornado(parent, center, maxf(radius, 1.0) * 0.35, 0.7, color)
		"shards":
			Vfx.shards(parent, center, color, 9, float(holder.data.get("radius", 0.5)) + 0.6, height * 0.8, 0.6)
		"steam":
			Vfx.burst(parent, center + Vector3.UP * height * 0.5, color, 34, 4.0, 0.22, 0.8)
