import csv
import math
import sys
from PIL import Image, ImageDraw, ImageFont


# From http://cs.joensuu.fi/~spectral/databases/programs.htm
# Convert Matlab formats into csv files.

s_colnames = [
    'h', 'v', 'c'
]

c_colnames = [
    'x', 'y', 'z', 'X', 'Y', 'Z',
    'R', 'G', 'B', 'L*', 'a*', 'b*',
    'u', 'v', 'u*', 'v*'
]

munsell_colnames = [
    '{}'.format(wavelength) for wavelength in range(400, 700+5, 5)
]

ordered_hues = [
    '2.5R',
    '5.0R',
    '7.5R',
    '10.0R',
    '2.5YR',
    '5.0YR',
    '7.5YR',
    '10.0YR',
    '2.5Y',
    '5.0Y',
    '7.5Y',
    '10.0Y',
    '2.5GY',
    '5.0GY',
    '7.5GY',
    '10.0GY',
    '2.5G',
    '5.0G',
    '7.5G',
    '10.0G',
    '2.5BG',
    '5.0BG',
    '7.5BG',
    '10.0BG',
    '2.5B',
    '5.0B',
    '7.5B',
    '10.0B',
    '2.5PB',
    '5.0PB',
    '7.5PB',
    '10.0PB',
    '2.5P',
    '5.0P',
    '7.5P',
    '10.0P',
    '2.5RP',
    '5.0RP',
    '7.5RP',
    '10.0RP'
]

chroma_labels = [
    (1, '/1 '),
    (2, '/2 '),
    (4, '/4 '),
    (6, '/6 '),
    (8, '/8 '),
    (10, '/10'),
    (12, '/12'),
    (14, '/14'),
    (16, '/16')
]

value_labels = [
    (25, '2.5/'),
    (30, '  3/'),
    (40, '  4/'),
    (50, '  5/'),
    (60, '  6/'),
    (70, '  7/'),
    (80, '  8/'),
    (85, '8.5/'),
    (90, '  9/')
]

font_size = 18
font_size_large = 32
image_w = 1100
image_h = 850
patch_x0 = 150
patch_w = 72
patch_w_stride = patch_w + 20
patch_y0 = 780
patch_h = 64
patch_h_stride = patch_h + 20
value_label_x0 = 80
chroma_label_y0 = patch_y0 + 15
gamma = 0.5

def clamped_rgb_gamma(value):
    clamped = max(0, min(value/100.0, 1.0))
    return max(0, min(int(round(math.pow(clamped, gamma) * 255.0)), 255))

def rgb_gamma(color):
    r = clamped_rgb_gamma(color['R'])
    g = clamped_rgb_gamma(color['G'])
    b = clamped_rgb_gamma(color['B'])
    return (r, g, b)

class MunsellPage:
    def __init__(self, hue, c):
        self.page_num = ordered_hues.index(hue) + 1
        self.h = hue
        self.color_data = c
        self.init_image()

    def text_ralign(self, xy, text, font):
        (w, h) = self.draw.textsize(text, font = font)
        (x, y) = xy
        self.draw.text((x - w, y), text, font = font, fill = '#000000')

    def init_image(self):
        self.img = Image.new('RGB', (image_w, image_h), color = 'white')
        self.draw = ImageDraw.Draw(self.img)
        small_font = ImageFont.truetype('./RobotoMono-BoldItalic.ttf', font_size)
        large_font = ImageFont.truetype('./RobotoMono-BoldItalic.ttf', font_size_large)
        x0 = patch_x0 + (len(chroma_labels) * patch_w_stride)
        y0 = patch_y0 - (len(value_labels) * patch_h_stride)
        # print('{} {}'.format((x0, y0), self.h))
        self.text_ralign((x0, y0), self.h, large_font)
        self.text_ralign((x0, y0 + 40), 'p. {}'.format(self.page_num), small_font)
        for y, vl in enumerate(value_labels):
            (v, label) = vl
            y0 = patch_y0 - patch_h - (y * patch_h_stride)
            # print('{} {}'.format((value_label_x0, y0), label))
            self.draw.text((value_label_x0, y0), label, font = small_font, fill = '#000000', align = 'left')
        for x, cl in enumerate(chroma_labels):
            (c, label) = cl
            x0 = patch_x0 + (x * patch_w_stride)
            # print('{} {}'.format((x0, chroma_label_y0), label))
            self.draw.text((x0, chroma_label_y0), label, font = small_font, fill = '#000000', align = 'left')

    def add_patch(self, idx, spec):
        v = spec['v']
        c = spec['c']
        location = self.find_location(v, c)
        if location:
            (x, y, v_label, c_label) = location
            x0 = patch_x0 + (x * patch_w_stride)
            y0 = patch_y0 - (y * patch_h_stride)
            x1 = x0 + patch_w
            y1 = y0 - patch_h
            xy = [x0, y0, x1, y1]
            color = self.color_data[idx]
            r, g, b = rgb_gamma(color)
            fill = '#{:02X}{:02X}{:02X}'.format(r, g, b)
            # print('spec{} idx {} xy {} fill {}'.format(spec, idx, xy, fill))
            self.draw.rectangle(xy, fill = fill)

    def find_location(self, v, c):
        for x, chroma in enumerate(chroma_labels):
            (c_test, c_label) = chroma
            if (c == c_test):
                for y, value in enumerate(value_labels):
                    (v_test, v_label) = value
                    if (v == v_test):
                        return (x, y, v_label, c_label)
        return None

    def print(self):
        self.img.save('{:03d}_{}.png'.format(self.page_num, self.h.replace(' ', '_')))

class MunsellBook:
    def __init__(self):
        self.current_hue = ''
        self.current_page = None

    def read_data(self):
        with open('munsell400_700_5.munsell.csv') as munsell_file:
            filter = lambda k, v: v
            self.munsell = [self.parsed(row, filter) for row in csv.DictReader(munsell_file)]

        with open('munsell400_700_5.s.csv') as s_file:
            filter = lambda k, v: int(v) if k in ['v', 'c'] else v
            self.s = [self.parsed(row, filter) for row in csv.DictReader(s_file)]

        with open('munsell400_700_5.c.csv') as c_file:
            filter = lambda k, v: float(v)
            self.c = [self.parsed(row, filter) for row in csv.DictReader(c_file)]

    def parsed(self, row, filter):
        parsed_row = dict()
        for k, v in row.items():
            parsed_row[k] = filter(k, v)
        return parsed_row

    def print_rgb_colors(self):
        for idx, color in enumerate(self.c):
            r, g, b = rgb_gamma(color)
            print('idx {} rgb {} hex {}'.format(idx, (color['R'], color['G'], color['B']), '#{:02X}{:02X}{:02X}'.format(r, g, b)))

    def print_pages(self, page_max = -1):
        page_count = 0
        for idx, spec in enumerate(self.s):
            if spec['h'] != self.current_hue:
                if page_count == page_max:
                    break
                if self.current_page is not None:
                    self.current_page.print()
                page_count = page_count + 1
                self.current_hue = spec['h']
                self.current_page = MunsellPage(spec['h'], self.c)
            self.current_page.add_patch(idx, spec)

        if self.current_page is not None:
            self.current_page.print()


book = MunsellBook()
book.read_data()
# book.print_rgb_colors()
book.print_pages()
