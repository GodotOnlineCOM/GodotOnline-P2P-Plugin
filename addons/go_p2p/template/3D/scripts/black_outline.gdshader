shader_type spatial;
render_mode unshaded, cull_disabled;

// Outline özellikleri
uniform vec4 outline_color : source_color = vec4(1.0, 0.8, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 0.2) = 0.02;
uniform float outline_brightness : hint_range(0.0, 5.0) = 1.5;

void vertex() {
    // Normal yönünde genişletme yaparak outline oluştur
    VERTEX += NORMAL * outline_width;
}

void fragment() {
    // Sadece outline rengini kullan
    ALBEDO = outline_color.rgb * outline_brightness;
    ALPHA = outline_color.a;
    
    // Işık hesaplamalarını devre dışı bırak
    METALLIC = 0.0;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}