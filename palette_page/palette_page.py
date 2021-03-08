#!/usr/bin/python3

import csv
import json
import math
import subprocess
import warnings
from PIL import Image, ImageDraw, ImageFont

import munsellkit as mkit

PALETTE_COLS = [ 
    'Foxton Palette',
    'My Palette',
    'GOSP Palette'
]

def munsell_to_rgb(h, v, c):
    arg = '{}{}/{}'.format(h, v, c)
    out = subprocess.check_output([ '/usr/bin/Rscript', 'munsell_to_rgb.R', arg ])
    try:
        res = json.loads(out)
    except:
        res = None
    if not isinstance(res, list) or len(res) == 0:
        warnings.warn(f"munsell_to_rgb.R returned unexpected output '{out}'")
        return (-1, -1, -1)
    return tuple([int(v) for v in res[0]])


class PalettePage:
   # Page parameters for PIL
    dpi = 100
    image_w = 1100
    image_h = 850

    small_font_size = 14
    small_font = ImageFont.truetype('../color_book/RobotoMono-BoldItalic.ttf', small_font_size)

    cells_v = 10

    patch_w = 180
    patch_w_stride = patch_w + 50

    start_y = 100
    patch_h = 40
    patch_h_stride = patch_h + 36

    def __init__(self):
        self.init_image()

    def init_image(self):
        self.img = Image.new('RGB', (self.image_w, self.image_h), color = 'white')
        self.draw = ImageDraw.Draw(self.img)

    def draw_patch(self, x0, y0, label, r, g, b):
        x1 = x0 + self.patch_w
        y1 = y0 - self.patch_h
        xy = [x0, y0, x1, y1]
        fill = f'#{r:02X}{g:02X}{b:02X}'
        self.draw.rectangle(xy, fill = fill)
        self.draw.text((x0, y0 + 5),
                label, font = self.small_font, fill = '#000000', align = 'left')

    def process_palette(self):
        x0 = 50
        y0 = self.start_y
        count = 0
        with open('munsell_palette.csv') as palette_file:
            for row in csv.DictReader(palette_file):
                in_palette = ''
                for col in PALETTE_COLS:
                    name = row[col]
                    if name != '':
                        in_palette = row['Name']
                        break
                if in_palette != '':
                    count += 1
                    value = max(1, min(float(row['Value']), 10))
                    chroma = max(2, min(float(row['Chroma']), 50))
                    munsell_color = f"{row['Hue']} {value}/{chroma}"
                    rgb = mkit.munsell_color_to_rgb(munsell_color)
                    r, g, b = rgb
                    r = max(0, min(255, int(r * 255)))
                    g = max(0, min(255, int(g * 255)))
                    b = max(0, min(255, int(b * 255)))                 
                    print(f'{in_palette:20s} {r} {g} {b}')
                    self.draw_patch(x0, y0, in_palette, r, g, b)
                    y0 += self.patch_h_stride
                    if count % self.cells_v == 0:
                        y0 = self.start_y
                        x0 += self.patch_w_stride

        print('stopped with count {}, x0 {}, y0 {}'.format(count, x0, y0))

    def print_page(self):
        self.process_palette()
        self.img.save('munsell_palette.png', dpi = (self.dpi, self.dpi))


if __name__ == '__main__':
    PalettePage().print_page()
    # r, g, b = to_rgb('7.16R', '1.54', '8.14')
    # print('rgb {} {} {}'.format(r, g, b))
