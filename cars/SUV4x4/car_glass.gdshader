// Vitres du 4x4 : verre presque incolore, qui devient flou (eau ruisselante) quand il
// pleut. L'image derrière la vitre est relue (hint_screen_texture) et moyennée sur un
// disque dont le rayon dépend de `wet`. Le pare-brise et la lunette arrière sont exclus
// (z > windshield_z ou z < rear_window_z dans le repère du modèle) : ils ont leur propre
// couche (WindshieldRain), effacée par les essuie-glaces.
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(0.85, 0.92, 0.96, 1.0);
uniform float opacity = 0.1;
uniform float wet = 0.0;              // 0 sec -> 1 très mouillé
uniform float max_blur_px = 9.0;      // rayon du flou à wet = 1 (pixels)
uniform float windshield_z = 0.3;     // au-delà : pare-brise, jamais flou ici
uniform float rear_window_z = -2.15;  // en deçà : lunette arrière (couche à part, essuie-glace arrière)
uniform float light = 1.0;

varying vec3 obj_pos;

const vec2 TAPS[12] = vec2[](
	vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457), vec2(-0.203, 0.621),
	vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767), vec2(0.185, -0.893),
	vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598));

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	float w = (obj_pos.z > windshield_z || obj_pos.z < rear_window_z) ? 0.0 : wet;
	if (w < 0.01) {
		ALBEDO = tint.rgb * (0.3 + 0.7 * light);
		ALPHA = opacity;
	} else {
		// gouttes et filets d'eau : décale un peu l'échantillon (réfraction irrégulière)
		vec2 cell = floor(obj_pos.zy * 38.0 + obj_pos.x * 17.0);
		float h = hash12(cell);
		vec2 jitter = (vec2(hash12(cell + 3.1), hash12(cell + 7.7)) - 0.5) * 6.0 * w * step(1.0 - w * 0.6, h);
		vec3 col = blurred(SCREEN_UV + jitter / VIEWPORT_SIZE, max_blur_px * w, VIEWPORT_SIZE, FRAGCOORD.z);
		// voile d'eau : un peu moins de contraste, légèrement gris-bleu
		vec3 haze = vec3(0.55, 0.6, 0.66) * (0.25 + 0.75 * light);
		col = mix(col, haze, 0.12 * w);
		ALBEDO = col;
		ALPHA = mix(opacity, 1.0, clamp(w * 1.6, 0.0, 1.0));
	}
}
