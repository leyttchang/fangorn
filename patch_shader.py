import os

path = 'Y:/Fangorn/fangorn/scripts/abilities/casting_animation/lightning_ball_shader.gdshader'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_vertex = '''void vertex()
{
\tfloat noiseVal = (texture(noiseVertex, UV + (TIME * speedVertex)).r * 2.0) - 1.0; // Range: -1.0 to 1.0
\tvec3 displacement = NORMAL * noiseVal * distortionVertex;
\tVERTEX = VERTEX + displacement;
}'''

new_vertex = '''void vertex()
{
\tfloat noiseVal = (texture(noiseVertex, UV + (TIME * speedVertex)).r * 2.0) - 1.0; // Range: -1.0 to 1.0
\t
\t// Calcul du scale du mesh (pour eviter les explosions de vertices sur les FBX scaled x100)
\tfloat model_scale = length(MODEL_MATRIX[0].xyz);
\tif (model_scale == 0.0) { model_scale = 1.0; } // Securite
\t
\tvec3 displacement = NORMAL * noiseVal * (distortionVertex / model_scale);
\tVERTEX = VERTEX + displacement;
}'''

content = content.replace(old_vertex, new_vertex)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
