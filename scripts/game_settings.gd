class_name GameSettings
extends Resource

@export var world_seed: int = 284
@export_range(16, 64, 1) var chunk_size: int = 32
@export_range(8, 32, 1) var subdivisions: int = 16
@export_range(1, 4, 1) var view_radius: int = 2
@export_range(0, 24, 1) var trees_per_chunk: int = 10
@export var terrain_amplitude: float = 6.0
@export var terrain_frequency: float = 0.012
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var acceleration: float = 22.0
@export var jump_speed: float = 7.0
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.0025
@export var day_length_seconds: float = 480.0
@export var near_tree_distance: float = 64.0

func chunk_capacity() -> int:
	return (view_radius * 2 + 1) ** 2
