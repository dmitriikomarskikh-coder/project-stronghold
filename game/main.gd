extends Node2D

const GameCamera := preload("res://game/input/camera_controller.gd")
const PlayerInput := preload("res://game/input/player_input.gd")
const TileMapRenderer := preload("res://game/render/tile_map_renderer.gd")
const TickRunner := preload("res://sim/tick.gd")

@onready var world: Node2D = $World
@onready var camera: Camera2D = $Camera2D
@onready var top_bar: Label = $CanvasLayer/Hud/TopBar
@onready var debug_label: Label = $CanvasLayer/Hud/Debug

var sim
var renderer
var camera_controller
var player_input

func _ready() -> void:
	sim = TickRunner.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)

	renderer = TileMapRenderer.new()
	world.add_child(renderer)
	renderer.draw_state(sim.map_state, sim.buildings, sim.units, sim.balance)

	camera_controller = GameCamera.new()
	camera_controller.setup(camera, Rect2(Vector2.ZERO, Vector2(sim.map_state.size_x, sim.map_state.size_y) * renderer.tile_size))
	player_input = PlayerInput.new()
	player_input.setup(camera, renderer, sim)
	renderer.set_selected_units(player_input.selected_units)

func _process(delta: float) -> void:
	camera_controller.update(delta)
	sim.advance_render_time(delta)
	top_bar.text = "Wood %d | Stone %d | Food %d (%+d) | Units %d/%d" % [
		sim.player_wood[0],
		sim.player_stone[0],
		sim.player_food[0],
		sim.food_trend_10s(0),
		sim.live_units_for_player(0),
		sim.unit_limit
	]
	debug_label.text = "Tick %d | queued commands %d | full visibility" % [sim.tick, sim.command_log.size()]
	if not player_input.selected_units.is_empty():
		var selected_id: int = player_input.selected_units[0]
		debug_label.text += " | selected %d | order %s | carry %s:%d" % [
			player_input.selected_units.size(),
			sim.units.order_type[selected_id],
			sim.units.carry_type[selected_id],
			sim.units.carry_amount[selected_id],
		]
	renderer.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	camera_controller.handle_input(event)
	player_input.handle_input(event)
