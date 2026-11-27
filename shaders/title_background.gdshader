shader_type canvas_item;
render_mode unshaded;

varying vec4 tint;

float soft_ellipse(vec2 uv, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.15, 1.0, length((uv - center) / radius));
}

float lantern_flicker(float time, float phase) {
	float flutter = sin(time * 8.1 + phase * 1.6 + 0.6 * sin(time * 2.1 + phase));
	return 0.56 + 0.26 * sin(time * 3.4 + phase)
		+ 0.13 * flutter + 0.05 * sin(time * 13.2 - phase);
}

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 uv = UV;
	// Move the painted wavelets sideways, keeping the banks and foreground still.
	float water = soft_ellipse(uv, vec2(0.644, 0.752), vec2(0.087, 0.090));
	float wave = sin(uv.y * 390.0 - TIME * 2.6 + sin(uv.x * 61.0) * 1.4);
	float wave_detail = sin(uv.y * 655.0 - TIME * 3.8 - uv.x * 46.0);
	float offset = water * (0.0026 * wave + 0.0009 * wave_detail);

	vec4 art;
	if (water > 0.0) {
		// Blend adjacent horizontal samples for subpixel motion with the pixel-art filter.
		float texels = offset / TEXTURE_PIXEL_SIZE.x;
		float whole = floor(texels);
		vec2 sample_uv = uv + vec2(whole * TEXTURE_PIXEL_SIZE.x, 0.0);
		art = mix(texture(TEXTURE, sample_uv),
			texture(TEXTURE, sample_uv + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)), fract(texels));
	} else {
		art = texture(TEXTURE, uv);
	}

	float reflection = soft_ellipse(uv, vec2(0.646, 0.775), vec2(0.036, 0.077));
	float sparkle = pow(max(0.0, wave * 0.65 + wave_detail * 0.35), 3.0);
	float warm_light = smoothstep(0.18, 0.72, art.r - art.b * 0.55);
	art.rgb *= 1.0 + water * (0.12 * wave + 0.045 * wave_detail);
	art.rgb += vec3(1.0, 0.61, 0.23) * reflection * warm_light * sparkle * 0.24;

	// Each lantern has a small flame core and a wider pool of warm spill.
	float left_spill = soft_ellipse(uv, vec2(0.173, 0.569), vec2(0.051, 0.080));
	float right_spill = soft_ellipse(uv, vec2(0.898, 0.770), vec2(0.044, 0.072));
	float left_core = soft_ellipse(uv, vec2(0.173, 0.572), vec2(0.009, 0.027));
	float right_core = soft_ellipse(uv, vec2(0.898, 0.772), vec2(0.008, 0.021));
	float left_flicker = lantern_flicker(TIME, 0.0);
	float right_flicker = lantern_flicker(TIME * 1.13, 2.3);
	float glow = left_spill * (0.066 + left_flicker * 0.24)
		+ right_spill * (0.064 + right_flicker * 0.23);
	glow += 0.18 * (left_core * left_flicker + right_core * right_flicker);
	art.rgb += vec3(1.0, 0.64, 0.20) * glow;

	COLOR = art * tint;
}
