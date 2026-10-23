// Variation de couleur du décor (arbres, buissons, herbes, rochers).
// Chaque instance du MultiMesh reçoit dans INSTANCE_CUSTOM (valeurs 0..1) :
//   r = décalage de teinte, g = saturation, b = luminosité, a = « sécheresse » (jaunissement).
// Chaque facette reçoit en plus une petite variation de luminosité (aspect low poly organique).
shader_type spatial;

uniform vec4 base_color : source_color = vec4(1.0);
uniform float roughness_value = 0.9;
uniform float hue_amount = 0.03;   // glissement chaud/froid (0.03 ≈ léger)
uniform float sat_amount = 0.15;
uniform float val_amount = 0.15;
uniform float dry_amount = 0.0;    // 0 = jamais jaunissant
uniform float face_amount = 0.07;  // variation par facette
uniform vec4 dry_color : source_color = vec4(0.62, 0.52, 0.24, 1.0);

varying vec4 v_custom;
varying flat float v_face;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	v_face = hash13(VERTEX * 37.0 + v_custom.rgb * 11.0);
}

void fragment() {
	vec3 col = base_color.rgb;
	// Hors MultiMesh, INSTANCE_CUSTOM vaut 0 : on retombe sur des valeurs neutres.
	vec4 c = (dot(v_custom, vec4(1.0)) < 1.0e-5) ? vec4(0.5, 0.5, 0.5, 0.0) : v_custom;
	// Calculs en RGB (pas de HSV : trop imprécis en demi-précision sur GL Compatibility).
	// « Teinte » : glissement vers un ton chaud (jaune-rouge) ou froid (bleu-vert).
	float h = (c.r - 0.5) * 2.0 * hue_amount * 6.0;
	float l0 = dot(col, vec3(0.3, 0.59, 0.11));
	vec3 warm = vec3(col.r * 1.25 + col.g * 0.1, col.g * 1.0, col.b * 0.6);
	vec3 cool = vec3(col.r * 0.7, col.g * 1.0, col.b * 1.3 + col.g * 0.05);
	col = mix(col, h > 0.0 ? warm : cool, abs(h));
	col *= l0 / max(dot(col, vec3(0.3, 0.59, 0.11)), 0.001);   // garde la luminosité
	// Saturation : écart à la luminance.
	float l1 = dot(col, vec3(0.3, 0.59, 0.11));
	col = max(mix(vec3(l1), col, 1.0 + (c.g - 0.5) * 2.0 * sat_amount), vec3(0.0));
	// Luminosité par instance et par facette.
	col *= 1.0 + (c.b - 0.5) * 2.0 * val_amount + (v_face - 0.5) * 2.0 * face_amount;
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, dry_color.rgb * lum * 2.6, clamp(c.a * dry_amount, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = roughness_value;
}
