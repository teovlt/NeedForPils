// Léger halo additif (effet Fresnel) posé sur la pièce elle-même,
// pour que les pièces encastrées (boîte à gants...) restent visibles.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

uniform vec4 color : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = color.rgb * (0.05 + 0.30 * fresnel) * intensity;
}
