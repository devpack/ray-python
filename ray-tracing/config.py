import time, collections
import moderngl as mgl
import pygame, cv2

# ----------------------------------------------------------------------------------------------------------------------

FULLSCREEN    = 0
SCREEN_WIDTH  = 1280
SCREEN_HEIGHT = 800
FONT_SIZE     = 32

XGROUPSIZE = 64
YGROUPSIZE = 1
ZGROUPSIZE = 1

GRAB_MOUSE = False

# ----------------------------------------------------------------------------------------------------------------------

class FPSCounter:
    def __init__(self):
        self.time = time.perf_counter()
        self.frame_times = collections.deque(maxlen=60)

    def tick(self):
        t1 = time.perf_counter()
        dt = t1 - self.time
        self.time = t1
        self.frame_times.append(dt)

    def get_fps(self):
        total_time = sum(self.frame_times)
        if total_time == 0:
            return 0
        else:
            return len(self.frame_times) / sum(self.frame_times)
        
# -----------------------------------------------------------------------------------------------------------

class ScreenRecorder:
    def __init__(self, width, height, fps, codec="XVID", out_file='output.avi'):
        print(f'Initializing ScreenRecorder with parameters width:{width} height:{height} fps:{fps}.')
        print(f'Output of the screen recording saved to {out_file}.')

        # define the codec and create a video writer object
        four_cc = cv2.VideoWriter_fourcc(*codec)

        self.video = cv2.VideoWriter(out_file, four_cc, float(fps), (width, height))

    def capture_frame(self, surf):
        # transform the pixels to the format used by open-cv
        pixels = cv2.rotate(pygame.surfarray.pixels3d(surf), cv2.ROTATE_90_CLOCKWISE)
        pixels = cv2.flip(pixels, 1)
        pixels = cv2.cvtColor(pixels, cv2.COLOR_RGB2BGR)

        # write the frame
        self.video.write(pixels)

    def end_recording(self):
        self.video.release()
