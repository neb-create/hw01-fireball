#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself

uniform float u_Time;

uniform float u_Setting_1;
uniform float u_Setting_2;

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out float fs_isSky;
out float fs_Dist;
out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Pos;

const vec4 lightPos = vec4(5, 4, 3, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.

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
float bias(float t, float b) {
    return t / ((((1.0 / b) - 2.0) * (1.0 - t)) + 1.0);
}
float gain(float t, float g) {
    if (t < 0.5)
        return bias(t * 2.0, g) * 0.5;
    else
        return bias(t * 2.0 - 1.0, 1.0 - g) * 0.5 + 0.5;
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



void main()
{

    fs_isSky = 0.0;
    if (length(vs_Pos) > 5.0) fs_isSky = 1.0;

    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation
   
    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.

    fs_Nor = u_ViewProj * fs_Nor;

    // First idea - distort the model in y-direction, with magnitute being similarity to up vector
    vec4 fire_dir = vec4(0., 1., 0., 0.);
    float fire_dir_similarity = (dot(fire_dir, vs_Nor) + 1.0) * 0.5;
    fire_dir_similarity = clamp(fire_dir_similarity, 0.0, 1.0);

    float displacement_speed = 0.2;
    float noise_scale = 2.0;

    vec3 noise_displacement = displacement_speed * vec3(0.02 * u_Time + 9.457, 0.01 * u_Time - 4.127, 0.03 * u_Time + 3.121);
    float fire_height = FBMperlin3D(noise_scale * vec3(vs_Pos) + noise_displacement, int(u_Setting_2));

    fire_height = bias(fire_height, 0.4);
    
    float fire_height_multiplier = 1.0 + u_Setting_1 * 0.5;
    float fire_height_base = u_Setting_1;

    float final_distorsion = ease_in_quadratic(fire_dir_similarity) * (fire_height_base + fire_height_multiplier * fire_height);
    fs_Dist = final_distorsion;

    vec4 modified_Pos = vs_Pos + final_distorsion * fire_dir;

    // Base
    fs_Pos = modified_Pos;
    vec4 modelposition = u_Model * modified_Pos;   // Temporarily store the transformed vertex positions for use below

    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies

    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}
