// Pluie sur le pare-brise. La carte "wet_map" (calculée par windshield_rain.gd) dit où
// la vitre est mouillée : les essuie-glaces la remettent à 0. Là où c'est mouillé,
// l'image derrière le pare-brise est floutée (film d'eau) et des gouttes déforment la vue.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D wet_map : filter_linear, hint_default_black;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float cells_x = 34.0;
uniform float aspect = 0.46;          // hauteur / largeur de la vitre
uniform float light = 1.0;            // luminosité ambiante (nuit = sombre)
uniform float max_blur_px = 16.0;     // rayon du flou là où la vitre est trempée (pixels)

const vec2 TAPS[12] = vec2[](
	vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457), vec2(-0.203, 0.621),
	vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767), vec2(0.185, -0.893),
	vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598));

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Une couche de gouttes : renvoie (opacité, reflet, décalage de réfraction x, y).
vec4 drops(vec2 uv, float scale, float wet, float seed) {
	vec2 g = uv * vec2(scale, scale * aspect);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float h = hash12(cell + seed);
	if (h > wet) {
		return vec4(0.0);
	}
	vec2 c = vec2(hash12(cell + seed + 3.1), hash12(cell + seed + 7.7)) * 0.6 + 0.2;
	float r = 0.12 + 0.22 * hash12(cell + seed + 1.3);
	vec2 d2 = (f - c) / r;
	float d = length(d2);
	float body = 1.0 - smoothstep(0.8, 1.0, d);
	float rim = smoothstep(0.55, 0.95, d) * body;
	float hl = 1.0 - smoothstep(0.0, 0.4, length(f - c + vec2(r * 0.35, -r * 0.35)) / r);
	return vec4(body * 0.12 + rim * 0.35, hl * body, -d2 * body);   // la goutte agit comme une lentille
}

// Flou sur un disque. Les échantillons qui tombent sur un objet plus proche que la
// vitre (rétroviseur, tableau de bord, montants…) sont ignorés : sinon ces objets
// « bavent » sur la vitre. Profondeur inversée (Godot 4.3+) : plus proche = plus grand.
vec3 blurred(vec2 uv, float radius_px, vec2 vp, float frag_depth) {
	float a = hash12(uv * vp) * 6.2831;
	mat2 rot = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
	vec3 acc = texture(screen_tex, uv).rgb;
	float n = 1.0;
	for (int i = 0; i < 12; i++) {
		vec2 q = uv + rot * TAPS[i] * radius_px / vp;
		if (texture(depth_tex, q).r <= frag_depth) {
			acc += texture(screen_tex, q).rgb;
			n += 1.0;
		}
	}
	return acc / n;
}

void fragment() {
	float wet = texture(wet_map, UV).r;
	vec4 a = drops(UV, cells_x, wet, 0.0);
	vec4 b = drops(UV, cells_x * 2.3, wet * 1.2, 17.0);
	float drop_alpha = clamp(a.x + b.x * 0.8, 0.0, 0.85);
	float hl = max(a.y, b.y * 0.8);
	vec2 refr = (a.zw + b.zw * 0.6) * 10.0;   // décalage en pixels
	// film d'eau : flou d'autant plus fort que la vitre est mouillée
	float film = smoothstep(0.05, 0.9, wet);
	vec3 col = blurred(SCREEN_UV + refr / VIEWPORT_SIZE, max_blur_px * film, VIEWPORT_SIZE, FRAGCOORD.z);
	vec3 haze = vec3(0.55, 0.6, 0.66) * (0.25 + 0.75 * light);
	col = mix(col, haze, 0.15 * film + drop_alpha * 0.4);
	col = mix(col, vec3(0.9, 0.95, 1.0) * (0.35 + 0.65 * light), hl * 0.6);
	ALBEDO = col;
	ALPHA = clamp(max(film * 1.15, max(drop_alpha * 1.5, hl * 0.6)), 0.0, 1.0);
}
