// Filtre plein écran posé devant la caméra (PillAddiction) : vignettage du manque,
// couleurs qui ondulent quand on est bourré, éclair à la prise, black-out.
// Travaille en SCREEN_UV : identique en VR (chaque œil) et en mode bureau.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;

uniform float craving = 0.0;
uniform float drunk = 0.0;
uniform float blackout = 0.0;
uniform float flash = 0.0;
uniform float pulse = 0.0;
uniform float assimilation = 0.0;
uniform float chase = 0.0;
uniform float stoned = 0.0;  // joint : brume chaude, bords flous qui respirent   // poursuivante proche : bords qui clignotent rose / bleu

vec3 palette(float h) {
	return 0.5 + 0.5 * cos(6.2832 * (h + vec3(0.0, 0.33, 0.67)));
}

// Couches empilées l'une sur l'autre (couleur prémultipliée par l'opacité).
void layer(inout vec3 pc, inout float a, vec3 c, float ca) {
	pc = c * ca + pc * (1.0 - ca);
	a = ca + a * (1.0 - ca);
}

void fragment() {
	vec2 p = SCREEN_UV - 0.5;
	float r = length(p * vec2(1.3, 1.0)) * 2.0;
	vec3 pc = vec3(0.0);
	float a = 0.0;

	// Bourré : bandes de couleur qui ondulent, surtout sur les bords.
	float wave = sin(p.y * 9.0 + TIME * 1.3) * 0.12 + sin(p.x * 7.0 - TIME * 0.9) * 0.1;
	float h = fract(TIME * 0.07 + r * 1.2 + wave + assimilation * 0.3);
	layer(pc, a, palette(h), drunk * (0.05 + 0.24 * smoothstep(0.35, 1.1, r + wave * 0.5)));

	// Joint : voile de fumée chaud sur toute la vue, plus épais sur les bords, qui
	// respire lentement et dérive.
	float breathe = 0.5 + 0.5 * sin(TIME * 0.6);
	float drift = sin(p.x * 3.0 + TIME * 0.25) * 0.08 + sin(p.y * 4.0 - TIME * 0.2) * 0.08;
	float haze = stoned * (0.08 + 0.05 * breathe + 0.34 * smoothstep(0.45, 1.25, r + drift));
	layer(pc, a, mix(vec3(0.62, 0.66, 0.52), vec3(0.78, 0.72, 0.6), breathe), haze);

	// Éclair rose à la prise d'une pilule.
	layer(pc, a, vec3(1.0, 0.35, 0.8), flash * flash * 0.45);

	// Manque : vignettage sombre qui se resserre et bat avec le cœur.
	float inner = mix(0.9, 0.25, craving);
	float av = smoothstep(inner, inner + 0.7, r) * smoothstep(0.15, 1.0, craving) * (0.8 + 0.2 * pulse);
	layer(pc, a, vec3(0.03, 0.0, 0.0), clamp(av, 0.0, 0.95));

	// Gyrophares de la poursuivante sur les bords.
	vec3 siren = mix(vec3(1.0, 0.15, 0.7), vec3(0.15, 0.35, 1.0), step(0.5, fract(TIME * 1.5)));
	layer(pc, a, siren, chase * 0.4 * smoothstep(0.55, 1.25, r));

	// Black-out.
	layer(pc, a, vec3(0.0), blackout);

	ALBEDO = pc / max(a, 0.001);
	ALPHA = clamp(a, 0.0, 1.0);
}
