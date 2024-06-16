import sys, argparse, random

import pygame as pg
import numpy as np
import moderngl as mgl
import glm
from array import array

from config import *
from shader_program import ShaderProgram

# -----------------------------------------------------------------------------------------------------------

class App:

    def __init__(self, screen_width=SCREEN_WIDTH, screen_height=SCREEN_HEIGHT, fps=-1, record_video="", video_fps=60):

        self.screen_width = screen_width
        self.screen_height = screen_height
        self.max_fps = fps

        self.record_video = record_video
        self.video_fps = video_fps

        if self.record_video:
            if self.record_video in ("XVID", "h264", "avc1", "mp4v"):
                self.video_recorder = ScreenRecorder(self.screen_width, self.screen_height, self.video_fps, codec=self.record_video)
            else:
                self.video_recorder = ScreenRecorder(self.screen_width, self.screen_height, self.video_fps)

        #
        print("SCREEN WIDTH =", SCREEN_WIDTH)
        print("SCREEN HEIGHT=", SCREEN_HEIGHT)

        print("X LOCAL  GROUPSIZE=", XGROUPSIZE)
        print("Y LOCAL  GROUPSIZE=", YGROUPSIZE)
        print("Z LOCAL  GROUPSIZE=", ZGROUPSIZE)
        print("X GLOBAL GROUPSIZE=", SCREEN_WIDTH // XGROUPSIZE)
        print("Y GLOBAL GROUPSIZE=", SCREEN_HEIGHT // YGROUPSIZE)
        print("Z GLOBAL GROUPSIZE=", 1)

        #
        self.lastTime = time.time()
        self.currentTime = time.time()
        self.pause = False

        self.fps = FPSCounter()

        # pygame init
        pg.init()

        pg.display.gl_set_attribute(pg.GL_CONTEXT_MAJOR_VERSION, 4)
        pg.display.gl_set_attribute(pg.GL_CONTEXT_MINOR_VERSION, 3)
        pg.display.gl_set_attribute(pg.GL_CONTEXT_PROFILE_MASK, pg.GL_CONTEXT_PROFILE_CORE)

        pg_flags = pg.OPENGL | pg.DOUBLEBUF
        if FULLSCREEN:
            pg_flags |= pg.FULLSCREEN

        pg.display.set_mode((self.screen_width, self.screen_height), flags=pg_flags)

        pg.event.set_grab(GRAB_MOUSE)
        pg.mouse.set_visible(True)

        # OpenGL context / options
        self.ctx = mgl.create_context()
        
        self.ctx.wireframe = False
        #self.ctx.front_face = 'cw'
        #self.ctx.enable(flags=mgl.DEPTH_TEST)
        #self.ctx.enable(flags=mgl.DEPTH_TEST | mgl.CULL_FACE)
        #self.ctx.enable(flags=mgl.DEPTH_TEST | mgl.CULL_FACE | mgl.BLEND)
        #self.ctx.enable(flags=mgl.BLEND)

        # time objects
        self.clock = pg.time.Clock()
        self.time = 0
        self.delta_time = 0
        self.num_frames = 0

        # quad
        quad = [
            # pos (x, y), uv coords (x, y)
            -1.0, 1.0, 0.0, 1.0,  # tl
            1.0, 1.0, 1.0, 1.0,   # tr
            -1.0, -1.0, 0.0, 0.0, # bl
            1.0, -1.0, 1.0, 0.0,  # br
        ]

        quad_buffer = self.ctx.buffer(data=np.array(quad, dtype='f4'))

        self.all_shaders = ShaderProgram(self.ctx)
        self.quad_program = self.all_shaders.get_program("quad")

        # compute shader
        with open(f'shaders/ray_cs.glsl') as file:
            compute_shader_source = file.read()

        compute_shader_source = compute_shader_source.replace("XGROUPSIZE_VAL", str(XGROUPSIZE)) \
                                                     .replace("YGROUPSIZE_VAL", str(YGROUPSIZE)) \
                                                     .replace("ZGROUPSIZE_VAL", str(ZGROUPSIZE))

        self.compute_shader = self.ctx.compute_shader(compute_shader_source)

        self.set_uniform(self.compute_shader, "SCREEN_WIDTH", self.screen_width)
        self.set_uniform(self.compute_shader, "SCREEN_HEIGHT", self.screen_height)

        # CS: layout(rgba8, binding = 0) uniform image2D out_texture;
        self.compute_shader["out_texture"] = 0
        #self.compute_shader["out_texture2"] = 1 # layout(rgba8, binding = 1) uniform image2D out_texture2;

        self.texture = self.ctx.texture((int(self.screen_width/1), int(self.screen_height/1)), 4, dtype='f1')
        self.texture.filter = mgl.NEAREST, mgl.NEAREST # because when we access the image from a CS it is an Image2D (not Sampler2D)
        #self.texture.bind_to_image(0, read=False, write=True)

        self.quad_program['quad_tex'] = 0

        self.quad_vao = self.ctx.vertex_array(self.quad_program, [(quad_buffer, '2f 2f', 'vert', 'texcoord')])

    def destroy(self):
        self.all_shaders.destroy()

    def set_uniform(self, program, u_name, u_value):
        try:
            program[u_name] = u_value
        except KeyError:
            pass

    def get_fps(self):
        self.currentTime = time.time()
        delta = self.currentTime - self.lastTime

        if delta >= 1:
            fps = f"FPS: {self.fps.get_fps():3.0f}"
            pg.display.set_caption(fps)

            self.lastTime = self.currentTime

        self.fps.tick()

    def check_events(self):

        for event in pg.event.get():

            if event.type == pg.QUIT or (event.type == pg.KEYDOWN and event.key == pg.K_ESCAPE):
                self.destroy()
                if self.record_video:
                    self.video_recorder.end_recording()
                pg.quit()
                sys.exit()

            if event.type == pg.KEYDOWN:
                if event.key == pg.K_p:
                    self.pause = not self.pause

            if event.type == pg.KEYUP:
                pass

    def run(self):

        while True:
            self.time = pg.time.get_ticks() * 0.001

            self.check_events()

            self.ctx.clear(color=(0.0, 0.0, 0.0))

            if not self.pause:
                self.set_uniform(self.compute_shader, "time", self.time)
                self.set_uniform(self.compute_shader, "delta_time", self.delta_time)

                # CS: layout(std430, binding = 0) buffer bodies_in
                #self.bodies.ssbo_in.bind_to_storage_buffer(0)

                # CS: layout(rgba8, binding = 0) uniform image2D out_texture;
                self.texture.bind_to_image(0, read=False, write=True) # glBindImageTexture(0, texHandle, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_R32F);

                # Number of WorkGroup: self.screen_width//XGROUPSIZE * self.screen_height//YGROUPSIZE * 1
                self.compute_shader.run(group_x= self.screen_width//XGROUPSIZE, group_y= self.screen_height//YGROUPSIZE, group_z=1)
                #self.compute_shader.run(group_x= self.screen_width, group_y= self.screen_height, group_z=1)

                self.ctx.memory_barrier()

            # FS
            self.texture.use(location=0)
            self.quad_vao.render(mode=mgl.TRIANGLE_STRIP)

            pg.display.flip()

            # record video
            if self.record_video:
                pg_surface = pygame.image.fromstring(self.texture.read(), (self.texture.width, self.texture.height), 'RGBA', True)
                self.video_recorder.capture_frame(pg_surface)

            self.delta_time = self.clock.tick(self.max_fps)

            self.get_fps()
            self.num_frames += 1

# -----------------------------------------------------------------------------------------------------------
# python3 main.py --fps=-1
# python3 main.py --fps=60 -rv="h264" -vfps=60

def main():

    parser = argparse.ArgumentParser(description="")

    parser.add_argument('-f', '--fps', help='Max FPS, -1 for unlimited', default=-1, type=int)
    parser.add_argument('-rv', '--record_video', help='', default="", type=str)
    parser.add_argument('-vfps', '--video_fps', help='', default=60, type=int)

    result = parser.parse_args()
    args = dict(result._get_kwargs())

    print("Args = %s" % args)

    app = App(screen_width=SCREEN_WIDTH, screen_height=SCREEN_HEIGHT, fps=args["fps"], record_video=args["record_video"], video_fps=args["video_fps"])
    app.run()

if __name__ == "__main__":
    main()

