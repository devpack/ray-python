class ShaderProgram:

    def __init__(self, ctx):
        self.ctx = ctx
        self.programs = {}
        self.programs['default'] = self.get_program('default')
        self.programs['ray'] = self.get_program('ray')
        self.programs['terrain'] = self.get_program('terrain')

    def get_program(self, shader_name):
        with open(f'shaders/{shader_name}_vs.glsl') as file:
            vertex_shader = file.read()

        with open(f'shaders/{shader_name}_fs.glsl') as file:
            fragment_shader = file.read()

        program = self.ctx.program(vertex_shader=vertex_shader, fragment_shader=fragment_shader)
        return program

    def destroy(self):
        [program.release() for program in self.programs.values()]