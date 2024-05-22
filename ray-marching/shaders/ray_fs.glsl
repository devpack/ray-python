#version 330 core

layout(location = 0) out vec4 fragColor;

uniform vec2  u_resolution;
uniform float u_time;
uniform int   u_frames;
uniform vec2  u_mouse;
uniform float u_scroll;

const bool ROTATE = false;

const int MAX_MARCHING_STEPS = 256;
const float MIN_DIST = 0.0;
const float MAX_DIST = 96.0;
const float EPSILON  = 0.001;
vec3 CAMERA_POS = vec3(0, 2, -3);
const float FOV = 1.0;
vec3 LIGHT_POS  = vec3(0, 5, 2);

const float PI  = acos(-1.0);
const float TAU = (2*PI);
const float PHI = (sqrt(5)*0.5 + 0.5);

// ------------------------------------------------------------------------------------------------

mat2 rot2D(float a) {
    float ca = cos(a);
    float sa = sin(a);
    return mat2(ca, -sa, sa, ca);
}

vec2 rotate2D(vec2 p, float a) {
    float s = sin(a) + u_scroll;
    float c = cos(a);
    return mat2(c, -s, s, c) * p;
}

void rotate(inout vec3 p) {
    p.xy *= rot2D(sin(u_time * 0.8) * 1.5);
    p.yz *= rot2D(sin(u_time * 0.7) * 1.2);
}

// ------------------------------------------------------------------------------------------------

float intersectSDF(float distA, float distB) {
    return max(distA, distB);
}

float unionSDF(float distA, float distB) {
    return min(distA, distB);
}

float differenceSDF(float distA, float distB) {
    return max(distA, -distB);
}

// the sign dist field returns the shortest dist to the object
float dist_torus(vec3 p) {
    float dist = length(vec2(length(p.xy) - 0.6, p.z)) - 0.22;
    return dist * 0.7;
}

float dist_plane(vec3 p, float h) {
    return p.y -h;
}

float dist_sphere(vec3 p, vec3 pos) {
    return length(p - pos) - 1;
}

float dist_cube( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;

  return length(max(q, 0.0)) + min(max(q.x,max(q.y,q.z)), 0.0);
}

float sceneSDF(vec3 p)
{
    float dt = dist_torus(p);

    float dp = dist_plane(p, -1.0);
	float ds = dist_sphere(p, vec3(-3.0, 0.0, 0.0));
    float dc = dist_cube(p, vec3(1, 1, 1));
    return unionSDF(ds, unionSDF(dp, dc));
}

// ------------------------------------------------------------------------------------------------
// the gradiant is more or less the same as the normal of the object on that point

vec3 get_normal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
}

// ------------------------------------------------------------------------------------------------
// Return the shortest distance from the camera (eye) to the scene surface along the marching direction

float shortest_distance_to_surface(vec3 eye, vec3 marching_direction, float start, float end) {
    float depth = start;

    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        vec3 pos_along_ray = eye + depth * marching_direction;

        if(ROTATE) rotate(pos_along_ray);

        float dist = sceneSDF(pos_along_ray);

        if (dist < EPSILON) {
			return depth;
        }
        depth += dist;
        if (depth >= end) {
            return end;
        }
    }

    return end;
}

// ------------------------------------------------------------------------------------------------

vec3 get_light(vec3 p, vec3 rd, vec3 color) {

    vec3 light2Pos = vec3(1.0 * sin(0.37 * u_time),
                          1.0 * cos(0.37 * u_time),
                          1.0);// * LIGHT_POS;

    light2Pos = LIGHT_POS;

    vec3 L = normalize(light2Pos - p);
    vec3 N = get_normal(p);
    vec3 V = -rd;
    vec3 R = reflect(-L, N);

    vec3 specColor = vec3(0.5);
    vec3 specular  = specColor * pow(clamp(dot(R, V), 0.0, 1.0), 10.0);
    vec3 diffuse   = color * clamp(dot(L, N), 0.0, 1.0);
    vec3 ambient   = color * 0.05;
    vec3 fresnel   = 0.25 * color * pow(1.0 + dot(rd, N), 3.0);

    // shadows
    if(true) {
        float d = shortest_distance_to_surface(p + N * 0.02, normalize(light2Pos), MIN_DIST, MAX_DIST);
        if (d < length(light2Pos - p)) return ambient + fresnel;
    }

    return diffuse + ambient + specular + fresnel;
}

// ------------------------------------------------------------------------------------------------

// Rotate around a coordinate axis (i.e. in a plane perpendicular to that axis) by angle <a>.
// Read like this: R(p.xz, a) rotates "x towards z".
// This is fast if <a> is a compile-time constant and slower (but still practical) if not.

void pR(inout vec2 p, float a) {
	p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

void mouseControl(inout vec3 ro) {
    vec2 m = u_mouse / u_resolution;
    pR(ro.yz, m.y * PI * 0.4 - 0.4);
    pR(ro.xz, m.x * TAU);
}

// ------------------------------------------------------------------------------------------------

mat3 getCam(vec3 eye, vec3 target) {
    vec3 fwd   = normalize(vec3(target - eye));
    vec3 right = normalize(cross(vec3(0, 1, 0), fwd));
    vec3 up    = cross(fwd, right);

    return mat3(right, up, fwd);
}

// ------------------------------------------------------------------------------------------------
// https://www.shadertoy.com/view/Xtd3z7
// https://github.com/StanislavPetrovV/Procedural-3D-scene-Ray-Marching/blob/main/programs/fragment.glsl

void main() {
    vec2 uv = (gl_FragCoord.xy * 2. - u_resolution.xy) / u_resolution.y; // (0,0) at the center of the screen X and Y in [-1, 1]

    //vec2 uv0 = uv;                                // svg distance to the scene (original distance to the center of the canvas)
    //uv = fract(uv*2) - 0.5;                       // repeat the screne

    vec3 eye    = CAMERA_POS;                   // ray origin vec3(0, 0, -3);

    mouseControl(eye);

    vec3 target = vec3(0, 0, 0);

    vec3 fwd    = normalize(target - eye);
    vec3 side   = normalize(cross(vec3(0, 1, 0), fwd));
    vec3 up     = cross(fwd, side);
    
    vec3 screen_pos = eye + (fwd + side * uv.x + up * uv.y);
    vec3 rd = normalize(screen_pos - eye); // <=> vec3 rd = getCam(eye, target) * normalize(vec3(uv, FOV));
    //vec3 rd = normalize(vec3(uv, 1));

    float dist = shortest_distance_to_surface(eye, rd, MIN_DIST, MAX_DIST);

    vec3 col = vec3(0);
    vec3 background = vec3(0.5, 0.8, 0.9);

    // ray hit something => color it
    if(dist < MAX_DIST) {
        vec3 pos_along_ray = eye + dist * rd;

        vec3 material = vec3(0.4, 0.6, 1.0);
        col += material;

        if(ROTATE) rotate(pos_along_ray);

        col += get_light(pos_along_ray, rd, material);
        //col = mix(col, background, 1.0 - exp(-0.00002 * dist * dist));

        // rotate(pos_along_ray);
        // vec3 normal = get_normal(pos_along_ray) ;

        // // shading
        // float diff = 0.7 * max(0.0, dot(normal, -rd));
        // vec3 ref = reflect(rd, normal);
        // float spec = max(0.0, pow(dot(ref, -rd), 128.0));
        // col += (spec + diff); // * res.rgb;

        // col += normal * 0.5 + 0.5;
        // //col += dist;
    }

    // gamma
    //col = pow(col, vec3(0.4545));

    if(false) {
        col = vec3(dist * .2);              // color based on distance
        //fragColor = vec4(uv, 0, 1);
    }

    fragColor = vec4(col, 1);               // out pixel color
}