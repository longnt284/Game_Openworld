class_name QuestManager
extends Node
## Sequential-objective quests driven by string events ("talk:ba_luc",
## "camp_clear:rescue", "interact:shrine_village", "flag:chimes_solved"…). check() also
## answers the "if" conditions of entities, dialogue choices and barks.
## Rewards are granted exactly once per save (guarded by a reward:<id> flag).

signal quest_started(id: String)
signal quest_updated(id: String)
signal quest_completed(id: String)

## Interactables are used once and leave one of these flags (see Interactable.flag_key()).
const ONE_TIME_PREFIXES: PackedStringArray = ["read:", "opened:", "echo_seen:", "memory:", "lit:", "used:"]

var state: GameState
var rewarder: Callable
## Clock and sky for "time:" and "weather:" conditions (wired by main). Without one it is a
## clear day, so a standalone manager (tests, tools) still answers.
var weather: WeatherDirector

func setup(game_state: GameState, reward_callback: Callable) -> void:
	state = game_state
	rewarder = reward_callback

func definition(id: String) -> Dictionary:
	return ContentDB.quest(id)

func is_started(id: String) -> bool:
	return state.quests.has(id)

func is_active(id: String) -> bool:
	return state.quests.has(id) and not bool(state.quests[id].get("done", false))

func is_done(id: String) -> bool:
	return state.quests.has(id) and bool(state.quests[id].get("done", false))

func stage(id: String) -> int:
	return int(state.quests[id].get("stage", 0)) if state.quests.has(id) else -1

func start(id: String) -> bool:
	if is_started(id) or definition(id).is_empty():
		return false
	state.quests[id] = {"stage": 0, "progress": 0, "done": false}
	if state.tracked_quest == "" or not is_active(state.tracked_quest) or definition(id).get("kind", "") == "main":
		state.tracked_quest = id
	emit_signal("quest_started", id)
	refresh()
	return true

func current_objective(id: String) -> Dictionary:
	if not is_active(id):
		return {}
	var objectives: Array = definition(id).get("objectives", [])
	var index: int = stage(id)
	return objectives[index] if index >= 0 and index < objectives.size() else {}

func progress(id: String) -> int:
	return int(state.quests[id].get("progress", 0)) if state.quests.has(id) else 0

func notify(event: String) -> void:
	for id: String in state.quests.keys():
		if not is_active(id):
			continue
		var objective: Dictionary = current_objective(id)
		if objective.get("event", "") != event:
			continue
		state.quests[id]["progress"] = progress(id) + 1
		if progress(id) >= int(objective.get("count", 1)):
			_advance(id)
		else:
			emit_signal("quest_updated", id)
	refresh()

func refresh() -> void:
	## Re-evaluates inventory ("have"), flag and world-fact objectives after any state change.
	var changed: bool = true
	var guard: int = 0
	while changed and guard < 8:
		changed = false
		guard += 1
		for id: String in state.quests.keys():
			if not is_active(id):
				continue
			var objective: Dictionary = current_objective(id)
			if objective.has("have"):
				var count: int = int(objective.get("count", 1))
				var owned: int = state.coins if objective["have"] == "coins" else state.count(objective["have"])
				if owned >= count:
					_advance(id)
					changed = true
				elif int(state.quests[id].get("progress", 0)) != owned:
					state.quests[id]["progress"] = owned
					emit_signal("quest_updated", id)
			elif String(objective.get("event", "")).begins_with("flag:") and state.has_flag(String(objective["event"]).substr(5)):
				_advance(id)
				changed = true
			else:
				var done: int = _world_progress(String(objective.get("event", "")))
				if done >= int(objective.get("count", 1)):
					_advance(id)
					changed = true
				elif done > progress(id):
					state.quests[id]["progress"] = done
					emit_signal("quest_updated", id)

func wants(event: String) -> bool:
	## True when some active quest is currently waiting for this event.
	for id: String in state.quests.keys():
		if is_active(id) and String(current_objective(id).get("event", "")) == event:
			return true
	return false

func _world_progress(event: String) -> int:
	## One-time world facts (cleared camps, heard echoes, read diaries, opened chests, slain bosses)
	## can happen before a quest asks for them. Counting them from GameState keeps the quest from
	## locking when the player explores ahead. Returns -1 for events that are not world facts.
	var parts: PackedStringArray = event.split(":")
	match parts[0]:
		"camp_clear":
			return 1 if state.has_flag(event) else 0
		"echo":
			var heard: int = 0
			for key: String in state.flags:
				if key.begins_with("echo_seen:echo_"):
					heard += 1
			return heard
		"interact":
			for prefix: String in ONE_TIME_PREFIXES:
				if state.has_flag(prefix + parts[1]):
					return 1
			return 0
		"kill":
			for entry: Dictionary in ContentDB.get_data("entities").get("entities", []):
				if String(entry.get("enemy", "")) == parts[1] and state.has_flag("dead:" + String(entry["id"])):
					return 1
			return 0
	return -1

func _advance(id: String) -> void:
	state.quests[id]["stage"] = stage(id) + 1
	state.quests[id]["progress"] = 0
	if stage(id) >= (definition(id).get("objectives", []) as Array).size():
		_complete(id)
	else:
		emit_signal("quest_updated", id)

func _complete(id: String) -> void:
	state.quests[id]["done"] = true
	var data: Dictionary = definition(id)
	if not state.has_flag("reward:" + id):
		state.set_flag("reward:" + id)
		if rewarder.is_valid():
			rewarder.call(data.get("rewards", {}), String(data.get("title", id)))
	emit_signal("quest_completed", id)
	for next: String in data.get("next", []):
		start(next)
	if state.tracked_quest == id:
		state.tracked_quest = _next_tracked()

func _next_tracked() -> String:
	var best: String = ""
	var best_order: int = 999
	for id: String in state.quests.keys():
		if is_active(id) and int(definition(id).get("order", 50)) < best_order:
			best_order = int(definition(id).get("order", 50))
			best = id
	return best

func marker(id: String) -> Variant:
	var objective: Dictionary = current_objective(id)
	if objective.is_empty():
		return null
	if objective.has("markers"):
		var markers: Array = objective["markers"]
		var index: int = clampi(progress(id), 0, markers.size() - 1)
		if String(objective.get("event", "")) == "echo":
			for candidate: int in range(markers.size()):
				if not state.has_flag("echo_seen:echo_%d" % (candidate + 1)):
					index = candidate
					break
		return Vector2(float(markers[index][0]), float(markers[index][1]))
	if objective.has("marker"):
		return Vector2(float(objective["marker"][0]), float(objective["marker"][1]))
	return null

func objective_text(id: String) -> String:
	var objective: Dictionary = current_objective(id)
	if objective.is_empty():
		return ""
	var text: String = String(objective.get("text", ""))
	var count: int = int(objective.get("count", 1))
	if count > 1:
		text += " (%d/%d)" % [mini(progress(id), count), count]
	return text

func check(conditions: Variant) -> bool:
	if conditions == null:
		return true
	for raw: Variant in conditions:
		var condition: String = String(raw)
		var negate: bool = condition.begins_with("!")
		if negate:
			condition = condition.substr(1)
		var result: bool = _check_one(condition)
		if result == negate:
			return false
	return true

func _check_one(condition: String) -> bool:
	var parts: PackedStringArray = condition.split(":")
	match parts[0]:
		"flag":
			return state.has_flag(condition.substr(5))
		"quest_active":
			return is_active(parts[1])
		"quest_done":
			return is_done(parts[1])
		"quest_started":
			return is_started(parts[1])
		"stage":
			return is_active(parts[1]) and stage(parts[1]) == int(parts[2])
		"has":
			var amount: int = int(parts[2]) if parts.size() > 2 else 1
			return (state.coins if parts[1] == "coins" else state.count(parts[1])) >= amount
		"dead":
			return state.has_flag("dead:" + parts[1])
		"camp_clear":
			return state.has_flag("camp_clear:" + parts[1])
		"skill":
			return state.skill_level(parts[1]) > 0
		"time":
			# night, day (dawn to dusk), dawn or dusk.
			return weather.is_time(parts[1]) if weather else parts[1] == "day"
		"weather":
			if not WeatherDirector.data().get("weathers", {}).has(parts[1]):
				push_warning("Unknown weather in condition " + condition)
			return (weather.weather_id() if weather else WeatherDirector.FALLBACK) == parts[1]
	push_warning("Unknown condition " + condition)
	return false
