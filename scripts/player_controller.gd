class_name PlayerController
extends Node3D
## Reads the touch controls and passes them to the car.
##
## All handling (steering feel, drift, stability, air control) lives in Car and
## is tuned per car type with a CarHandling profile. This script only turns the
## joystick, gear slider and brake button into car inputs.

@export var engine_force_fwd: float = 2000
@export var engine_force_reverse: float = 1000

@export_group("Steering Stick")
## Joystick travel around the center that is ignored.
@export_range(0.0, 0.5, 0.01) var steer_deadzone: float = 0.08
## Input response curve. Above 1 gives finer control near the center.
@export_range(1.0, 3.0, 0.05) var steer_curve: float = 1.25

@onready var vehicle: Car = get_parent() as Car
@onready var virtual_joystick: VirtualJoystick = $"Player controllsUI/VirtualJoystick"
@onready var debug_lable: Label = $"Player controllsUI/DebugLable"
@onready var gear_slider: GearSlider = $"Player controllsUI/GearSlider"


func _ready() -> void:
	# Read the controls before the car runs its physics step this frame.
	process_physics_priority = -1
	vehicle.assists_enabled = true
	GlobalSignals.show_debug_text.connect(show_debug_lable)

	# The FPS counter is a debug tool only. Drop it (and its per-frame Label
	# update) from exported release builds and keep it in editor/debug runs.
	if not OS.is_debug_build():
		var fps_label := get_node_or_null("Player controllsUI/TopToolbar/FpsLabel")
		if fps_label:
			fps_label.queue_free()


func _exit_tree() -> void:
	GlobalSignals.show_debug_text.disconnect(show_debug_lable)


func _physics_process(_delta: float) -> void:
	vehicle.engine_force_to_apply = get_engine_force()
	vehicle.steer_input = _get_steer_input()
	vehicle.brake_input = should_brake()

	if vehicle.brake_input:
		vehicle.show_brake_indicator()
	else:
		vehicle.hide_brake_indicator()


func _get_steer_input() -> float:
	# Read the action strengths directly instead of Input.get_vector(): the
	# ui_* actions have a 0.5 deadzone for UI navigation, which would throw
	# away most of the analog range of the virtual joystick.
	var raw := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var magnitude := absf(clampf(raw, -1.0, 1.0))
	if magnitude <= steer_deadzone:
		return 0.0
	magnitude = (magnitude - steer_deadzone) / maxf(1.0 - steer_deadzone, 0.001)
	return signf(raw) * pow(magnitude, steer_curve)


func get_engine_force() -> float:
	match gear_slider.current_gear:
		gear_slider.Gear.DRIVE:
			return engine_force_fwd
		gear_slider.Gear.REVERSE:
			return -engine_force_reverse
		_:
			return 0.0


func should_brake() -> bool:
	return Input.is_action_pressed("ui_accept")


func _on_button_pressed() -> void:
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	GlobalSceneManager.load_menu()


func show_debug_lable(debug_text) -> void:
	debug_lable.text = debug_text
