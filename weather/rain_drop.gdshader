// Gouttes de pluie (particules). Les gouttes qui entrent dans le volume d'un abri
// (la voiture : habitacle, pare-brise, capot) ne sont pas dessinées, pour qu'elles
// ne traversent ni le toit ni le capot. Le volume suit le profil du 4x4.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(0.78, 0.82, 0.9, 0.35);
uniform float shelter_on = 0.0;
uniform mat4 shelter_inv;                  // monde -> repère de la voiture
// Profil de l'abri (repère de la voiture : +Z = avant, Y = haut).
uniform float half_width = 0.99;
uniform float floor_y = 0.2;
uniform float rear_z = -2.4;
uniform float roof_y = 1.95;               // toit + barres de toit
uniform float roof_front_z = 0.55;         // haut du pare-brise
uniform float hood_z = 1.05;               // bas du pare-brise
uniform float hood_y = 1.2;
uniform float front_z = 2.5;

varying vec3 wpos;

void vertex() {
	wpos = (INV_VIEW_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0))).xyz;
}

void fragment() {
	if (shelter_on > 0.5) {
		vec3 p = (shelter_inv * vec4(wpos, 1.0)).xyz;
		if (abs(p.x) < half_width && p.z > rear_z && p.z < front_z && p.y > floor_y) {
			float top = hood_y;
			if (p.z < roof_front_z) {
				top = roof_y;
			} else if (p.z < hood_z) {
				top = mix(roof_y - 0.08, hood_y, (p.z - roof_front_z) / (hood_z - roof_front_z));
			}
			if (p.y < top) {
				discard;
			}
		}
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
