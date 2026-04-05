extends Node3D

@onready var load_pos: Marker3D = $LoadPos
@onready var active_marker: MeshInstance3D = $ActiveMarker
@onready var area_3d: Area3D = $Area3D
@onready var load_button: TouchScreenButton = $CanvasLayer/LoadButtons/LoadTouchScreenButton
@onready var unload_button: TouchScreenButton = $CanvasLayer/LoadButtons/UnloadTouchScreenButton

var currentActiveCargo: RigidBody3D = null
var current_unload_area: Node3D = null

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("CARGO"):
		replace_current_active_cargo(body)
	
		
func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("CARGO"):
		clear_currentActiveCargo()
		

func replace_current_active_cargo(body: Node3D):
		# replace previus activeCargo if any
		if currentActiveCargo:
			clear_currentActiveCargo()			
		set_current_active_cargo(body)


func set_current_active_cargo(cargo: RigidBody3D):
	active_marker.global_position = cargo.global_position
	active_marker.visible = true
	load_button.visible = true
	currentActiveCargo = cargo
		
		
func clear_currentActiveCargo():
	active_marker.visible = false
	load_button.visible = false
	currentActiveCargo = null


func find_all_cargo_in_area(exlude: Node3D):
	var bodies = area_3d.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("CARGO") and body != exlude:
			replace_current_active_cargo(body)
			
			
func _on_load_button_pressed() -> void:
	if currentActiveCargo:
		currentActiveCargo.freeze = true
		currentActiveCargo.global_position = load_pos.global_position
		currentActiveCargo.freeze = false
		
	find_all_cargo_in_area(currentActiveCargo)
	active_marker.visible = false
	load_button.visible = false


func _on_unload_button_pressed() -> void:
	var unload_pos: Vector3 = global_position
	if current_unload_area:
		unload_pos = current_unload_area.global_position
		
	var bodies = area_3d.get_overlapping_bodies()
	
	for body in bodies:
		if body is RigidBody3D and body.is_in_group("CARGO"):
			# 1. Stop the physics simulation for a split second
			body.freeze = true
			
			# 2. Reset velocities so it doesn't "carry" its old speed to the new spot
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
			
			# 3. Increment the stack height
			unload_pos += Vector3(0, 1.1, 0) 
			
			# 4. Teleport using the PhysicsServer (The most reliable way)
			PhysicsServer3D.body_set_state(
				body.get_rid(),
				PhysicsServer3D.BODY_STATE_TRANSFORM,
				Transform3D(Basis(), unload_pos)
			)
			
			# 5. Turn physics back on
			body.freeze = false
			
			
func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("UNLOADING_AREA"):
		current_unload_area = area
		unload_button.visible = true


func _on_area_3d_area_exited(area: Area3D) -> void:
	if area.is_in_group("UNLOADING_AREA"):
		current_unload_area = null
		unload_button.visible = false
