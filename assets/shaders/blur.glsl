uniform float radius;
uniform vec2 size;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc)
{
    vec4 sum = vec4(0.0);
    float count = 0.0; // Agora a gente CONTA os pixels de verdade, chega de matemática preguiçosa!

    const int MAX_R = 64; 

    for (int x = -MAX_R; x <= MAX_R; x++)
    {
        for (int y = -MAX_R; y <= MAX_R; y++)
        {
            // O SEGREDO AQUI! 
            // length() cria um círculo perfeito em vez de um quadrado horroroso.
            if (length(vec2(x, y)) > radius)
                continue;

            vec2 offset = vec2(x, y) / size;
            sum += Texel(tex, uv + offset);
            count += 1.0; // Adiciona 1 pra cada pixel válido dentro do círculo
        }
    }

    // Se o count for zero (impossível, mas o diabo mora nos detalhes), evita explodir o universo
    if (count == 0.0) return vec4(0.0);

    return sum / count;
}