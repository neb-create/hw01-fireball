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

uniform float u_Time;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

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

float fade(float t) {
    return t * t * t * (10.0 + t * ( -15.0 + t * 6.0));
}

float peak(float t) {
    return pow(4.0 * t * (1.0 - t), 2.0);
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

void main()
{
    // Material base color (before shading)
        vec4 diffuseColor = u_Color_Primary;

        vec3 perlin_in = vec3(fs_Pos.x + u_Time/200.0, fs_Pos.y + u_Time/300.0, fs_Pos.z);

        float perlin_influence = perlin3d(perlin_in * 4.0);
        perlin_influence = peak(perlin_influence);

        diffuseColor = mix(diffuseColor, , 1.0 - perlin_influence);

        // Calculate the diffuse term for Lambert shading
        float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
        // Avoid negative lighting values
        // diffuseTerm = clamp(diffuseTerm, 0, 1);

        float ambientTerm = 0.2;

        float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                            //to simulate ambient lighting. This ensures that faces that are not
                                                            //lit by our point light are not completely black.

        // Compute final shaded color
        out_Col = vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);
}
