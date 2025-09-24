#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color_Primary;
uniform vec4 u_Color_Secondary; // The color with which to render this instance of geometry.

uniform vec4 u_Eye;

uniform float u_Time;
uniform float u_Res;

uniform float u_Setting_3;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in float fs_isSky;
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;
in float fs_Dist;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.


// Toolbox functions (From lecture slides)
float ease_linear(float t, float b, float c, float d) {
    return c * (t / d) + b;
}
float ease_in_quadratic(float t) {
    return t * t;
}
float ease_out_quadratic(float t) {
    return 1.0 - ease_in_quadratic(1.0 - t);
}
float ease_in_out_quadratic(float t) {
    if (t < 0.5)
        return ease_in_quadratic(t * 2.0) / 2.0;
    else
        return 1.0 - ease_in_quadratic((1.0 - t) * 2.0) / 2.0;
}
float smootherstep(float edge0, float edge1, float x) {
    // Scale, clamp x to 0..1 range
    x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    // Evaluate polynomial
    return x * x * x * (x * (x * 6. - 15.) + 10.);
}
float bias(float b, float t) {
    return pow(t, log(b) / log(0.5));
}
float gain(float g, float t) {
    if (t < 0.5)
        return bias(1.0 - g, 2.0 * t) / 2.0;
    else
        return 1.0 - bias(1.0 - g, 2.0 - 2.0 * t) / 2.0;
}
float square_wave(float x, float freq, float amplitude) {
    return abs(mod(floor(x * freq), 2.0)) * amplitude;
}
float sawtooth_wave(float x, float freq, float amplitude) {
    return (x * freq - floor(x * freq)) * amplitude;
}
float triangle_wave(float x, float freq, float amplitude) {
    return abs(mod(x * freq, amplitude) - (0.5 * amplitude));
}
float cubicPulse(float c, float w, float x) {
    x = abs(x - c);
    if (x > w) return 0.0;
    x /= w;
    return 1.0 - x * x * (3.0 - 2.0 * x);
}
float fade(float t) {
    return t * t * t * (10.0 + t * ( -15.0 + t * 6.0));
}
float peak(float t) {
    return pow(4.0 * t * (1.0 - t), 2.0);
}

// Noise functions
vec3 grad3d(float x, float y, float z)
{
    float pi = 3.14159265;
    float f = fract(sin(dot(vec3(x,y,z), vec3(127.1,311.7,74.7))) * 43758.5453);
    float theta = f * 2.0 * pi;
    float phi = f * pi;
    float gx = sin(phi) * cos(theta);
    float gy = sin(phi) * sin(theta);
    float gz = cos(phi);
    return vec3(gx, gy, gz);
}
float perlin3d(vec3 pos) {

    vec3 p0 = floor(pos);
    vec3 p1 = p0 + vec3(1.0);

    vec3 d000 = pos - vec3(p0.x, p0.y, p0.z);
    vec3 d100 = pos - vec3(p1.x, p0.y, p0.z);
    vec3 d010 = pos - vec3(p0.x, p1.y, p0.z);
    vec3 d110 = pos - vec3(p1.x, p1.y, p0.z);
    vec3 d001 = pos - vec3(p0.x, p0.y, p1.z);
    vec3 d101 = pos - vec3(p1.x, p0.y, p1.z);
    vec3 d011 = pos - vec3(p0.x, p1.y, p1.z);
    vec3 d111 = pos - vec3(p1.x, p1.y, p1.z);

    float n000 = dot(grad3d(p0.x,p0.y,p0.z), d000);
    float n100 = dot(grad3d(p1.x,p0.y,p0.z), d100);
    float n010 = dot(grad3d(p0.x,p1.y,p0.z), d010);
    float n110 = dot(grad3d(p1.x,p1.y,p0.z), d110);
    float n001 = dot(grad3d(p0.x,p0.y,p1.z), d001);
    float n101 = dot(grad3d(p1.x,p0.y,p1.z), d101);
    float n011 = dot(grad3d(p0.x,p1.y,p1.z), d011);
    float n111 = dot(grad3d(p1.x,p1.y,p1.z), d111);

    vec3 f = fract(pos);
    float tx = fade(f.x);
    float ty = fade(f.y);
    float tz = fade(f.z);

    float nx00 = mix(n000, n100, tx);
    float nx01 = mix(n001, n101, tx);
    float nx10 = mix(n010, n110, tx);
    float nx11 = mix(n011, n111, tx);

    float nxy0 = mix(nx00, nx10, ty);
    float nxy1 = mix(nx01, nx11, ty);

    float nxyz = mix(nxy0, nxy1, tz);

    return nxyz;

}
float FBMperlin3D(vec3 pos, int octaves) {
    
    float sum = 0.0;
    float persistence = 1.0 / 2.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float maxAmp = 0.0;

    for (int i = 0; i < octaves; ++i) {
        maxAmp += amplitude;
        sum += amplitude * perlin3d(frequency * pos);

        frequency *= 2.0;
        amplitude *= persistence;

    }

    return sum / maxAmp;
}

// My helpers
float similarity(vec3 dir_in, vec3 dir_targ) {
    return 0.5 * dot(normalize(dir_in), normalize(dir_targ)) + 0.5;
}

void main()
{

    vec4 fs_Nor_modified = fs_Nor;
    fs_Nor_modified.x *= u_Res;
    // Get similarity
    float fire_dir_similarity = similarity(vec3(fs_Nor_modified), vec3(0.0, 1.0, 0.0));
    float eye_dir_similarity = similarity(vec3(fs_Nor_modified),(vec3(0.0, 0.0, 1.0)));

    // Material base color (before shading)
    vec4 diffuseColor = u_Color_Primary;

    float noise_base_scale = 1.0;
    vec3 perlin_in = noise_base_scale * vec3(fs_Pos);

    float perlin_influence = FBMperlin3D(perlin_in, 1);

    float mix_param = clamp(fs_Dist * 4.0 + fire_dir_similarity * 0.3 + perlin_influence * 0.5, 0.0, 2.0);

    diffuseColor = mix(diffuseColor, u_Color_Secondary, 1.0 - mix_param);





    // LIGHT PART
    // Calculate the diffuse term for Lambert shading
    float diffuseTerm;
    //diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
    float displacement_correction = clamp(fs_Dist * 0.3, 0.0, 1.0);
    float light_term = eye_dir_similarity + 0.5 *displacement_correction;


    float core_size = u_Setting_3 * 1.4;

    float core_e0 = 0.06 * core_size;
    float core_e1 = 0.07 * core_size;
    float core_e2 = 0.15 * core_size;

    if (light_term < core_e1) {

        if (light_term < core_e0) {
            diffuseTerm = smoothstep(0.0, core_e0, light_term) * -0.2 + 0.2;
        } else {
            diffuseTerm = 0.0;
        }
        
    } else if (light_term > core_e2) {
        diffuseTerm = 1.0;
    } else {
        diffuseTerm = smootherstep(core_e1, core_e2, light_term)* 1.0;
    }
    
    diffuseColor = mix(diffuseColor, u_Color_Primary * 2.0, 1.0 - diffuseTerm);
    
    
    // Avoid negative lighting values
    diffuseTerm = clamp(diffuseTerm, 0.0, 1.0);

    float ambientTerm = 0.4;

    float lightIntensity = 1.0;   //Add a small float value to the color multiplier
                                                        //to simulate ambient lighting. This ensures that faces that are not
                                                        //lit by our point light are not completely black.
    float border_len = 0.55 * u_Setting_3;
    if (eye_dir_similarity - 0.5 * displacement_correction > 0.5 - border_len && eye_dir_similarity - 0.5 * displacement_correction < 0.5 + border_len) lightIntensity = 2.0;
    lightIntensity = clamp(lightIntensity, 0.0, 2.0);
    
    // Debug part

    // Compute final shaded color
    out_Col = vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);

    if (fs_isSky == 1.0) {
        out_Col = vec4(diffuseColor.rgb / 4.0, diffuseColor.a);
    } else {
        out_Col = vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);
    }
}
