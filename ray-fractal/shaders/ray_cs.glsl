#version 430 core

#define XGROUPSIZE  XGROUPSIZE_VAL
#define YGROUPSIZE  YGROUPSIZE_VAL
#define ZGROUPSIZE  ZGROUPSIZE_VAL

// Number of threads/invocation (per WorkGroup): XGROUPSIZE * YGROUPSIZE * ZGROUPSIZE
layout(local_size_x=XGROUPSIZE, local_size_y=YGROUPSIZE, local_size_z=ZGROUPSIZE) in;
//layout(local_size_x = 8, local_size_y = 8) in;

layout(rgba32f, binding = 0) uniform image2D out_texture;
//layout(rgba8, binding = 1) uniform image2D out_texture2;

uniform int   SCREEN_WIDTH;
uniform int   SCREEN_HEIGHT;

uniform float time;
uniform int   delta_time;

// ---------------------------------------------------------------------------------------------------------------------

struct Body
{
    vec4 pos;  // x, y, z, w
};

layout(std430, binding = 0) buffer bodies_in
{
    Body bodies[];
} buf;

// ---------------------------------------------------------------------------------------------------------------------

ivec2 to_tex_coord(float posx, float posy) {
    return ivec2( ((posx+1.0)/2.0) * SCREEN_WIDTH, ((posy+1.0)/2.0) * SCREEN_HEIGHT );
}

// ---------------------------------------------------------------------------------------------------------------------

void clamp_pos(int id)
{
    if(buf.bodies[id].pos.x > 1.0) {
        buf.bodies[id].pos.x = -1.0;
    }
    else if (buf.bodies[id].pos.x < -1.0) {
        buf.bodies[id].pos.x = 1.0;
    }
    if(buf.bodies[id].pos.y > 1.0) {
        buf.bodies[id].pos.y = -1.0;
    }
    else if (buf.bodies[id].pos.y < -1.0) {
        buf.bodies[id].pos.y = 1.0;
    }
}

void fade(ivec2 tex_coord, float fade_rate)
{
    vec3 col = imageLoad(out_texture, tex_coord).rgb;

    float r = max(0, col.r - fade_rate * delta_time);
    float g = max(0, col.g - fade_rate * delta_time);
    float b = max(0, col.b - fade_rate * delta_time);

    imageStore(out_texture, tex_coord, vec4(r, g, b, 1.0));
}

// ---------------------------------------------------------------------------------------------------------------------

void main()
{
    // Def: gl_GlobalInvocationID = gl_WorkGroupID * gl_WorkGroupSize + gl_LocalInvocationID
    uvec3 nb_particles = gl_NumWorkGroups * gl_WorkGroupSize;
    int id = int(gl_GlobalInvocationID.y * nb_particles.x + gl_GlobalInvocationID.x);

    //id = int(gl_GlobalInvocationID);
    //gl_LocalInvocationIndex

    // 1. Uniform color output
    //ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    //vec3 pixel = vec3(1.0, 0.0, 0.0);
    //imageStore(out_texture, pixel_coords, vec4(pixel,1.0));

    float SPEED_RATE = 0.0001;
    float FADE_RATE = 0.001;

    buf.bodies[id].pos.x += delta_time * SPEED_RATE;
    buf.bodies[id].pos.y += delta_time * SPEED_RATE;

    clamp_pos(id);

    fade(ivec2(gl_GlobalInvocationID.xy), FADE_RATE);
    vec4 color = vec4(1.0);    
    imageStore(out_texture, to_tex_coord(buf.bodies[id].pos.x, buf.bodies[id].pos.y), color);

    //memoryBarrierImage();
    //memoryBarrier();
    //barrier();
}