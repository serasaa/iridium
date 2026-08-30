extern vec2  u_resolution;  // Tamanho da tela (largura, altura)
extern vec2  u_offset;      // Posição da câmera (camera.x, camera.y)
extern float u_zoom;        // Nível de zoom atual
extern float u_gridSize;    // Tamanho da grade dinâmica (calculado no Lua)
extern float u_lineWidth;   // Espessura das linhas da grade
extern float u_axisWidth;   // Espessura dos eixos principais
extern vec4  u_gridColor;   // Cor da grade (com transparência)
extern vec4  u_axisColor;   // Cor dos eixos (com transparência)

// Função auxiliar para desenhar uma linha anti-aliasing baseada em distância
float drawLine(float dist, float width) {
    // Usa smoothstep para criar bordas suaves nas linhas, evitando serrilhado
    // independente do nível de zoom ou resolução.
    float feather = 1.0; // Suavização de 1 pixel
    return smoothstep(width + feather, width - feather, abs(dist) * u_zoom);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // 1. Converter coordenadas da tela para coordenadas do mundo
    // Centraliza a origem (0,0) no meio da tela
    vec2 center = u_resolution * 0.5;
    // Calcula a posição no mundo considerando zoom e offset da câmera
    vec2 worldCoords = (screen_coords - center) / u_zoom + u_offset;

    // 2. Calcular a intensidade da grade de fundo
    // 'mod' calcula a distância do pixel atual para a linha da grade mais próxima
    vec2 gridMod = mod(worldCoords + u_gridSize * 0.5, u_gridSize) - u_gridSize * 0.5;
    
    // Anti-aliasing para a grade
    float gridLines = max(drawLine(gridMod.x, u_lineWidth), drawLine(gridMod.y, u_lineWidth));

    // 3. Lógica para Pular os Eixos Principais na Grade de Fundo
    // (Isso replica o 'if x~=0 then' do seu código original)
    float axisThreshold = u_gridSize * 0.1; // Margem de segurança pequena
    // Remove a grade de fundo se estivermos muito perto de X=0 ou Y=0
    if (abs(worldCoords.x) < axisThreshold) gridLines = min(gridLines, drawLine(worldCoords.y, u_lineWidth));
    if (abs(worldCoords.y) < axisThreshold) gridLines = min(gridLines, drawLine(worldCoords.x, u_lineWidth));

    // 4. Calcular a intensidade dos Eixos Principais (X=0 e Y=0)
    // Usa a coordenada do mundo bruta para detectar as linhas centrais
    float axes = max(drawLine(worldCoords.x, u_axisWidth), drawLine(worldCoords.y, u_axisWidth));

    // 5. Combinar as cores finais
    vec4 finalGrid = u_gridColor * gridLines;
    vec4 finalAxes = u_axisColor * axes;

    // Composição simples (os eixos ficam por cima da grade)
    // Usamos max() para garantir que a linha mais forte prevaleça sem somar alfa
    return max(finalGrid, finalAxes);
}