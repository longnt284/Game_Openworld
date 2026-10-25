class_name EnemyFactory
extends RefCounted
## Picks the script of an enemy from its data "class" (data/enemies.json). The one place
## enemy classes are registered: the world spawner, the Endless Trial and the tests all
## build their enemies here. No "class" means the shared Enemy brain.

const CLASSES: Dictionary = {
	"boar": preload("res://scripts/enemies/boar.gd"),
	"guardian": preload("res://scripts/enemies/guardian.gd"),
	"archer": preload("res://scripts/enemies/archer.gd"),
	"shield_guard": preload("res://scripts/enemies/shield_guard.gd"),
	"mage": preload("res://scripts/enemies/mage.gd"),
	"wolf": preload("res://scripts/enemies/wolf.gd"),
	"wraith": preload("res://scripts/enemies/wraith.gd"),
	"golem": preload("res://scripts/enemies/golem.gd"),
}

static func script_for(data: Dictionary) -> GDScript:
	var key: String = String(data.get("class", ""))
	if key != "" and not CLASSES.has(key):
		push_warning("Unknown enemy class '%s', using Enemy" % key)
	return CLASSES.get(key, Enemy) as GDScript

static func create(data: Dictionary) -> Enemy:
	## A bare node of the right class; the caller names it, adds it and calls setup().
	return script_for(data).new() as Enemy
