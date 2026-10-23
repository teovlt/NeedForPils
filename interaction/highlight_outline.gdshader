// Contour lumineux par "coque inversée" : le mesh est légèrement gonflé
// le long de normales lissées et seules ses faces arrière sont dessinées.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_mix, fog_disabled;

uniform vec4 color : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float pulse_speed = 4.0;

void fragment() {
	float pulse = 0.82 + 0.18 * sin(TIME * pulse_speed);
	ALBEDO = color.rgb;
	ALPHA = clamp(intensity * pulse, 0.0, 1.0);
}
