#version 430 core

#define XGROUPSIZE  XGROUPSIZE_VAL
#define YGROUPSIZE  YGROUPSIZE_VAL
#define ZGROUPSIZE  ZGROUPSIZE_VAL

#define PI     3.1415926538

layout(local_size_x=XGROUPSIZE, local_size_y=YGROUPSIZE, local_size_z=ZGROUPSIZE) in;

// ---------------------------------------------------------------------------------------------------------------------

uniform int   SCREEN_WIDTH;
uniform int   SCREEN_HEIGHT;

uniform float time;
uniform int   delta_time;
uniform int   NB_BODY;

uniform float SPEED_RATE;
uniform float TURN_SPEED;
uniform float FADE_RATE;
uniform float DIFFUSE_RATE;

uniform float RANDOM_DIRECTION_STRENGTH;
uniform float SENSOR_ANGLE;
uniform float SENSOR_DIST;
uniform int   SENSOR_SIZE;
uniform float SENSOR_WEIGHT;
uniform vec3  COLOR;

layout(rgba8, binding = 0) uniform image2D out_texture;

// ---------------------------------------------------------------------------------------------------------------------

struct Body
{
    vec4 pos;  // x, y, z, w
    vec4 dat;  // angle, ID, nop, nop
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

float random_01(uint state)
{
    state ^= 2747636419u;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    return state / 4294967295;
}

// ---------------------------------------------------------------------------------------------------------------------

float clamp_01(float x)
{
    return max(0, min(1, x));
}

// ---------------------------------------------------------------------------------------------------------------------

void random_test()
{
    ivec2 tex_coord2 = ivec2(gl_GlobalInvocationID.x, gl_GlobalInvocationID.y);

    float c = random_01(gl_GlobalInvocationID.y * SCREEN_WIDTH + gl_GlobalInvocationID.x + int(time*10000));
    vec4 color = vec4(c, c, c, 1.0);
    imageStore(out_texture, tex_coord2, color);
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

// ---------------------------------------------------------------------------------------------------------------------

void fade()
{
    ivec2 tex_coord = ivec2(gl_GlobalInvocationID.xy);

    vec3 col = imageLoad(out_texture, tex_coord).rgb;

    float r = max(0, col.r - FADE_RATE * delta_time);
    float g = max(0, col.g - FADE_RATE * delta_time);
    float b = max(0, col.b - FADE_RATE * delta_time);

    imageStore(out_texture, tex_coord, vec4(r, g, b, 1.0));
}

// ---------------------------------------------------------------------------------------------------------------------

void blur()
{
    ivec2 tex_coord = ivec2(gl_GlobalInvocationID.xy);

    vec3 ori_col = imageLoad(out_texture, tex_coord).rgb;

    vec3 sum_col = vec3(0.0, 0.0, 0.0);

	for (int offset_x = -1; offset_x <= 1; offset_x ++) {
		for (int offset_y = -1; offset_y <= 1; offset_y ++) {
			int sample_x = min(SCREEN_WIDTH -1, max(0, tex_coord.x + offset_x));
            int sample_y = min(SCREEN_HEIGHT-1, max(0, tex_coord.y + offset_y));

            vec3 suround_col = imageLoad(out_texture, ivec2(sample_x, sample_y)).rgb;

            sum_col += suround_col;
		}
	}

    vec3 blur_col = sum_col / 9;

	float diffuse_weight = clamp_01(DIFFUSE_RATE * delta_time);

    blur_col = (ori_col * (1 - diffuse_weight)) + (blur_col * diffuse_weight);
    blur_col = blur_col - (FADE_RATE * delta_time);

    if (blur_col.r < 0) blur_col.r = 0;
    if (blur_col.g < 0) blur_col.g = 0;
    if (blur_col.b < 0) blur_col.b = 0;

    imageStore(out_texture, tex_coord, vec4(blur_col, 1.0));
}

// ---------------------------------------------------------------------------------------------------------------------

float sense(ivec2 body_pos, float body_angle, float sensor_angle)
{
	vec3 sense_weight  = vec3(SENSOR_WEIGHT, SENSOR_WEIGHT, SENSOR_WEIGHT);

    float sensor_total_angle = body_angle + sensor_angle;
	vec2 sensor_dir    = vec2(cos(sensor_total_angle), sin(sensor_total_angle));

    vec2 sensor_pos;
    sensor_pos.x = body_pos.x + sensor_dir.x * SENSOR_DIST;
    sensor_pos.y = body_pos.y + sensor_dir.y * SENSOR_DIST;

	vec2 sensor_center = vec2(int(sensor_pos.x), int(sensor_pos.y));

    float sum = 0;

	for (int offset_x = -SENSOR_SIZE; offset_x <= SENSOR_SIZE; offset_x ++) {
		for (int offset_y = -SENSOR_SIZE; offset_y <= SENSOR_SIZE; offset_y ++) {

            int sample_x = min(SCREEN_WIDTH  - 1, max(0, int(sensor_center.x) + offset_x));
			int sample_y = min(SCREEN_HEIGHT - 1, max(0, int(sensor_center.y) + offset_y));

            vec3 sense_col = imageLoad(out_texture, ivec2(sample_x, sample_y)).rgb;
			sum += dot(sense_weight, sense_col);
		}
	}

	return sum;
}

// ---------------------------------------------------------------------------------------------------------------------

void main()
{
    // Def: gl_GlobalInvocationID = gl_WorkGroupID * gl_WorkGroupSize + gl_LocalInvocationID
    uvec3 nb_particles = gl_NumWorkGroups * gl_WorkGroupSize;
    int id = int(gl_GlobalInvocationID.y * nb_particles.x + gl_GlobalInvocationID.x);
    //id = int(gl_GlobalInvocationID);
    //gl_LocalInvocationIndex

    //
    float weight_forward = sense( to_tex_coord(buf.bodies[id].pos.x, buf.bodies[id].pos.y), buf.bodies[id].dat.x, 0 );
    float weight_left    = sense( to_tex_coord(buf.bodies[id].pos.x, buf.bodies[id].pos.y), buf.bodies[id].dat.x, radians(SENSOR_ANGLE) );
    float weight_right   = sense( to_tex_coord(buf.bodies[id].pos.x, buf.bodies[id].pos.y), buf.bodies[id].dat.x, -radians(SENSOR_ANGLE) );

    float direction_strength = (0.5 - RANDOM_DIRECTION_STRENGTH/2) + RANDOM_DIRECTION_STRENGTH * random_01(gl_GlobalInvocationID.y * SCREEN_WIDTH + gl_GlobalInvocationID.x + int(time*10000));

    //if (weight_forward > weight_left && weight_forward > weight_right) {
	//}
    if (weight_forward < weight_left && weight_forward < weight_right) {
        buf.bodies[id].dat.x += (direction_strength - 0.5) * 2 * TURN_SPEED * delta_time;
        buf.bodies[id].dat.x += ((direction_strength + 0.5) * 2 - 1.0) * TURN_SPEED * delta_time;
    }
    // Turn right
    else if (weight_right > weight_left) {
        buf.bodies[id].dat.x -= direction_strength * TURN_SPEED * delta_time;
    }
    // Turn left
    else if (weight_left > weight_right) {
        buf.bodies[id].dat.x += direction_strength * TURN_SPEED * delta_time;
    }

    vec2 direction = vec2(cos(buf.bodies[id].dat.x), sin(buf.bodies[id].dat.x));

    buf.bodies[id].pos.x += direction.x * delta_time * SPEED_RATE;
    buf.bodies[id].pos.y += direction.y * delta_time * SPEED_RATE;

    clamp_pos(id);

    //random_test();

    imageStore(out_texture, to_tex_coord(buf.bodies[id].pos.x, buf.bodies[id].pos.y), vec4(COLOR, 1.0));
    blur();

    //memoryBarrierImage();
    memoryBarrier();
    barrier();
}