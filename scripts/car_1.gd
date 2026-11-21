class_name Car
extends VehicleBody3D

## Emitted when the player's car starts sliding sideways in a drift.
signal drift_started
## Emitted when a drift ends. boost is 0..1 (0 = drift was too short for a boost).
signal drift_ended(duration: float, boost: float)

const CAR_BODY_MATERIAL: ShaderMaterial = preload("res://materials/car_body.tres")
## How strongly the steering corrects the difference between the intended and
## the actual turn rate.
const STEER_FEEDBACK := 2.0

@export var color: Color = Color.WHITE
@export var max_speed: float = 40
@export var max_brake_force: float = 20.0
## Arcade handling used when a player drives this car. NPCs ignore it.
## Without a profile the player gets the CarHandling defaults.
@export var handling: CarHandling

@onready var body: Node3D = $Body
@onready var brake_indicator: Node3D = $brake_indicator
@onready var wheel_front_left: VehicleWheel3D = $VehicleWheel3DFrontLeft
@onready var wheel_front_right: VehicleWheel3D = $VehicleWheel3DFrontRight
@onready var wheel_back_right: VehicleWheel3D = $VehicleWheel3DBackRight
@onready var wheel_back_left: VehicleWheel3D = $VehicleWheel3DBackLeft

var engine_force_to_apply: float = 0
# Internal state
var engine_force_modifier: float = 1.0
# current speed
var current_speed: float = 0

# --- Driver input (set every physics frame by a controller) ------------------
## True when a controller drives the car through the inputs below. Turns on the
## handling assists. NPC controllers leave it off and steer the car directly.
var assists_enabled: bool = false
## -1..1, positive = right.
var steer_input: float = 0.0
var brake_input: bool = false

# --- Handling state -----------------------------------------------------------
var is_drifting: bool = false
## 0..1 blend between normal grip driving and a full slide.
var drift_amount: float = 0.0
var drift_time: float = 0.0

var _steer: float = 0.0
var _wheelbase: float = 2.6
var _front_axle_z: float = -1.3
var _front_grip: float = 1.0
var _rear_grip: float = 1.0
var _drift_dir: float = 0.0
var _drift_target_speed: float = 0.0
var _drift_exit_timer: float = 0.0
var _boost_time_left: float = 0.0
var _boost_strength: float = 0.0
var _air_time: float = 0.0
var _stuck_time: float = 0.0
var _initialized: bool = false


func _physics_process(delta: float) -> void:
	current_speed = linear_velocity.length()
	if assists_enabled:
		_drive_with_assists(delta)
		return

	if current_speed < max_speed:
		engine_force = engine_force_to_apply * engine_force_modifier
	else:
		engine_force = 0.0


# =============================================================================
# Arcade handling (player only)
# =============================================================================

func _init_handling() -> void:
	_initialized = true
	if handling == null:
		handling = CarHandling.new()
	_front_axle_z = wheel_front_left.position.z
	_wheelbase = maxf(absf(wheel_front_left.position.z - wheel_back_left.position.z), 0.5)
	_front_grip = wheel_front_left.wheel_friction_slip
	_rear_grip = wheel_back_left.wheel_friction_slip


func _drive_with_assists(delta: float) -> void:
	if not _initialized:
		_init_handling()
	var h := handling

	var basis_now := global_transform.basis
	var up := basis_now.y
	var fwd := -basis_now.z
	var right := basis_now.x
	var forward_speed := linear_velocity.dot(fwd)
	var side_speed := linear_velocity.dot(right)
	var speed := absf(forward_speed)
	var yaw_rate := angular_velocity.dot(up) # positive = turning left
	# Slip angle: angle from the nose to the direction of travel, positive when
	# the car is moving to the left of where it points.
	var slip := atan2(-side_speed, maxf(forward_speed, 0.5)) if speed > 1.0 else 0.0

	var grounded := _wheels_in_contact() >= 2
	_air_time = 0.0 if grounded else _air_time + delta

	# Smooth the stick. Coming back to center is faster than turning in.
	var returning := absf(steer_input) < absf(_steer) or steer_input * _steer < 0.0
	var rate := h.steer_return if returning else h.steer_response
	_steer = lerpf(_steer, steer_input, 1.0 - exp(-rate * delta))

	_update_drift_state(delta, speed, forward_speed, grounded)

	# --- Turning --------------------------------------------------------------
	var max_angle := deg_to_rad(h.max_steer_angle_deg)
	# Intended turn rate for normal driving (positive = left). Low speed: limited
	# by the wheel angle. High speed: limited by tire grip.
	var steer_speed := maxf(speed, 0.5)
	var max_turn_rate := minf(steer_speed * tan(max_angle) / _wheelbase, h.max_lateral_accel / steer_speed)
	var grip_turn_rate := -_steer * max_turn_rate
	# Wheel angle for that turn rate (bicycle model), plus a correction for
	# the turn rate the car is actually doing. The correction is what removes
	# under- and oversteer: the tires do the work, not a fake torque.
	var corrected_rate := grip_turn_rate + STEER_FEEDBACK * (grip_turn_rate - yaw_rate) * clampf(speed / 8.0, 0.0, 1.0)
	var grip_wheel_angle := clampf(atan(_wheelbase * corrected_rate / steer_speed), -max_angle, max_angle)

	var target_turn_rate := grip_turn_rate
	var wheel_angle := grip_wheel_angle
	var d := drift_amount

	if forward_speed < -1.0:
		# Reversing: plain steering, no assists.
		wheel_angle = -_steer * max_angle
		target_turn_rate = yaw_rate
	elif d > 0.0:
		target_turn_rate = lerpf(grip_turn_rate, _drift_turn_rate(slip, current_speed), d)
		# Point the front wheels where the front axle is travelling. That is the
		# counter-steer a real driver would do and keeps the front tires from
		# fighting the slide.
		var front_velocity := linear_velocity + angular_velocity.cross(basis_now * Vector3(0, 0, _front_axle_z))
		var align_angle := atan2(-front_velocity.dot(right), maxf(front_velocity.dot(fwd), 0.5))
		wheel_angle = lerpf(grip_wheel_angle, clampf(align_angle, -max_angle, max_angle), d)

	steering = wheel_angle
	_set_wheel_grip(lerpf(1.0, h.drift_grip_factor, d))

	if grounded and forward_speed > -1.0:
		var inertia := _inertia_about(up)
		var assist_scale := clampf(speed / 6.0, 0.0, 1.0)
		var gain := lerpf(h.yaw_assist, maxf(h.yaw_assist, 10.0), d)
		var yaw_accel := clampf((target_turn_rate - yaw_rate) * gain, -h.yaw_assist_max, h.yaw_assist_max)
		# Stability: pull the nose back toward the direction of travel when the
		# car slides more than it should in normal driving.
		var max_slip := deg_to_rad(h.max_grip_slip_deg)
		if absf(slip) > max_slip and d < 0.5:
			var excess := slip - signf(slip) * max_slip
			yaw_accel += excess * h.slip_correction * 4.0 * (1.0 - d)
			apply_central_force(-right * side_speed * mass * h.slip_correction * 0.5 * (1.0 - d) * minf(absf(excess) * 4.0, 1.0))
		apply_torque(up * yaw_accel * inertia * assist_scale)

		if d > 0.0:
			_apply_drift_forces(d, up, delta)

	# --- Engine & brakes ----------------------------------------------------------
	var top_speed := max_speed
	if _boost_time_left > 0.0:
		_boost_time_left -= delta
		top_speed *= h.boost_top_speed_factor
		if grounded and forward_speed > 0.0 and speed < top_speed:
			apply_central_force(fwd * mass * h.boost_accel * _boost_strength)

	var force := engine_force_to_apply * engine_force_modifier
	# Corner slowdown: hard stick at speed scrubs a little speed (engine stays on).
	var hard_steer := clampf((absf(_steer) - 0.5) * 2.0, 0.0, 1.0) * (1.0 - d)
	if hard_steer > 0.0 and h.steer_slowdown > 0.0 and grounded and speed > max_speed * 0.4:
		apply_central_force(-fwd * mass * h.steer_slowdown * hard_steer)
	if force > 0.0:
		# Fade the engine out near top speed instead of switching it off, which
		# made the rear tires grip and let go every frame.
		force *= clampf((top_speed - speed) / (top_speed * 0.08), 0.0, 1.0)
	force *= 1.0 - d

	if brake_input:
		engine_force = 0.0
		brake = max_brake_force
	else:
		engine_force = force
		brake = 0.0

	# --- Downforce, air control, flip recovery ------------------------------------
	if grounded and h.downforce > 0.0:
		apply_central_force(-up * h.downforce * speed * speed)

	if not grounded and _air_time > 0.1 and h.air_control > 0.0:
		_apply_air_control(up)

	if h.auto_flip:
		_check_flip(delta, up)


func _update_drift_state(delta: float, speed: float, forward_speed: float, grounded: bool) -> void:
	var h := handling
	if not h.drift_enabled:
		drift_amount = 0.0
		return

	var stick := absf(steer_input)
	if not is_drifting:
		var wants_drift := stick >= h.drift_entry_steer or (h.drift_on_brake and brake_input and stick > 0.3)
		if wants_drift and grounded and forward_speed > h.drift_min_speed:
			is_drifting = true
			drift_time = 0.0
			_drift_exit_timer = 0.0
			_drift_dir = -signf(steer_input) # turn direction, positive = left
			_drift_target_speed = current_speed
			drift_started.emit()
	else:
		drift_time += delta
		# Steering into the turn keeps the drift, letting go or steering the
		# other way ends it.
		var into_turn := -steer_input * _drift_dir
		if into_turn < 0.2:
			_drift_exit_timer += delta
		else:
			_drift_exit_timer = 0.0
		var too_slow := speed < h.drift_min_speed * 0.6
		if _drift_exit_timer >= h.drift_exit_delay or too_slow or _air_time > 0.6:
			_end_drift()

	var target := 1.0 if is_drifting else 0.0
	var duration := h.drift_engage_time if is_drifting else h.drift_release_time
	drift_amount = move_toward(drift_amount, target, delta / maxf(duration, 0.01))


func _end_drift() -> void:
	var h := handling
	is_drifting = false
	var boost := 0.0
	if drift_time >= h.boost_min_drift_time:
		boost = clampf(drift_time / maxf(h.boost_full_drift_time, 0.01), 0.0, 1.0)
		_boost_strength = boost
		_boost_time_left = h.boost_duration * lerpf(0.5, 1.0, boost)
	drift_ended.emit(drift_time, boost)


## Turn rate the nose should have while drifting: follow the path and rotate
## toward the target drift angle.
func _drift_turn_rate(slip: float, speed: float) -> float:
	var h := handling
	var into_turn := clampf(-_steer * _drift_dir, -1.0, 1.0)
	var t := (into_turn + 1.0) * 0.5
	var path_rate := _drift_path_rate(t, speed)
	var target_slip := -_drift_dir * deg_to_rad(lerpf(h.drift_angle_min_deg, h.drift_angle_max_deg, t))
	return path_rate - 4.0 * (target_slip - slip)


func _drift_path_rate(t: float, speed: float) -> float:
	var h := handling
	var rate := lerpf(h.drift_turn_rate_min, h.drift_turn_rate_max, t)
	rate = minf(rate, h.drift_max_lateral_accel / maxf(speed, 1.0))
	return _drift_dir * rate


## Bend the direction of travel along the drift line and hold the drift speed.
## The tires are mostly sliding, so these forces decide the line.
func _apply_drift_forces(d: float, up: Vector3, delta: float) -> void:
	var h := handling
	# Use the real travel speed: in a slide the speed along the nose is lower.
	var flat_velocity := linear_velocity - up * linear_velocity.dot(up)
	var speed := flat_velocity.length()
	if speed < 1.0:
		return
	var vel_dir := flat_velocity / speed
	var into_turn := clampf(-_steer * _drift_dir, -1.0, 1.0)
	var path_rate := _drift_path_rate((into_turn + 1.0) * 0.5, speed)
	var side_dir := up.cross(vel_dir).normalized() # left of travel
	apply_central_force(side_dir * mass * speed * path_rate * d)

	# Hold the drift speed (minus a slow loss) while sliding. Off the gas or on
	# the brake the car slows down faster. While gripping up again it only
	# makes up for tire scrub, so it never fights the drift boost.
	var speed_error := _drift_target_speed - speed
	if is_drifting:
		var loss := h.drift_speed_loss if engine_force_to_apply > 0.0 else h.drift_speed_loss * 4.0
		_drift_target_speed = maxf(_drift_target_speed - loss * delta, h.drift_min_speed * 0.6)
		speed_error = _drift_target_speed - speed
	else:
		speed_error = maxf(speed_error, 0.0)
	if brake_input:
		speed_error = minf(speed_error, -4.0)
	apply_central_force(vel_dir * mass * clampf(speed_error * 3.0, -8.0, 8.0) * d)


func _apply_air_control(up: Vector3) -> void:
	var h := handling
	var inertia := _inertia_about(global_transform.basis.z)
	# Level the car (keep heading) and damp roll/pitch tumbling.
	var righting := up.cross(Vector3.UP)
	var tumble := angular_velocity - Vector3.UP * angular_velocity.dot(Vector3.UP)
	apply_torque((righting * h.air_control - tumble * h.air_damping) * inertia)


func _check_flip(delta: float, up: Vector3) -> void:
	if up.y < 0.35 and current_speed < 3.0:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	if _stuck_time < 1.5:
		return
	_stuck_time = 0.0
	var heading := -global_transform.basis.z
	heading.y = 0.0
	if heading.length_squared() < 0.01:
		heading = Vector3.FORWARD
	var t := global_transform
	t.basis = Basis.looking_at(heading.normalized(), Vector3.UP)
	t.origin += Vector3.UP * 1.0
	global_transform = t
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _set_wheel_grip(factor: float) -> void:
	var front := _front_grip * lerpf(1.0, factor, 0.6)
	var rear := _rear_grip * factor
	wheel_front_left.wheel_friction_slip = front
	wheel_front_right.wheel_friction_slip = front
	wheel_back_left.wheel_friction_slip = rear
	wheel_back_right.wheel_friction_slip = rear


func _wheels_in_contact() -> int:
	var count := 0
	for wheel: VehicleWheel3D in [wheel_front_left, wheel_front_right, wheel_back_left, wheel_back_right]:
		if wheel.is_in_contact():
			count += 1
	return count


func _inertia_about(axis: Vector3) -> float:
	var inv := axis.dot(get_inverse_inertia_tensor() * axis)
	return 1.0 / inv if inv > 0.000001 else mass


# =============================================================================
# Shared helpers (player and NPC)
# =============================================================================

func apply_color_to_mesh(_color: Color) -> void:
	var body_mesh := get_first_mesh_instance(body)
	# Assign the shared material (same instance for all cars) and set per-instance color.
	# This avoids duplicating the material and allows GPU batching.
	body_mesh.set_surface_override_material(0, CAR_BODY_MATERIAL)
	body_mesh.set_instance_shader_parameter("car_color", _color)
	for child_mesh in body_mesh.get_children():
		if child_mesh is MeshInstance3D:
			child_mesh.set_surface_override_material(0, CAR_BODY_MATERIAL)
			child_mesh.set_instance_shader_parameter("car_color", _color)

func brake_car():
	engine_force = 0
	brake = max_brake_force


func show_brake_indicator():
	if not brake_indicator.visible:
		brake_indicator.visible = true


func hide_brake_indicator():
	if brake_indicator.visible:
		brake_indicator.visible = false


func get_first_mesh_instance(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var result = get_first_mesh_instance(child)
		if result:
			return result
	return null
