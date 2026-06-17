extends Node2D

const GameCamera := preload("res://game/input/camera_controller.gd")
const PlayerInput := preload("res://game/input/player_input.gd")
const TileMapRenderer := preload("res://game/render/tile_map_renderer.gd")
const MiniMap := preload("res://game/ui/minimap.gd")
const AudioFeedback := preload("res://game/audio/audio_feedback.gd")
const TickRunner := preload("res://sim/tick.gd")

@onready var world: Node2D = $World
@onready var camera: Camera2D = $Camera2D
@onready var top_bar: Label = $CanvasLayer/Hud/TopBar
@onready var debug_label: Label = $CanvasLayer/Hud/Debug
@onready var warning_label: Label = $CanvasLayer/Hud/Warning
@onready var result_label: Label = $CanvasLayer/Hud/Result
@onready var minimap_host: Control = $CanvasLayer/Hud/Minimap
@onready var menu: Control = $CanvasLayer/Menu
@onready var new_game_button: Button = $CanvasLayer/Menu/NewGame
@onready var exit_button: Button = $CanvasLayer/Menu/Exit

var sim
var renderer
var minimap
var camera_controller
var player_input
var audio_feedback
var _last_attack_feedback_tick := -1000000

func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	_start_new_match()
	menu.visible = true

func _start_new_match() -> void:
	sim = TickRunner.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	sim.enable_ai("res://config/ai_normal.json")

	if renderer != null:
		renderer.queue_free()
	if audio_feedback != null:
		audio_feedback.queue_free()
	renderer = TileMapRenderer.new()
	world.add_child(renderer)
	renderer.draw_state(sim.map_state, sim.buildings, sim.units, sim.balance)
	renderer.set_platoons(sim.platoons)
	renderer.set_fog(sim.fog, 0)

	camera_controller = GameCamera.new()
	camera_controller.setup(camera, Rect2(Vector2.ZERO, Vector2(sim.map_state.size_x, sim.map_state.size_y) * renderer.tile_size))
	audio_feedback = AudioFeedback.new()
	add_child(audio_feedback)
	player_input = PlayerInput.new()
	player_input.setup(camera, renderer, sim, audio_feedback)
	renderer.set_selected_units(player_input.selected_units)
	if minimap != null:
		minimap.queue_free()
	minimap = MiniMap.new()
	minimap_host.add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minimap.setup(sim, camera, player_input, 0)
	result_label.visible = false

func _process(delta: float) -> void:
	if sim == null:
		return
	camera_controller.update(delta)
	if menu.visible and not result_label.visible:
		return
	sim.advance_render_time(delta)
	top_bar.text = "Wood %d | Stone %d | Food %d (%+d) | Units %d/%d" % [
		sim.player_wood[0],
		sim.player_stone[0],
		sim.player_food[0],
		sim.food_trend_10s(0),
		sim.live_units_for_player(0),
		sim.unit_limit
	]
	renderer.set_fog(sim.fog, 0)
	if minimap != null:
		minimap.queue_redraw()
	debug_label.text = "Tick %d | queued commands %d | fog enabled" % [sim.tick, sim.command_log.size()]
	if not player_input.selected_units.is_empty():
		var selected_id: int = player_input.selected_units[0]
		debug_label.text += " | selected %d | order %s | carry %s:%d" % [
			player_input.selected_units.size(),
			sim.units.order_type[selected_id],
			sim.units.carry_type[selected_id],
			sim.units.carry_amount[selected_id],
		]
		var platoon_id: int = sim.units.platoon_id[selected_id]
		if platoon_id >= 0 and platoon_id < sim.platoons.alive.size() and sim.platoons.alive[platoon_id] and sim.platoons.broken[platoon_id]:
			debug_label.text += " | formation broken"
	elif player_input.selected_building_id >= 0:
		var building_id: int = player_input.selected_building_id
		if building_id < sim.buildings.alive.size() and sim.buildings.alive[building_id]:
			debug_label.text += " | selected %s | queue %s+%d" % [
				sim.buildings.building_type[building_id],
				sim.buildings.production_type[building_id],
				sim.buildings.production_queue[building_id].size(),
			]
	if player_input.build_mode_enabled():
		debug_label.text += " | build %s" % player_input.pending_building_type()
	_update_warning_label()
	if sim.winner_player >= 0 or sim.winner_player == -2:
		_show_result()
	renderer.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if sim == null or menu.visible:
		return
	camera_controller.handle_input(event)
	player_input.handle_input(event)

func _show_result() -> void:
	if result_label.visible:
		return
	var outcome := "Draw"
	if sim.winner_player == 0:
		outcome = "Victory"
	elif sim.winner_player == 1:
		outcome = "Defeat"
	result_label.text = "%s | Time %02d:%02d" % [outcome, int(sim.tick / 600), int((sim.tick / 10) % 60)]
	result_label.visible = true
	menu.visible = true

func _update_warning_label() -> void:
	var messages: Array[String] = []
	if sim.player_food[0] < 10 and sim.food_trend_10s(0) <= 0:
		messages.append("Low food: build a farm")
	if sim.tick - sim.last_attack_tick[0] <= 100:
		messages.append("Under attack")
		if audio_feedback != null and sim.last_attack_tick[0] != _last_attack_feedback_tick:
			_last_attack_feedback_tick = sim.last_attack_tick[0]
			audio_feedback.play_under_attack()
	warning_label.text = " | ".join(messages)
	warning_label.visible = not messages.is_empty()

func _on_new_game_pressed() -> void:
	menu.visible = false
	_start_new_match()

func _on_exit_pressed() -> void:
	get_tree().quit()
