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

ivec2 to_tex_coord(float posx, float posy) {
    return ivec2( ((posx+1.0)/2.0) * SCREEN_WIDTH, ((posy+1.0)/2.0) * SCREEN_HEIGHT );
}

// ---------------------------------------------------------------------------------------------------------------------

void main()
{
    // Def: gl_GlobalInvocationID = gl_WorkGroupID * gl_WorkGroupSize + gl_LocalInvocationID
    //uvec3 nb_particles = gl_NumWorkGroups * gl_WorkGroupSize;
    //int id = int(gl_GlobalInvocationID.y * nb_particles.x + gl_GlobalInvocationID.x);
    //id = int(gl_GlobalInvocationID);
    //gl_LocalInvocationIndex

    // 1. Uniform color output
    // ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    // vec3 pixel = vec3(1.0, 0.0, 0.0);
    // imageStore(out_texture, pixel_coords, vec4(pixel,1.0));

    
    // ivec2 tex_coord2 = ivec2(gl_GlobalInvocationID.xy);
    // float local = 1 - length(vec2(ivec2(gl_LocalInvocationID.xy) - XGROUPSIZE/2) / XGROUPSIZE/2);
    // float global = sin(float(gl_WorkGroupID.x + gl_WorkGroupID.y) * 0.1 + time) / 2.0 + 0.5;
    // vec4 color = vec4(local, global, 0.0, 1.0);
    // imageStore(out_texture, tex_coord2, color);

	vec4 pixel = vec4(0.075, 0.133, 0.173, 1.0);
	ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
	
	ivec2 dims = imageSize(out_texture);
	float x = -(float(pixel_coords.x * 2 - dims.x) / dims.x); 
	float y = -(float(pixel_coords.y * 2 - dims.y) / dims.x); // .y

	//float fov = 90.0;
	//vec3 cam_o = vec3(0.0, 0.0, -tan(fov / 2.0));
	vec3 cam_o = vec3(0.0, 0.0, -1);
	vec3 ray_o = vec3(x, y, 0.0);
	vec3 ray_d = normalize(ray_o - cam_o);

	vec3 sphere_c = vec3(0.0, 0.0, -5.0);
	float sphere_r = 1.0;

	vec3 o_c = ray_o - sphere_c;
	float b = dot(ray_d, o_c);
	float c = dot(o_c, o_c) - sphere_r * sphere_r;
	float intersectionState = b * b - c;
	vec3 intersection = ray_o + ray_d * (-b + sqrt(b * b - c));

	if (intersectionState >= 0.0)
	{
		pixel = vec4((normalize(intersection - sphere_c) + 1.0) / 2.0, 1.0);
	}

	imageStore(out_texture, pixel_coords, pixel);

    //memoryBarrierImage();
    //memoryBarrier();
    //barrier();
}