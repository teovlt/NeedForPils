// Bitume procédural. UV.x = position latérale (m, 0 = axe, + = droite),
// UV.y = distance parcourue le long de la route (m).
// COLOR.r = nid-de-poule, COLOR.g = rustine, COLOR.b = dos-d'âne, COLOR.a = usure.
shader_type spatial;
render_mode cull_back;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float edge_line = 3.6;      // position des lignes de rive (m)
uniform float line_half_width = 0.07;
uniform float dash_period = 12.0;    // ligne centrale : 3 m de trait, 9 m d'espace
uniform float dash_ratio = 0.25;

void fragment() {
	vec2 p = UV;
	float n_big = texture(noise_tex, p * 0.07).r;
	float n_mid = texture(noise_tex, p * 0.45).r;
	float n_fine = texture(noise_tex, p * 3.1).r;
	float wear = COLOR.a;

	// --- Bitume ------------------------------------------------------------
	vec3 asphalt = vec3(0.12, 0.12, 0.125) * (0.82 + 0.25 * n_mid + 0.18 * n_fine);
	asphalt = mix(asphalt, asphalt * vec3(1.15, 1.12, 1.05), smoothstep(0.55, 0.8, n_big) * 0.6);
	// traces de roues plus claires (bitume poli)
	float ax = abs(p.x);
	float wheel_track = smoothstep(0.6, 0.0, abs(ax - 0.9)) + smoothstep(0.6, 0.0, abs(ax - 2.6));
	asphalt *= 1.0 + 0.08 * wheel_track;

	// --- Fissures (plus nombreuses quand la route est usée) ----------------
	float c1 = abs(texture(noise_tex, p * vec2(0.11, 0.04)).r - 0.5);
	float c2 = abs(texture(noise_tex, p * vec2(0.05, 0.13) + 0.31).r - 0.5);
	float crack = (1.0 - smoothstep(0.0, 0.012, c1)) + (1.0 - smoothstep(0.0, 0.009, c2));
	asphalt *= 1.0 - clamp(crack, 0.0, 1.0) * 0.55 * wear;

	// --- Rustines --------------------------------------------------------------
	asphalt = mix(asphalt, vec3(0.065, 0.065, 0.07) * (0.9 + 0.2 * n_fine), COLOR.g);

	// --- Marquage ---------------------------------------------------------------
	float center = (1.0 - smoothstep(line_half_width, line_half_width + 0.015, ax))
		* step(fract(p.y / dash_period), dash_ratio);
	float edge = 1.0 - smoothstep(line_half_width, line_half_width + 0.015, abs(ax - edge_line));
	float paint_wear = mix(1.0, smoothstep(0.25, 0.6, n_fine + n_mid * 0.5), wear);
	float paint = max(center, edge) * paint_wear * (1.0 - COLOR.g) * (1.0 - COLOR.r);
	vec3 col = mix(asphalt, vec3(0.86, 0.86, 0.82), paint);

	// --- Dos-d'âne : bandes jaunes en biais --------------------------------------
	float stripe = step(0.5, fract((p.x + p.y) * 0.9)) * COLOR.b;
	col = mix(col, vec3(0.9, 0.72, 0.08), stripe);

	// --- Nid-de-poule : fond sombre, gravier ---------------------------------
	vec3 hole = vec3(0.05, 0.045, 0.04) * (0.6 + 0.8 * n_fine);
	float rim = smoothstep(0.02, 0.25, COLOR.r) * (1.0 - smoothstep(0.35, 0.75, COLOR.r));
	col = mix(col, vec3(0.3, 0.29, 0.27) * (0.7 + 0.6 * n_fine), rim * 0.8);   // bord effrité
	col = mix(col, hole, smoothstep(0.55, 0.95, COLOR.r));

	// --- Pluie : bitume plus sombre et brillant, flaques dans les trous ------
	float rough = mix(0.88, 0.32, wetness);
	col *= 1.0 - 0.38 * wetness;
	float puddle = smoothstep(0.35, 0.7, COLOR.r) * smoothstep(0.2, 0.6, wetness);
	col = mix(col, vec3(0.035, 0.045, 0.055), puddle);
	rough = mix(rough, 0.04, puddle);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = mix(0.35, 0.7, max(wetness * 0.6, puddle));
}
