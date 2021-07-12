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

    x_center = 450
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

    dot_r = 18
    polar_value_max = 6.5

    def __init__(self, polar=False):
        self.polar = polar
        self.init_image()

    def init_image(self):
        self.img = Image.new('RGB', (self.image_w, self.image_h), color = 'white')
        self.draw = ImageDraw.Draw(self.img)

    def get_x(self, hue):
        return self.x_origin + self.patch_w_stride * hue/10

    def get_y(self, value):
        return self.y_origin + self.patch_h_stride * (9.5 - value)

    def get_r(self, value):
        return value * (self.y_center - self.y_origin) / self.polar_value_max

    def get_polar_xy(self, hue, value):
        r = self.get_r(value)
        theta = hue * math.pi / 50.
        x = self.x_center + r * math.sin(theta)
        y = self.y_center - r * math.cos(theta)
        return (x, y)

    def draw_polar_grid(self):
        for value in [4, 6, 8]:
            r = self.get_r(value)
            xy = (self.x_center - r, self.y_center - r, self.x_center + r, self.y_center + r)
            self.draw.ellipse(xy, fill = None, outline = '#cccccc')

        for hue_label, hue in HUES:
            if hue_label == '10RP':
                continue
            x, y = self.get_polar_xy(hue, 8)
            xy = [self.x_center, self.y_center, x, y]
            self.draw.line(xy, fill = '#cccccc')
            xy = self.get_polar_xy(hue, 6.5)
            self.draw.text(xy,
                hue_label, font = self.small_font, fill = '#000000', align = 'left')

    def draw_polar_patch(self, label, lpos, hue, value, r, g, b):
        x, y = self.get_polar_xy(hue, value)
        xy = (x - self.dot_r, y - self.dot_r, x + self.dot_r, y + self.dot_r)
        if label is None:
            fill = f'#{r:02X}{g:02X}{b:02X}'
            self.draw.ellipse(xy, fill = fill)
        else:
            xy = (x - 12, y - 8)
            if value < 5.1:
                fill = '#cccccc'
            else:
                fill = '#000000'
            self.draw.text(xy,
                label, font = self.small_font, fill = fill, align = 'center')

    def draw_grid(self):
        self.draw.rectangle([5, 5, 1095, 845], outline = '#ccccff')

        for hue_label, hue in HUES:
            if hue_label == '10RP':
                continue
            x = self.get_x(hue)
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

    def draw_patch(self, label, lpos, hue, value, r, g, b):
        x0 = self.get_x(hue)
        y0 = self.get_y(value)
        x1 = x0 + self.patch_w
        y1 = y0 + self.patch_h
        xy = (x0, y0, x1, y1)
        if label is None:
            fill = f'#{r:02X}{g:02X}{b:02X}'
            self.draw.rectangle(xy, fill = fill)
        else:
            xy = (x1 + 4, y0)
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

    def draw_patches(self):
        with open('my_colors.csv') as palette_file:
            for row in csv.DictReader(palette_file):
                astm_hue = row['ASTM Hue']
                value = row['Value']
                if astm_hue == '#N/A' or value == '':
                    continue
                value = float(value)
                astm_hue = float(astm_hue)
                adj_value = value
                if value <= 4:
                    adj_value = value * 0.5 + 2
                munsell_color = f"{row['Hue Value']}{row['Hue Name']} {adj_value}/{row['Chroma']}"
                rgb = mkit.munsell_color_to_rgb(munsell_color)
                r, g, b = rgb
                r = max(0, min(255, int(r * 255)))
                g = max(0, min(255, int(g * 255)))
                b = max(0, min(255, int(b * 255)))
                if self.polar:
                    self.draw_polar_patch(None, None, astm_hue, value, r, g, b)
                else:
                    self.draw_patch(None, None, astm_hue, value, r, g, b)

        with open('my_colors.csv') as palette_file:
            for row in csv.DictReader(palette_file):
                astm_hue = row['ASTM Hue']
                value = row['Value']
                if astm_hue == '#N/A' or value == '':
                    continue
                value = float(value)
                astm_hue = float(astm_hue)
                munsell_color = f"{row['Hue Value']}{row['Hue Name']} {value}/{row['Chroma']}"
                rgb = mkit.munsell_color_to_rgb(munsell_color)
                r, g, b = rgb
                r = max(0, min(255, int(r * 255)))
                g = max(0, min(255, int(g * 255)))
                b = max(0, min(255, int(b * 255)))
                if self.polar:
                    self.draw_polar_patch(row['Abbrev'], row['LPos'], astm_hue, value, r, g, b)
                else:
                    self.draw_patch(row['Abbrev'], row['LPos'], astm_hue, value, r, g, b)

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
