// Ciel dynamique : dégradé jour/nuit, coucher de soleil, soleil, lune,
// étoiles, nuages animés (texture de bruit) et flash des éclairs.
// Tous les paramètres sont pilotés par weather_system.gd.
shader_type sky;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float day : hint_range(0.0, 1.0) = 1.0;        // 0 nuit, 1 plein jour
uniform float sunset : hint_range(0.0, 1.0) = 0.0;     // teinte orangée à l'horizon
uniform float clouds : hint_range(0.0, 1.0) = 0.3;     // couverture nuageuse
uniform float cloud_dark : hint_range(0.0, 1.0) = 0.0; // nuages sombres (pluie, orage)
uniform float flash : hint_range(0.0, 1.0) = 0.0;      // éclair
uniform vec2 cloud_offset = vec2(0.0);                 // défilement (vent)
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

const vec3 DAY_ZENITH = vec3(0.16, 0.36, 0.74);
const vec3 DAY_HORIZON = vec3(0.62, 0.76, 0.92);
const vec3 NIGHT_ZENITH = vec3(0.005, 0.008, 0.025);
const vec3 NIGHT_HORIZON = vec3(0.035, 0.045, 0.08);
const vec3 SUNSET_HORIZON = vec3(0.98, 0.48, 0.22);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;

	// --- Dégradé de base -------------------------------------------------
	vec3 zenith = mix(NIGHT_ZENITH, DAY_ZENITH, day);
	vec3 horizon = mix(NIGHT_HORIZON, DAY_HORIZON, day);
	vec2 flat_d = normalize(d.xz + vec2(1e-4));
	vec2 flat_s = normalize(sun_dir.xz + vec2(1e-4));
	float toward_sun = pow(max(dot(flat_d, flat_s), 0.0), 3.0);
	horizon = mix(horizon, SUNSET_HORIZON, sunset * (0.35 + 0.65 * toward_sun));
	vec3 col = mix(horizon, zenith, pow(clamp(h, 0.0, 1.0), 0.45));
	if (h < 0.0) {
		// Sous l'horizon : terres lointaines dans la brume (si l'on voit au-delà du
		// terrain, depuis une route en hauteur, on croit voir une vallée au loin).
		vec3 land = mix(vec3(0.015, 0.02, 0.025), vec3(0.26, 0.33, 0.26), day);
		land = mix(land, horizon, 0.45);
		col = mix(horizon, land, clamp(-h * 9.0, 0.0, 1.0));
	}

	// --- Étoiles ---------------------------------------------------------
	float night = 1.0 - day;
	if (night > 0.01 && h > 0.0) {
		vec3 cell = floor(d * 220.0);
		float s = hash13(cell);
		float star = step(0.9975, s) * smoothstep(0.0, 0.25, h);
		col += vec3(star) * night * (1.0 - clouds) * (0.6 + 0.4 * hash13(cell + 7.0));
	}

	// --- Soleil et lune ---------------------------------------------------
	float sd = dot(d, sun_dir);
	vec3 sun_col = mix(vec3(1.0, 0.55, 0.25), vec3(1.0, 0.96, 0.88), clamp(sun_dir.y * 3.0, 0.0, 1.0));
	float sun_vis = smoothstep(-0.05, 0.02, sun_dir.y);
	col += sun_col * (smoothstep(0.9993, 0.9996, sd) * 6.0 + pow(max(sd, 0.0), 80.0) * 0.6) * sun_vis;
	float md = dot(d, moon_dir);
	col += vec3(0.75, 0.8, 0.95) * smoothstep(0.9994, 0.9997, md) * night;

	// --- Nuages ----------------------------------------------------------
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 0.12 + cloud_offset;
		float n = texture(noise_tex, uv).r * 0.65 + texture(noise_tex, uv * 2.7 + 0.37).r * 0.35;
		float threshold = 1.0 - clouds;
		float cover = smoothstep(threshold - 0.08, threshold + 0.22, n) * smoothstep(0.0, 0.12, h);
		cover = max(cover, clouds * clouds * 0.85 * smoothstep(0.0, 0.08, h)); // ciel couvert
		vec3 lit = mix(vec3(0.07, 0.08, 0.11), vec3(0.96, 0.96, 0.98), day);
		lit = mix(lit, SUNSET_HORIZON * 0.9 + 0.15, sunset * 0.6);
		vec3 shade = lit * mix(0.82, 0.3, cloud_dark);
		vec3 cloud_col = mix(lit, shade, smoothstep(0.35, 0.9, n));
		col = mix(col, cloud_col, cover);
	}
	// Ciel bouché et sombre par mauvais temps.
	vec3 grey = mix(vec3(0.03, 0.035, 0.05), vec3(0.5, 0.53, 0.57), day) * (1.0 - 0.55 * cloud_dark);
	col = mix(col, grey, clouds * cloud_dark * 0.75);

	col += flash * vec3(0.75, 0.8, 1.0);
	COLOR = col;
}
