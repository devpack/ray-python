import pygame as pg
import numpy as np
import moderngl as mgl
import sys

from config import *
from shader_program import ShaderProgram

# -----------------------------------------------------------------------------------------------------------

class App:

    def __init__(self, screen_width=SCREEN_WIDTH, screen_height=SCREEN_HEIGHT):

        self.screen_width = screen_width
        self.screen_height = screen_height

        #
        self.lastTime = time.time()
        self.currentTime = time.time()

        self.fps = FPSCounter()

        # pygame init
        pg.init()

        pg.display.gl_set_attribute(pg.GL_CONTEXT_MAJOR_VERSION, 3)
        pg.display.gl_set_attribute(pg.GL_CONTEXT_MINOR_VERSION, 3)
        pg.display.gl_set_attribute(pg.GL_CONTEXT_PROFILE_MASK, pg.GL_CONTEXT_PROFILE_CORE)

        pg.display.set_mode((self.screen_width, self.screen_height), flags=pg.OPENGL | pg.DOUBLEBUF)  # | pg.FULLSCREEN)

        pg.event.set_grab(False)
        pg.mouse.set_visible(True)

        self.u_scroll = 5.0  # mouse

        # OpenGL context / options
        self.ctx = mgl.create_context()
        # self.ctx.enable(flags=mgl.DEPTH_TEST | mgl.CULL_FACE)

        # time objects
        self.clock = pg.time.Clock()
        self.time = 0
        self.delta_time = 0
        self.num_frames = 0

        # load shaders
        all_shaders = ShaderProgram(self.ctx)
        self.program = all_shaders.programs[MODEL]

        vertex_data = [(-1, -1, 0), (1, -1, 0), (1, 1, 0), (-1, 1, 0), (-1, -1, 0), (1, 1, 0)]
        vertex_data = np.array(vertex_data, dtype=np.float32)

        self.vbo = self.ctx.buffer(vertex_data)  # self.vbo = self.ctx.buffer(vertex_data.tobytes())

        self.vao = self.ctx.vertex_array(self.program, [(self.vbo, '3f', 'vertexPosition')])

        # uniforms
        self.set_uniform('u_resolution', (self.screen_width, self.screen_height))
        self.set_uniform('u_mouse', (0, 0))

    def destroy(self):
        self.vbo.release()
        self.program.release()
        self.vao.release()

    def set_uniform(self, u_name, u_value):
        try:
            self.program[u_name] = u_value
        except KeyError:
            pass

    def get_time(self):
        self.time = pg.time.get_ticks() * 0.001

    def get_fps(self):
        self.currentTime = time.time()
        delta = self.currentTime - self.lastTime

        if delta >= 1:
            fps = f"PyGame FPS: {self.fps.get_fps():3.0f}"
            pg.display.set_caption(fps)

            self.lastTime = self.currentTime

        self.fps.tick()

    def check_events(self):

        for event in pg.event.get():

            if event.type == pg.QUIT or (event.type == pg.KEYDOWN and event.key == pg.K_ESCAPE):
                self.destroy()
                pg.quit()
                sys.exit()

            if event.type == pg.MOUSEMOTION:
                x, y = pg.mouse.get_pos()
                dx, dy = pg.mouse.get_rel()
                self.mouse_pos(x, y, dx, dy)

            if event.type == pg.MOUSEWHEEL:  # which, flipped, x, y, touch, precise_x, precise_y
                self.mouse_scroll(event.x, event.y)

    def mouse_pos(self, x, y, dx, dy):
        self.set_uniform('u_mouse', (x, y))

    def mouse_scroll(self, x, y):
        self.u_scroll = max(1.0, self.u_scroll + y)
        self.set_uniform('u_scroll', self.u_scroll)

    #
    def render(self):
        self.ctx.clear()
        self.vao.render()
        pg.display.flip()

    #
    def update(self):
        self.set_uniform('u_time', pg.time.get_ticks() * 0.001)
        self.set_uniform('u_frames', self.num_frames)

    #
    def run(self):
        while True:
            self.num_frames += 1

            self.get_time()

            self.check_events()

            self.update()
            self.render()

            self.delta_time = self.clock.tick(MAX_FPS)

            self.get_fps()


# -----------------------------------------------------------------------------------------------------------

if __name__ == '__main__':
    app = App()
    app.run()

