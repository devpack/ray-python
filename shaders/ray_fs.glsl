#version 330 core

layout(location = 0) out vec4 fragColor;

uniform vec2 u_resolution;
uniform float u_time;
uniform int u_frames;
uniform vec2 u_mouse;
uniform float u_scroll;

const int MAX_STEPS = 256;
const float MAX_DIST = 100.0;
const float EPSILON = 0.0001;
vec3 CAMERA_POS = vec3(0, 0, -1);
const float PI = acos(-1.0);


// Return random noise in the range [0.0, 1.0], as a function of x.
float Noise2d( in vec2 x )
{
    float xhash = cos( x.x * 37.0 );
    float yhash = cos( x.y * 57.0 );
    return fract( 415.92653 * ( xhash + yhash ) );
}

// Convert Noise2d() into a "star field" by stomping everthing below fThreshhold to zero.
float NoisyStarField( in vec2 vSamplePos, float fThreshhold )
{
    float StarVal = Noise2d( vSamplePos );
    if ( StarVal >= fThreshhold )
        StarVal = pow( (StarVal - fThreshhold)/(1.0 - fThreshhold), 6.0 );
    else
        StarVal = 0.0;
    return StarVal;
}

// Stabilize NoisyStarField() by only sampling at integer values.
float StableStarField( in vec2 vSamplePos, float fThreshhold )
{
    // Linear interpolation between four samples.
    // Note: This approach has some visual artifacts.
    // There must be a better way to "anti alias" the star field.
    float fractX = fract( vSamplePos.x );
    float fractY = fract( vSamplePos.y );
    vec2 floorSample = floor( vSamplePos );    
    float v1 = NoisyStarField( floorSample, fThreshhold );
    float v2 = NoisyStarField( floorSample + vec2( 0.0, 1.0 ), fThreshhold );
    float v3 = NoisyStarField( floorSample + vec2( 1.0, 0.0 ), fThreshhold );
    float v4 = NoisyStarField( floorSample + vec2( 1.0, 1.0 ), fThreshhold );

    float StarVal =   v1 * ( 1.0 - fractX ) * ( 1.0 - fractY )
        			+ v2 * ( 1.0 - fractX ) * fractY
        			+ v3 * fractX * ( 1.0 - fractY )
        			+ v4 * fractX * fractY;
	return StarVal;
}


#define STARDISTANCE 150.
#define STARBRIGHTNESS 0.5
#define STARDENSITY 0.05

float hash13_b(vec3 p3)
{
	p3  = fract(p3 * vec3(.1031,.11369,.13787));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

float stars(vec3 ray)
{
    vec3 p = ray * STARDISTANCE;
    float h = hash13_b(p);
    float flicker = cos(u_time * 1. + hash13_b(abs(p) * 0.01) * 13.) * 0.5 + 0.5;
    float brigtness = smoothstep(1.0 - STARDENSITY, 1.0, hash13_b(floor(p)));
    return smoothstep(STARBRIGHTNESS, 0., length(fract(p) - 0.5)) * brigtness * flicker;
}

vec3 camera(vec2 fragCoord)
{
	vec3 ray = normalize(vec3( fragCoord - u_resolution.xy*.5, u_resolution.x));
    vec2 angle = vec2(3. + u_time * -0.01, 10. + u_time * 0.10);
    vec4 cs = vec4(cos(angle.x), sin(-angle.x), cos(angle.y), sin(angle.y));
    ray.yz *= mat2(cs.xy,-cs.y,cs.x); 
    ray.xz *= mat2(cs.zw,-cs.w,cs.z); 
    return ray;
}

// ------------------------------------------------------------------------------------------------

void main_test() {

    // ShaderToy
    // uniform vec3      iResolution;           // viewport resolution (in pixels)
    // uniform float     iTime;                 // shader playback time (in seconds)
    // uniform float     iTimeDelta;            // render time (in seconds)
    // uniform float     iFrameRate;            // shader frame rate
    // uniform int       iFrame;                // shader playback frame
    // uniform float     iChannelTime[4];       // channel playback time (in seconds)
    // uniform vec3      iChannelResolution[4]; // channel resolution (in pixels)
    // uniform vec4      iMouse;                // mouse pixel coords. xy: current (if MLB down), zw: click
    // uniform samplerXX iChannel0..3;          // input channel. XX = 2D/Cube
    // uniform vec4      iDate;                 // (year, month, day, time in seconds)
    // uniform float     iSampleRate;           // sound sample rate (i.e., 44100)
                

    if(false) {
        vec2 uv = (gl_FragCoord.xy-u_resolution.xy*.5)/u_resolution.y;

        vec3 ray = camera(gl_FragCoord.xy);
        float s = stars(ray);
        fragColor = vec4(s, s ,s ,1.0);

    }
    else {
        // Sky Background Color
        vec3 vColor = vec3( 0.1, 0.2, 0.4 ) * gl_FragCoord.y / u_resolution.y;

        // Note: Choose fThreshhold in the range [0.99, 0.9999].
        // Higher values (i.e., closer to one) yield a sparser starfield.
        float StarFieldThreshhold = 0.97;

        // Stars with a slow crawl.
        float xRate = 0.2;
        float yRate = -0.06;
        vec2 vSamplePos = gl_FragCoord.xy + vec2( xRate * float( u_frames ), yRate * float( u_frames ) );
        float StarVal = StableStarField( vSamplePos, StarFieldThreshhold );
        vColor += vec3( StarVal );
        
        fragColor = vec4(vColor, 1.0);

    }

    if (false) {
        //vec2 uv = gl_FragCoord.xy - 0.5 * u_resolution.xy;
        vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / (u_resolution.xy / 2.0);

        fragColor = vec4(uv.x, uv.y, 0.0 ,1.0);
        
        if (length(uv) < 1.0) {
            fragColor = vec4(1.0, 1.0, 1.0 ,1.0);
        }
    }
}

// ------------------------------------------------------------------------------------------------

void basic() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;
    vec3 col = vec3(0.0);

    //col += 0.1 / length(uv);
    //col += length(uv);

    uv = step(0, uv);
    col = vec3(uv, 0);
    
    fragColor = vec4(col, 1.0);
}

// ------------------------------------------------------------------------------------------------

bool isPrime(int n) {
    if (n == 2) return true;
    if (n < 2 || n % 2 == 0) return false;
    for (int i = 3; i <= int(sqrt(float(n))); i += 2) {
        if (n % i == 0) return false;
    }
    return true;
}

bool isTwinPrime(int n1, int n2) {
    if( isPrime(n1) && isPrime(n2) ) {
        return true;
    }
    else {
        return false;
    }
}

vec3 hash31(float p) {
   vec3 p3 = fract(vec3(p) * vec3(0.1031, 0.1030, 0.0973));
   p3 += dot(p3, p3.yzx + 33.33);
   return fract((p3.xxy + p3.yzz)*p3.zyx) + 0.25;
}

void prime() {
    //float zoom = sin(u_time * 0.2) * 0.2 + 0.3;
    //vec2 uv = gl_FragCoord.xy * zoom + 30.0 * u_time;
    vec3 color = vec3(0);

    //int num = int(uv.x) | int(uv.y);
    //if (isPrime(num)) color += hash31(num);
    //if (isTwinPrime(num, num + 2))
        //color += hash31(num);
        //color.g += 1.0;

    if(false) {
         vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

        if (uv.x == 0 && uv.y == 0)
            color = vec3(1);

        float lv = length(uv);
        color = vec3(lv, lv, lv);
        fragColor = vec4(color, 1.0);
    }
    else {
        float zoom = 1.0;
        zoom = u_time * 0.1;
        vec2 uv = gl_FragCoord.xy * zoom; // u.x: 0 <= gl_FragCoord.x <= u_resolution.x (SCREEN_WIDTH)
        //vec2 uv = gl_FragCoord.xy / u_resolution.xy; // [0, 1]

        //float lv = length(uv);
        //color = vec3(lv, lv, lv);

        //if (int(uv.x) == 0 && int(uv.y) == 0)
        //    color = vec3(1.0, 1.0, 1.0);

        int num = int(uv.x) + (int(uv.y) * int(u_resolution.x));

        //num = int(uv.y) ^ int(uv.x);
        //num = int(uv.y) | int(uv.x) ;

        if (isPrime(num))
            color = vec3(0.0, 1.0, 0.0);

        fragColor = vec4(color, 1.0);
    }
}

void prime2() {
    float zoom = u_mouse.x / u_resolution.x;
    vec2 uv = (floor(gl_FragCoord.xy) - floor(0.5 * u_resolution.xy)) * zoom ;

    vec3 color = vec3(0);

    uv.y += floor(u_resolution.y * 0.5);
    //int num = int(uv.y) * int(u_resolution.x) + int(uv.x);
    int num = int(uv.y) ^ int(uv.x);

    //if (isTwinPrime(num, num+2))
    if (isPrime(num))
        color.g += 1.0;

    fragColor = vec4(color, 1.0);
}


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

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.xxy + p.yxx) * p.zyx);
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

vec2 hash12(float t) {
    float x = fract(sin(t * 3453.329));
    float y = fract(sin((t + x) * 8532.732));
    return vec2(x, y);
}

void cardio() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;
    vec3 col = vec3(0.0);

    uv = rotate2D(uv, 3.14 / 2.0);

    float r = 0.17;
    for (float i=0.0; i < 60.0; i++) {
        float factor = (sin(u_time) * 0.5 + 0.5) + 0.3;
        i += factor;

        float a = i / 3;
        float dx = 2 * r * cos(a) - r * cos(2 * a);
        float dy = 2 * r * sin(a) - r * sin(2 * a);

        col += 0.013 * factor / length(uv - vec2(dx + 0.1, dy) - 0.02 * hash12(i));
    }
    col *= sin(vec3(0.2, 0.8, 0.9) * u_time) * 0.15 + 0.25;

    fragColor = vec4(col, 1.0);
}

// --------------------------------------------------------------------------------------------------------------------------
// RAY MARCHING
// --------------------------------------------------------------------------------------------------------------------------

// the sign dist field returns the shortest dist to the object
float calc_dist(vec3 p) {

    // torus
    float dist = length(vec2(length(p.xy) - 0.6, p.z)) - 0.22;
    return dist * 0.7;

    // sphere
    return length(p) - 0.5;
}

float getAO(vec3 pos, vec3 norm) {
    // float AO_SAMPLES = 10.0;
    // float AO_FACTOR = 1.0;
    // float result = 1.0;
    // float s = -AO_SAMPLES;
    // float unit = 1.0 / AO_SAMPLES;
    // for (float i = unit; i < 1.0; i += unit) {
    //     result -= pow(1.6, i * s) * (i - calc_dist(pos + i * norm).w);
    // }
    // return result * AO_FACTOR;
    return 1.;
}

void rotate(inout vec3 p) {
    p.xy *= rot2D(sin(u_time * 0.8) * 0.25);
    p.yz *= rot2D(sin(u_time * 0.7) * 0.2);
}

// the gradiant of the distance field is the same as the normal of the object on that point
vec3 get_normal(vec3 p) {
    vec2 e = vec2(0.01, 0.0);
    vec3 n = vec3(calc_dist(p)) - vec3(calc_dist(p - e.xyy), calc_dist(p - e.yxy), calc_dist(p - e.yyx));
    return normalize(n);
}

// void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
float ray_march(vec3 ray_origin, vec3 ray_direction) {
    float total_distance = 0.;                   // total distance travelled

    // march
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 pos_along_ray = ray_origin + ray_direction * total_distance; // position along the ray

        rotate(pos_along_ray);

        float cur_dist = calc_dist(pos_along_ray);  // if fract() used d = local distance relative to the center of each repetion (vs original distance to the center of the canvas)

        total_distance += cur_dist;                 // march the ray

        // stop if close enough or too far
        if (abs(cur_dist) < EPSILON || total_distance > MAX_DIST) 
            break;    
    }

    return total_distance;
}

void main_raymarch() {
    vec2 uv = (gl_FragCoord.xy * 2. - u_resolution.xy) / u_resolution.y; // (0,0) at the center of the screen X and Y in [-1, 1]

    vec3 col = vec3(0);                           // final pixel color

    //vec2 uv0 = uv;                              // svg distance to the scene (original distance to the center of the canvas)
    //uv = fract(uv*2) - 0.5;                     // repeat the screne

    vec3 ray_origin = CAMERA_POS;                // ray origin vec3(0, 0, -3);
    vec3 ray_direction = normalize(vec3(uv, 1)); // ray direction

    float dist = ray_march(ray_origin, ray_direction);

    if(dist < 100.) {
        vec3 pos_along_ray = ray_origin + dist * ray_direction;
        rotate(pos_along_ray);
        vec3 normal = get_normal(pos_along_ray) ;

        // shading
        float diff = 0.7 * max(0.0, dot(normal, -ray_direction));
        vec3 ref = reflect(ray_direction, normal);
        float spec = max(0.0, pow(dot(ref, -ray_direction), 128.0));
        float ao = getAO(pos_along_ray, normal);
        col += (spec + diff) * ao; // * res.rgb;
        //col += diff * ao; // * res.rgb;

        col += normal * 0.5 + 0.5;
        //col += dist;
    }

    if(false) {
        col = vec3(dist * .2);             // color based on distance
        //fragColor = vec4(uv, 0, 1);
    }

    fragColor = vec4(col, 1);                   // out pixel color
}

// ------------------------------------------------------------------------------------------------

void main() {
    main_raymarch();

    //main_test();
    //basic();
    //prime();
    //cardio();
}