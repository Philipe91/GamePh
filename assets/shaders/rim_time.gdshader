shader_type spatial;
// Rim light FRESNEL discreto na cor do time (overlay aditivo por cima do material
// original — não repinta a textura do modelo). Faz o personagem "descolar" do chão
// escuro em qualquer ângulo, e diz de longe quem é aliado/inimigo.
render_mode unshaded, blend_add, cull_back, depth_draw_never;

uniform vec4 cor : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform float forca : hint_range(0.0, 1.0) = 0.32;
uniform float expoente : hint_range(1.0, 6.0) = 2.8;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), expoente);
	ALBEDO = cor.rgb * f * forca;
}
