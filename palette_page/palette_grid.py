#!/usr/bin/python3

import csv
import json
import math
import subprocess
import warnings
from PIL import Image, ImageDraw, ImageFont

import munsellkit as mkit

HUES = [
    ('10RP', 0),
    ('5R', 5),
    ('5YR', 15),
    ('5Y', 25),
    ('5GY', 35),
    ('5G', 45),
    ('5BG', 55),
    ('5B', 65),
    ('5PB', 75),
    ('5P', 85),
    ('5RP', 95),
    ('10RP', 100)
]

class PaletteGrid:
    # Page parameters for PIL
    dpi = 100

    image_w = 1100
    image_h = 850

    x_center = 425
    y_center = 425

    x_origin = 20
    y_origin = 20

    small_font_size = 14
    small_font = ImageFont.truetype('../color_book/RobotoMono-BoldItalic.ttf', small_font_size)

    cells_v = 10

    patch_w = 24
    patch_w_stride = 106

    patch_h = 40
    patch_h_stride = 90

    dot_r = 30
    dot_r_outer = 40
    polar_value_max = 6.5

    def __init__(self, polar=False):
        self.polar = polar
        self.init_image()

    def init_image(self):
        self.img = Image.new('RGB', (self.image_w, self.image_h), color = 'white')
        self.draw = ImageDraw.Draw(self.img)

    def get_x(self, astm_hue):
        return self.x_origin + self.patch_w_stride * astm_hue / 10.

    def get_y(self, value):
        return self.y_origin + self.patch_h_stride * (9.5 - value)

    def get_r(self, value):
        return value * (self.y_center - self.y_origin) / self.polar_value_max

    def get_polar_xy(self, astm_hue, value):
        r = self.get_r(value)
        theta = astm_hue * 2. * math.pi / 100.
        x = self.x_center + r * math.sin(theta)
        y = self.y_center - r * math.cos(theta)
        return (x, y)

    def draw_polar_grid(self):
        for value in range(2, 12, 2):
            r = self.get_r(value)
            xy = (self.x_center - r, self.y_center - r, self.x_center + r, self.y_center + r)
            self.draw.ellipse(xy, fill = None, outline = '#cccccc')
            xy = self.get_polar_xy(28, value)
            self.draw.text(xy,
                str(value), font = self.small_font, fill = '#000000', align = 'left')

        for hue_label, astm_hue in HUES:
            if hue_label == '10RP':
                continue
            x, y = self.get_polar_xy(astm_hue, 10)
            xy = [self.x_center, self.y_center, x, y]
            self.draw.line(xy, fill = '#cccccc')
            xy = self.get_polar_xy(astm_hue, 6.5)
            self.draw.text(xy,
                hue_label, font = self.small_font, fill = '#000000', align = 'left')

    def get_fill(self, hue, value, chroma):
        if value <= 4:
            adj_value = value * 0.5 + 2
        else:
            adj_value = value
        munsell_color = f"{hue} {adj_value}/{chroma}"
        rgb = mkit.munsell_color_to_rgb(munsell_color)
        r, g, b = rgb
        r = max(0, min(255, int(r * 255)))
        g = max(0, min(255, int(g * 255)))
        b = max(0, min(255, int(b * 255)))
        return f'#{r:02X}{g:02X}{b:02X}'

    def get_label_fill(self, value):
        if value < 5.5:
            return '#CCCCCC'
        else:
            return '#000000'

    def draw_polar_label(self, label, astm_hue, value):
        x, y = self.get_polar_xy(astm_hue, value)
        xy = (x - self.dot_r, y - self.dot_r, x + self.dot_r, y + self.dot_r)
        xy = (x - 12, y - 8)
        self.draw.text(xy,
            label, font = self.small_font, 
            fill = self.get_label_fill(value), align = 'center')

    def draw_polar_patch(self, astm_hue, hue, value, chroma):
        x, y = self.get_polar_xy(astm_hue, value)
        # xy = (x - self.dot_r_outer, y - self.dot_r_outer, 
        #    x + self.dot_r_outer, y + self.dot_r_outer)
        # self.draw.ellipse(xy, fill = self.get_fill(hue, value, 2))
        xy = (x - self.dot_r, y - self.dot_r, x + self.dot_r, y + self.dot_r)
        self.draw.ellipse(xy, fill = self.get_fill(hue, value, chroma))

    def draw_grid(self):
        self.draw.rectangle([5, 5, 1095, 845], outline = '#ccccff')

        for hue_label, astm_hue in HUES:
            if hue_label == '10RP':
                continue
            x = self.get_x(astm_hue)
            y0 = self.get_y(9.5)
            y1 = self.get_y(1)
            xy = (x, y0, x, y1)
            self.draw.line(xy, fill = '#cccccc')
            self.draw.text((x, self.y_origin),
                hue_label, font = self.small_font, fill = '#000000', align = 'left')

        for v in range(1, 10):
            value = float(v)
            x0 = self.get_x(0)
            x1 = self.get_x(100)
            y = self.get_y(value)
            xy = (x0, y, x1, y)
            self.draw.line(xy, fill = '#cccccc')
            self.draw.text((self.x_origin, y),
                str(v), font = self.small_font, fill = '#000000', align = 'left')

    def draw_cartesian_label(self, label, lpos, astm_hue, value):
        x0 = self.get_x(astm_hue)
        y0 = self.get_y(value)
        xy = (x0 + self.patch_w + 4, y0)
        align = 'left'
        if lpos == 'L':
            xy = (x0 - 4, y0)
            align = 'right'
        elif lpos == 'T':
            xy = (x0, y0 - 16)
        elif lpos == 'B':
            xy = (x0, y0 + self.patch_h + 4)
        self.draw.text(xy,
            label, font = self.small_font, fill = '#000000', align = align)

    def draw_cartesian_patch(self, astm_hue, hue, value, chroma):
        x0 = self.get_x(astm_hue)
        y0 = self.get_y(value)
        x1 = x0 + self.patch_w
        y1 = y0 + self.patch_h
        xy = (x0, y0, x1, y1)
        self.draw.rectangle(xy, fill = self.get_fill(hue, value, chroma))

    def draw_patches(self):
        with open('my_colors.csv') as palette_file:
            for row in csv.DictReader(palette_file):
                astm_hue = row['ASTM Hue']
                value = row['Value']
                if astm_hue == '#N/A' or value == '':
                    continue
                astm_hue = float(astm_hue)
                hue = f'''{row['Hue Value']}{row['Hue Name']}'''
                value = float(value)
                chroma = float(row['Chroma']) 
                if self.polar:
                    self.draw_polar_patch(astm_hue, hue, value, chroma)
                else:
                    self.draw_cartesian_patch(astm_hue, hue, value, chroma)

        with open('my_colors.csv') as palette_file:
            for row in csv.DictReader(palette_file):
                astm_hue = row['ASTM Hue']
                value = row['Value']
                if astm_hue == '#N/A' or value == '':
                    continue
                astm_hue = float(astm_hue)
                value = float(value)
                if self.polar:
                    self.draw_polar_label(row['Abbrev'], astm_hue, value)
                else:
                    self.draw_cartesian_label(row['Abbrev'], row['LPos'], astm_hue, value)

    def print_page(self):
        if self.polar:
            self.draw_polar_grid()
            self.draw_patches()
            self.img.save('munsell_polar.png', dpi = (self.dpi, self.dpi))
        else:
            self.draw_grid()
            self.draw_patches()
            self.img.save('munsell_grid.png', dpi = (self.dpi, self.dpi))


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--polar', help='print a polar grid', action='store_true'
    )
    args = parser.parse_args()

    PaletteGrid(polar=args.polar).print_page()
