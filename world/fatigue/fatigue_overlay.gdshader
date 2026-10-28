// Filtre plein écran de la fatigue (Fatigue), posé devant la caméra comme celui des
// pilules : vue qui s'assombrit par les bords, yeux qui larmoient après un bâillement,
// paupières qui se ferment (clignements, micro-sommeils).
// Travaille en SCREEN_UV : identique en VR (chaque œil) et en mode bureau.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;

uniform float dim = 0.0;    // 0 -> 1 : vision qui s'assombrit (fatigue)
uniform float lids = 0.0;   // 0 = yeux ouverts, 1 = fermés
uniform float tears = 0.0;  // larmes après un bâillement : vue embuée et brillante

void layer(inout vec3 pc, inout float a, vec3 c, float ca) {
	ca = clamp(ca, 0.0, 1.0);
	pc = c * ca + pc * (1.0 - ca);
	a = ca + a * (1.0 - ca);
}

void fragment() {
	vec2 p = SCREEN_UV - 0.5;
	float r = length(p * vec2(1.25, 1.0)) * 2.0;
	vec3 pc = vec3(0.0);
	float a = 0.0;

	// Vue qui s'assombrit : voile léger partout, bords de plus en plus noirs, qui
	// « respire » lentement (on lutte pour garder les yeux ouverts).
	float sway = 0.5 + 0.5 * sin(TIME * 0.45);
	layer(pc, a, vec3(0.0, 0.0, 0.015), dim * (0.18 + 0.06 * sway));
	float inner = mix(1.15, 0.3, dim);
	layer(pc, a, vec3(0.0), smoothstep(inner, inner + 0.75, r) * dim * 1.1);

	// Larmes : halo clair et ondulant, surtout en bas et sur les bords.
	float wob = sin(p.x * 23.0 + TIME * 1.7) * 0.03 + sin(p.y * 17.0 - TIME * 1.1) * 0.03;
	float wet = smoothstep(0.25, 1.1, r + wob) * 0.55 + smoothstep(0.1, 0.5, p.y + wob) * 0.45;
	layer(pc, a, vec3(0.85, 0.88, 0.9), tears * 0.38 * wet);

	// Paupières : se ferment par le haut et par le bas en forme d'amande ; près du bord
	// la lumière traverse la peau (rouge sombre).
	float h = mix(0.8, 0.0, lids) * (1.0 - 0.35 * (2.0 * p.x) * (2.0 * p.x));
	float d = abs(p.y) - h;
	float lid = smoothstep(-0.035, 0.035, d);
	lid = max(lid, smoothstep(0.85, 1.0, lids));
	vec3 skin = mix(vec3(0.09, 0.015, 0.01), vec3(0.0), smoothstep(0.0, 0.12, d));
	layer(pc, a, skin, lid * step(0.001, lids));

	ALBEDO = pc / max(a, 0.001);
	ALPHA = clamp(a, 0.0, 1.0);
}
