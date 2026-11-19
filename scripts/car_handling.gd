class_name CarHandling
extends Resource
## Arcade handling profile for a car type.
##
## The profile only shapes how the PLAYER's car responds to input. NPC cars
## drive the raw VehicleBody3D physics and ignore it. Wheel grip, suspension and
## mass stay in the car scene; values here are relative to those.
##
## Progression: an upgraded car can be a duplicated profile with higher numbers
## (more lateral grip, faster steering, longer drift boost...).

@export_group("Steering")
## Widest front-wheel angle in degrees. Only reachable at low speed.
@export_range(5.0, 45.0, 0.5) var max_steer_angle_deg: float = 30.0
## Sideways acceleration (m/s²) a full stick asks for at speed. Higher means
## tighter turns at speed. Turn rate = this / speed, so the car feels the same at
## every speed: full stick is always "turn as hard as the tires allow".
@export var max_lateral_accel: float = 20.0
## How quickly the steering follows the stick (1/s).
@export var steer_response: float = 8.0
## How quickly the steering re-centers when the stick is released (1/s).
@export var steer_return: float = 14.0
## Speed scrubbed off (m/s²) while the stick is held hard over at speed, so
## a one-thumb player can take tight corners without touching the brake.
## 0 = off.
@export var steer_slowdown: float = 0.0

@export_group("Stability")
## How hard the car is pushed to turn at the intended rate. This removes
## under- and oversteer. 0 = raw physics.
@export_range(0.0, 30.0, 0.5) var yaw_assist: float = 8.0
## Most angular acceleration (rad/s²) the yaw assist may use.
@export var yaw_assist_max: float = 8.0
## Sideways slip (degrees) allowed in normal driving before the car is pulled
## straight. Ignored while drifting.
@export var max_grip_slip_deg: float = 6.0
## How strongly sideways slide beyond max_grip_slip_deg is cancelled (1/s).
@export var slip_correction: float = 4.0

@export_group("Drift")
## Turn the drift system on (drift car).
@export var drift_enabled: bool = false
## Stick deflection (0..1) that kicks the car into a drift at speed.
@export_range(0.1, 1.0, 0.05) var drift_entry_steer: float = 0.75
## Pressing brake while steering also starts a drift.
@export var drift_on_brake: bool = true
## Slowest speed (m/s) a drift can start at.
@export var drift_min_speed: float = 12.0
## Drift angle (degrees) when counter-steering (wide line).
@export var drift_angle_min_deg: float = 15.0
## Drift angle (degrees) when steering hard into the turn (tight line).
@export var drift_angle_max_deg: float = 40.0
## Turn rate of the path (rad/s) when counter-steering.
@export var drift_turn_rate_min: float = 0.45
## Turn rate of the path (rad/s) when steering hard into the turn.
@export var drift_turn_rate_max: float = 1.35
## Upper limit for sideways acceleration while drifting (m/s²).
@export var drift_max_lateral_accel: float = 32.0
## Wheel grip multiplier while sliding. Low = the tires slide and the
## drift assist decides the line.
@export_range(0.0, 1.0, 0.01) var drift_grip_factor: float = 0.1
## Seconds to go fully sideways.
@export var drift_engage_time: float = 0.18
## Seconds to grip up again after the drift ends.
@export var drift_release_time: float = 0.35
## Speed lost per second while drifting (m/s²).
@export var drift_speed_loss: float = 1.0
## Stick must be near center this long (s) to end the drift.
@export var drift_exit_delay: float = 0.15

@export_group("Drift Boost")
## Drifts shorter than this (s) give no boost.
@export var boost_min_drift_time: float = 0.8
## Drift length (s) that gives the full boost.
@export var boost_full_drift_time: float = 2.5
## Length (s) of a full boost.
@export var boost_duration: float = 1.2
## Extra forward acceleration (m/s²) while boosting.
@export var boost_accel: float = 9.0
## Top speed multiplier while boosting.
@export var boost_top_speed_factor: float = 1.15

@export_group("Aero & Air")
## Downforce (N per (m/s)²) that pushes the car onto the road at speed.
## More downforce means more tire grip in fast corners.
@export var downforce: float = 0.0
## How strongly the car levels itself in the air (1/s²). 0 = off.
@export var air_control: float = 0.0
## Damps tumbling in the air (1/s).
@export var air_damping: float = 2.0
## Put the car back on its wheels after it has been stuck on its side or roof.
@export var auto_flip: bool = true
