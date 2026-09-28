shader_type canvas_item;
// Remove only the edge-connected matte, preserving dark details inside the monster.
uniform sampler2D matte_mask : filter_linear, repeat_disable;
void fragment() {
	COLOR.a *= texture(matte_mask, UV).r;
}
