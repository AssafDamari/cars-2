extends Node3D

@onready var load_area: Area3D = $LoadArea
@onready var bed_area: Area3D = $BedArea
@onready var load_pos: Marker3D = $LoadPos

@onready var load_button: TouchScreenButton = $CanvasLayer/LoadButtons/LoadTouchScreenButton
@onready var unload_button: TouchScreenButton = $CanvasLayer/LoadButtons/UnloadTouchScreenButton

var nearby_cargo: Array[RigidBody3D] = []
var current_unload_area: Area3D = null

# --------------------------------------------------
# DETECTION: Nearby cargo
# --------------------------------------------------
func _on_load_area_body_entered(body):
	if body is RigidBody3D and body.is_in_group("CARGO"):
		if body not in nearby_cargo:
			nearby_cargo.append(body)
			update_ui()

func _on_load_area_body_exited(body):
	if body in nearby_cargo:
		nearby_cargo.erase(body)
		update_ui()

# --------------------------------------------------
# DETECTION: Unload area
# --------------------------------------------------
func _on_load_area_area_entered(area: Area3D):
	if area.is_in_group("UNLOADING_AREA"):
		current_unload_area = area
		update_ui()

func _on_load_area_area_exited(area: Area3D):
	if area == current_unload_area:
		current_unload_area = null
		update_ui()

# --------------------------------------------------
# FIND CLOSEST CARGO
# --------------------------------------------------
func get_closest_cargo():
	var closest: RigidBody3D = null
	var min_dist := INF
	
	for c in nearby_cargo:
		if not is_instance_valid(c):
			continue
		
		# ❌ Skip cargo already on truck
		if is_cargo_on_truck(c):
			continue
		
		var d = global_position.distance_to(c.global_position)
		if d < min_dist:
			min_dist = d
			closest = c
	
	return closest

func is_cargo_on_truck(cargo: RigidBody3D) -> bool:
	var bodies = bed_area.get_overlapping_bodies()
	return cargo in bodies
	
# --------------------------------------------------
# LOAD (PHYSICS ASSIST)
# --------------------------------------------------
func _on_load_button_pressed():
	var cargo = get_closest_cargo()
	if not cargo:
		return
	
	assist_load(cargo)
	update_ui()

func assist_load(cargo: RigidBody3D):
	var target_pos = load_pos.global_position
	var dir = target_pos - cargo.global_position
	
	var lift = Vector3.UP * 3.0
	var push = dir.normalized() * 6.0
	
	cargo.linear_velocity = Vector3.ZERO
	cargo.angular_velocity = Vector3.ZERO
	
	cargo.apply_impulse(push + lift)

# --------------------------------------------------
# UNLOAD
# --------------------------------------------------
func _on_unload_button_pressed():
	var bodies = bed_area.get_overlapping_bodies()
	
	for body in bodies:
		if body is RigidBody3D and body.is_in_group("CARGO"):
			var back_dir = -global_transform.basis.z
			body.apply_impulse(back_dir * 5.0 + Vector3.UP * 2.0)
	
	update_ui()

# --------------------------------------------------
# CHECK CARGO ON TRUCK
# --------------------------------------------------
func has_cargo_on_truck() -> bool:
	var bodies = bed_area.get_overlapping_bodies()
	
	for b in bodies:
		if b is RigidBody3D and b.is_in_group("CARGO"):
			return true
	
	return false

# --------------------------------------------------
# UI CONTROL
# --------------------------------------------------
func update_ui():
	# Clean invalid references
	nearby_cargo = nearby_cargo.filter(func(c): return is_instance_valid(c))
	
	# LOAD button: show if cargo nearby
	load_button.visible = nearby_cargo.size() > 0
	
	# UNLOAD button: only if cargo on truck AND in unload area
	unload_button.visible = has_cargo_on_truck() and current_unload_area != null

# --------------------------------------------------
# KEEP UI IN SYNC WITH PHYSICS
# --------------------------------------------------
func _physics_process(_delta):
	update_ui()
