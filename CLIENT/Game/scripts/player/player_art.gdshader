shader_type canvas_item;

uniform float hurt_flash : hint_range(0.0, 1.0) = 0.0;
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec4 sampled = texture(TEXTURE, UV) * sprite_tint;
	COLOR = vec4(mix(sampled.rgb, vec3(1.0), hurt_flash), sampled.a);
}
