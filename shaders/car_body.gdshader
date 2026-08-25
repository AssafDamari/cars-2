shader_type spatial;

// Per-instance parameter: each MeshInstance3D sets its own color
// without duplicating the material, enabling GPU batching.
instance uniform vec4 car_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	ALBEDO = car_color.rgb;
}

