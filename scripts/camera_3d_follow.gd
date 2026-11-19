class_name CameraGimble extends Node3D

# Reference to the actual Camera3D node that is a child of this gimble.
@onready var camera_3d: Camera3D = $Camera3D 

# --- Exposed Variables (Editable in Godot Editor) ---
# Assign the NodePath to your target (e.g., the cat/player vehicle) in the editor.
@export var target_node_path: NodePath 
# The actual Node3D instance of the target.
var target: Node3D 

# How quickly the camera follows the target. Higher values mean faster following.
@export var follow_speed: float = 5.0
# The height of the camera above the target's origin point.
@export var vertical_offset: float = 12.0
# The distance the camera stays behind the target.
@export var horizontal_offset: float = 15.0
# The sideways offset applied when 'is_finish_mode' is true.
@export var finish_offset: float = 5.0
# debug mode
@export var debug_mode: bool = false
## How much the camera looks along the direction of travel instead of the
## car's nose (0 = nose, 1 = travel). Keeps the view steady in drifts.
@export_range(0.0, 1.0, 0.05) var velocity_follow: float = 0.6

# Flag to control the "finish mode" camera behavior.
var is_finish_mode: bool = false

func _ready() -> void:
	# Setting top_level = true makes this node's global transform independent of its parent.
	# This is essential for a camera controller that calculates its own world position.
	top_level = true 
	
	# Attempt to get the target Node3D instance from the provided NodePath.
	if target_node_path:
		var node = get_node_or_null(target_node_path)
		if node is Node3D:
			target = node
		else:
			printerr("CameraGimble: Target node at path '", target_node_path, "' is not a Node3D or was not found.")
	else:
		# Fallback: If no target_node_path is set, try to use this node's parent as the target.
		# This matches the implicit behavior of the original script.
		var parent_node = get_parent()
		if parent_node is Node3D:
			target = parent_node
			print("CameraGimble: 'target_node_path' not set. Defaulting to parent node '", target.name, "' as target.")
		else:
			printerr("CameraGimble: 'target_node_path' not set and parent is not a Node3D. Target remains unassigned.")

	# Optional: For an immediate snap to position on game start, you could call:
	# if is_instance_valid(target):
	#    global_position = _calculate_desired_camera_position()
	#    # Ensure the camera also looks at the target immediately.
	#    if is_instance_valid(camera_3d):
	#        camera_3d.look_at(target.global_transform.origin, Vector3.UP)


func _physics_process(delta: float) -> void:
	# If the target is not valid (e.g., not set or has been freed from the scene),
	# then do nothing to prevent errors.
	if not is_instance_valid(target):
		return

	# Calculate the ideal position where the camera gimble should be.
	var desired_cam_pos: Vector3 = _calculate_desired_camera_position()

	# Smoothly interpolate the camera gimble's current global position towards the desired position.
	# The 'follow_speed * delta' determines how quickly it catches up.
	global_position = global_position.lerp(desired_cam_pos, follow_speed * delta)
	
	# Make the actual Camera3D node (child of this gimble) look at the target's origin.
	# Using Vector3.UP as the 'up' vector for look_at helps maintain a stable horizon
	# and prevents unwanted camera roll.
	if is_instance_valid(camera_3d):
		camera_3d.look_at(target.global_transform.origin, Vector3.UP)

func _calculate_desired_camera_position() -> Vector3:
	# This helper function computes the desired world position for the camera gimble.

	# 1. Start with the target's current global position.
	var target_pos: Vector3 = target.global_transform.origin
	var calculated_pos: Vector3 = target_pos

	# 2. Apply vertical offset.
	# This raises the camera purely along the world's Y-axis from the target's position.
	# It's not affected by the target's rotation.
	calculated_pos.y += vertical_offset

	# 3. Calculate and apply horizontal offset (distance behind the target).
	# This offset depends only on the target's yaw (left/right rotation),
	# ignoring its pitch (up/down tilt) and roll (sideways tilt).
	
	# Assume the target model's "front" is along its local +Z axis.
	# target.global_transform.basis.z gives this local Z axis in world coordinates.
	var target_forward_world: Vector3 = target.global_transform.basis.z
	# While sliding, aim between the nose and the direction of travel so the
	# view does not swing around with the car's rotation.
	if target is RigidBody3D and velocity_follow > 0.0:
		var travel: Vector3 = (target as RigidBody3D).linear_velocity
		travel.y = 0.0
		if travel.length_squared() > 25.0 and travel.dot(-target_forward_world) > 0.0:
			target_forward_world = target_forward_world.lerp(-travel.normalized(), velocity_follow)
	
	# Project the target's forward vector onto the XZ plane (ground plane).
	# This effectively isolates the direction based on yaw.
	var forward_xz_yaw_only: Vector3 = target_forward_world
	forward_xz_yaw_only.y = 0.0 # Zero out the Y component to remove pitch influence.

	if forward_xz_yaw_only.length_squared() > 0.0001: # Check to avoid normalizing a zero vector.
		forward_xz_yaw_only = forward_xz_yaw_only.normalized()
	else:
		# Fallback strategy: If the target is pointing straight up or down,
		# its forward projection on the XZ plane is zero.
		# In this case, use the camera gimble's current forward view (projected to XZ)
		# as a stable directional reference. The gimble's view direction is its local -Z.
		var gimble_view_dir_world: Vector3 = -global_transform.basis.z 
		forward_xz_yaw_only = gimble_view_dir_world
		forward_xz_yaw_only.y = 0.0 # Project to XZ plane.
		if forward_xz_yaw_only.length_squared() > 0.0001:
			forward_xz_yaw_only = forward_xz_yaw_only.normalized()
		else:
			# Ultimate fallback: If the gimble is also looking straight up/down,
			# default to the global "back" direction (-Z).
			forward_xz_yaw_only = Vector3.BACK 

	# Position the camera "behind" the target along this yaw-derived direction.
	# The 'horizontal_offset' determines the distance.
	calculated_pos -= forward_xz_yaw_only * -horizontal_offset

	# 4. Apply "finish mode" offset (sideways).
	# This is also based on the target's yaw only.
	if is_finish_mode:
		# Assume the target model's "right" is along its local +X axis.
		var target_right_world: Vector3 = target.global_transform.basis.x
		
		# Project the target's right vector onto the XZ plane.
		var right_xz_yaw_only: Vector3 = target_right_world
		right_xz_yaw_only.y = 0.0 # Zero out Y component.

		if right_xz_yaw_only.length_squared() > 0.0001:
			right_xz_yaw_only = right_xz_yaw_only.normalized()
		else:
			# Fallback: If target's local "right" is purely vertical (e.g., target is rolled 90 degrees).
			# Derive the "right" direction from the `forward_xz_yaw_only` (which is the target's effective forward on XZ).
			# The "behind" direction is -forward_xz_yaw_only.
			# Right = Behind_XZ.cross(World_Up)
			right_xz_yaw_only = (-forward_xz_yaw_only).cross(Vector3.UP).normalized()
			if right_xz_yaw_only.length_squared() < 0.0001: 
				# If, for some extreme reason, the cross product is zero (e.g. -forward_xz_yaw_only is parallel to UP),
				# which shouldn't happen if forward_xz_yaw_only is a valid XZ vector.
				right_xz_yaw_only = Vector3.RIGHT # Default to global +X.
		
		# Apply the sideways offset.
		calculated_pos += right_xz_yaw_only * finish_offset
	
	return calculated_pos

# This function activates the "finish mode" camera behavior for a short duration.
# It's similar to your original 'set_finish_position' method.
func trigger_finish_camera_mode() -> void:
	is_finish_mode = true
	# Wait for 0.8 seconds, then deactivate finish mode.
	# 'await' pauses execution of this function until the timer's 'timeout' signal is emitted.
	await get_tree().create_timer(0.8).timeout
	is_finish_mode = false

func set_debug_mode():
	debug_mode = true
	#global_position.y += 250
	#camera_3d.look_at(target.global_transform.origin, Vector3.UP)
	
