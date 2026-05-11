shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float speed : hint_range(0.0, 5.0) = 2.0;

void fragment() {
	// Direction from center
	vec2 center = vec2(0.5, 0.5);
	vec2 dir = UV - center;
	float dist = length(dir);
	float angle = 0.0;

	// Animated lines radiating outward
	float line = sin(angle * 12.0 + TIME * speed - dist * 20.0);
	line = smoothstep(0.4, 1.0, line);

	// Fade toward center and toward edges
	float radial_fade = smoothstep(0.0, 0.2, dist) * smoothstep(0.8, 0.4, dist);

	float alpha = line * radial_fade * intensity;
	COLOR = vec4(1.0, 1.0, 1.0, alpha * 0.3);
}