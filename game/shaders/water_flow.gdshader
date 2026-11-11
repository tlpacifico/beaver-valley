shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

// E1 river current. The water meshes bake the depth tint, the shallow edge and
// the clear cache window into the vertex colours, so this shader keeps the
// vertex colour and vertex alpha untouched and only adds soft ripples that
// travel downstream (+z). No texture, no simulation and no per-frame mesh work.
//
// The baked alpha is the depth signal: shallow marsh and the clear cache window
// have a low alpha, deeper channel water a high one. `depth_mask` therefore
// fades the current out at the shallow edges, where no current should read.
//
// The ripple is two travelling wave trains of different frequency and phase,
// bent by a low-frequency domain warp and scaled by a slow along-channel
// envelope. Together they break the old straight z-band/x-lane lattice that
// read as diagonal plaid fabric. `flow_strength` is the only amplitude control:
// 0 leaves the prepared water colour exactly as authored, and the downstream
// reach uses a larger value than the almost still upstream lake.
uniform float flow_speed : hint_range(0.0, 2.0) = 0.62;
uniform float flow_scale : hint_range(0.05, 8.0) = 1.1;
uniform float flow_strength : hint_range(0.0, 0.5) = 0.16;
uniform vec4 foam_color : source_color = vec4(0.9, 0.96, 0.94, 1.0);

varying vec4 water_color;
varying vec3 world_position;

void vertex() {
	water_color = COLOR;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The vertex alpha is authored from water depth (deep channel ~0.86, shallow
	// marsh ~0.34), so this keeps the animated current on the deeper water and
	// away from the shallow banks and the clear cache window.
	float depth_mask = smoothstep(0.42, 0.72, water_color.a);
	// Distance the surface has travelled downstream since the shader started.
	float travel = TIME * flow_speed;

	// A slow warp bends every crest line, so no ripple stays a straight band
	// across the channel at the play distance.
	float warp = 0.20 * sin(world_position.x * 1.9 + world_position.z * 0.6 + 0.4)
		+ 0.11 * sin(world_position.x * 3.4 - world_position.z * 1.7 + 1.3);

	// Two travelling components with different wavelengths and phases. Both move
	// toward +z, away from the dam.
	float ripple_a = sin((world_position.z - travel + warp) * flow_scale * 2.6 + 0.6);
	float ripple_b = sin((world_position.z * 1.27 - world_position.x * 0.55 - travel * 1.27) * flow_scale * 4.9 + 2.4);

	// Soft along-channel modulation: amplitude swells and fades over several
	// metres instead of repeating one hard period.
	float envelope = 0.58 + 0.42 * sin((world_position.z - travel * 0.85) * 0.55 + world_position.x * 0.18 + 0.9);

	// The mix stays low-contrast: a few percent brightness variation on the deep
	// water, never a high-contrast strip.
	float ripple = (ripple_a * 0.62 + ripple_b * 0.38) * envelope;
	float amount = ripple * depth_mask * flow_strength * 0.8;

	// Modulate brightness instead of mixing toward the foam colour, so the baked
	// depth tint survives and the surface reads as moving water, not paint.
	vec3 lit = water_color.rgb * (1.0 + amount);
	ALBEDO = mix(lit, foam_color.rgb, max(amount, 0.0) * 0.18);
	ALPHA = water_color.a;
}
