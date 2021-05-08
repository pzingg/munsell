from abc import ABC
import csv
import itertools
import math
import operator

from colour.notation import munsell as cnm
from PIL import Image, ImageDraw, ImageFont


VALUE_2_ROWS = [
    19,
    18,
    17,
    16,
    14,
    12,
    10,
    8,
    6
]

N_ROWS = len(VALUE_2_ROWS)

CHROMA_COLS = [
    1,
    2,
    4,
    6,
    8,
    10,
    12,
    14
]

N_COLS = len(CHROMA_COLS)

COLORLAB_HUE_NAMES = [
    'B',  # hue_index  1, ASTM 60
    'BG', # hue_index  2, ASTM 50
    'G',  # hue_index  3, ASTM 40
    'GY', # hue_index  4, ASTM 30
    'Y',  # hue_index  5, ASTM 20
    'YR', # hue_index  6, ASTM 10
    'R',  # hue_index  7, ASTM  0
    'RP', # hue_index  8, ASTM 90
    'P',  # hue_index  9, ASTM 80
    'PB'  # hue_index 10, ASTM 70
]

HUES = [
    '10RP', # 0
    '2.5R',
    '5R',
    '7.5R',
    '10R', # 4
    '2.5YR',
    '5YR',
    '7.5YR',
    '10YR', # 8
    '2.5Y',
    '5Y',
    '7.5Y',
    '10Y', # 12
    '2.5GY',
    '5GY',
    '7.5GY',
    '10GY', # 16
    '2.5G',
    '5G',
    '7.5G',
    '10G', # 20
    '2.5BG',
    '5BG',
    '7.5BG',
    '10BG', # 24
    '2.5B',
    '5B',
    '7.5B',
    '10B', # 28
    '2.5PB',
    '5PB',
    '7.5PB',
    '10PB', # 32
    '2.5P',
    '5P',
    '7.5P',
    '10P', # 36
    '2.5RP',
    '5RP',
    '7.5RP'
]

def draw_text_ralign(draw, xy, text, font):
    (w, h) = draw.textsize(text, font=font)
    (x, y) = xy
    draw.text((x - w, y), text, font=font, fill='#000000')

def value_label(value_2):
    value = value_2 / 2.
    return f'{value:.1f}'

def chroma_label(chroma):
    return f'{chroma}'

# Formats an 8 1/2 by 11 inch page in the Munsell book
class MunsellPage:
    # Page parameters for PIL
    dpi = 100
    image_w = 850
    image_h = 1100

    xsmall_font_size = 14
    small_font_size = 18
    large_font_size = 32
    xsmall_font = ImageFont.truetype(
        './RobotoMono-Regular.ttf', xsmall_font_size)
    small_font = ImageFont.truetype(
        './RobotoMono-BoldItalic.ttf', small_font_size)
    large_font = ImageFont.truetype(
        './RobotoMono-BoldItalic.ttf', large_font_size)

    patch_x0 = 150
    value_label_x0 = patch_x0 - 50
    patch_w = 72
    patch_w_stride = patch_w + 12

    patch_y0 = image_h - 60
    chroma_label_y0 = patch_y0 + 15
    patch_h = 100
    patch_h_stride = patch_h + 12

    def __init__(self, source_name, page_num, hue, data):
        self.source_name = source_name
        self.page_num = page_num
        self.astm_hue = (page_num % 40) * 2.5
        self.hue = hue
        self.data = data
        self.init_image()

    def init_image(self):
        self.img = Image.new(
            'RGB', (self.image_w, self.image_h), color='white')
        self.draw = ImageDraw.Draw(self.img)

    def build_image(self):
        x0 = self.patch_x0 + ((N_COLS - 1) * self.patch_w_stride) + self.patch_w
        y0 = self.patch_y0 - (N_ROWS * self.patch_h_stride) + 10
        draw_text_ralign(self.draw, (x0, y0), self.hue, self.large_font)
        draw_text_ralign(self.draw, (x0, y0 + 40), f'p. {self.page_num}', self.small_font)
        last_col = len(CHROMA_COLS) - 2 

        for x, chroma in enumerate(CHROMA_COLS):
            label = chroma_label(chroma)
            x0 = self.patch_x0 + (x * self.patch_w_stride)
            self.draw.text((x0, self.chroma_label_y0),
                            label, font=self.small_font, fill='#000000', align='left')

        for i, value_2 in enumerate(VALUE_2_ROWS):
            value = value_2 / 2.
            y = N_ROWS - i - 1
            label = value_label(value_2)
            y0 = self.patch_y0 - self.patch_h - (y * self.patch_h_stride)
            self.draw.text((self.value_label_x0, y0),
                           label, font=self.small_font, fill='#000000', align='left')

            for x, chroma in enumerate(CHROMA_COLS):
                if i == 0 and x >= last_col:
                    continue

                x0 = self.patch_x0 + (x * self.patch_w_stride)
                y0 = self.patch_y0 - (y * self.patch_h_stride)
                x1 = x0 + self.patch_w
                y1 = y0 - self.patch_h
                xy = [x0, y0, x1, y1]
                if chroma in self.data[value_2]:
                    self.draw.rectangle(xy, outline='black')

                    x1 = x0 + 6
                    y1 = y1 + 4
                    colors = sorted(self.data[value_2][chroma], key=lambda row: color_distance(row, self.astm_hue, value, chroma))
                    if len(colors) > 0:
                        for row in colors[:6]:
                            label = row['Identifier']
                            self.draw.text((x1, y1),
                                label, font=self.xsmall_font, fill='#000000', align='left')
                            y1 = y1 + 14
                else:
                    munsell_color = f'{self.hue} {value}/{chroma}'
                    spec = cnm.parse_munsell_colour(munsell_color)
                    max_chroma = cnm.maximum_chroma_from_renotation(spec[0], spec[1], spec[3])
                    if chroma <= max_chroma:
                        self.draw.rectangle(xy, outline='#666699')
                        # self.draw.line(xy, fill='#666666', width=1)
                        # self.draw.line([x0, y1, x1, y0], fill='#666666', width=1)


    def print(self):
        file_name = f'{self.source_name}_{self.page_num:02d}_{self.hue}.png'
        self.img.save(file_name, dpi=(self.dpi, self.dpi))


def make_book(args):
    pages = dict()
    with open('dunn_edwards.csv', 'rt') as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = row['Color Name']
            value = float(row['Value'])
            chroma = float(row['Chroma'])
            astm_hue = float(row['ASTM Hue'])
            astm_page = round(astm_hue / 2.5) % 40

            row['Value'] = value
            row['Chroma'] = chroma
            row['ASTM Hue'] = astm_hue

            if value > 8.:
                value_2 = min(round(value * 2.), 19)
            else:
                value_2 = round(value) * 2

            # value_2 is an int
            if value_2 not in VALUE_2_ROWS:
                if args.raise_exceptions:
                    raise RuntimeError(f'{name}: value_2 {value_2} is out of range, value was {value}')
                else:
                    continue

            if chroma > 2.:
                chroma = round(chroma / 2.) * 2
            else:
                chroma = max(round(chroma), 1)

            # chroma is now an int
            if chroma not in CHROMA_COLS:
                if args.raise_exceptions:
                    raise RuntimeError(f'{name}: chroma {chroma} is out of range')
                else:
                    continue

            if astm_page not in pages:
                page_rows = dict()
                for v2 in VALUE_2_ROWS:
                    page_rows[v2] = dict()
                pages[astm_page] = page_rows

            if chroma not in pages[astm_page][value_2]:
                pages[astm_page][value_2][chroma] = []

            pages[astm_page][value_2][chroma].append(row)

    if args.book:
        print_book(pages)
    else:
        print_text(pages)
    
    if args.verbose:
        print_stats(pages)

def print_book(pages):
    stats = (N_ROWS * N_COLS) * [0]
    for page_num in range(1, 41):
        page = page_num % 40
        page_image = MunsellPage('de', page_num, HUES[page], pages[page])
        page_image.build_image()
        page_image.print()


def print_text(pages):
    for page_num in range(1, 41):
        print(f'\nPage # {page_num}')
        page = page_num % 40
        hue = HUES[page]
        astm_hue = page * 2.5
        print(f'Hue {hue}')
        for i, value_2 in enumerate(VALUE_2_ROWS):
            value = value_2 / 2.
            row = pages[page][value_2]
            if len(row) > 0:
                print(f' Value {value_label(value_2)}:')
                for j, chroma in enumerate(CHROMA_COLS):
                    bucket = i * N_COLS + j
                    if chroma in pages[page][value_2]:
                        print(f'  Chroma {chroma_label(chroma)}:')
                        colors = sorted(pages[page][value_2][chroma], key=lambda row: color_distance(row, astm_hue, value, chroma))
                        for row in colors:
                            dist = color_distance(row, astm_hue, value, chroma)
                            print(f'''   {row['Identifier']} {row['Color Name']} {row['Munsell Specification']} d={dist:.2f}''')        


def print_stats(pages):
    print('')
    stats = (N_ROWS * N_COLS) * [0]
    for page_num in range(1, 41):
        page = page_num % 40
        for i, value_2 in enumerate(VALUE_2_ROWS):
            row = pages[page][value_2]
            if len(row) > 0:
                for j, chroma in enumerate(CHROMA_COLS):
                    bucket = i * N_COLS + j
                    if chroma in pages[page][value_2]:
                        stats[bucket] = stats[bucket] + 1

    for i, value_2 in enumerate(VALUE_2_ROWS):
        for j, chroma in enumerate(CHROMA_COLS):
            bucket = i * N_COLS + j
            print(f'{value_label(value_2)}/{chroma_label(chroma)}: {stats[bucket]} pages')


HUE_WEIGHT = 1.     # Max will be 1.25
VALUE_WEIGHT = 10.  # Max will be 5.
CHROMA_WEIGHT = 2.  # Max will be 2.

def color_distance(row, astm_hue, value, chroma):
    dh = astm_hue - row['ASTM Hue']
    if dh > 50.:
        dh = dh - 100.
    elif dh < -50.:
        dh = dh + 100.
    dv = value - row['Value']
    dc = chroma - row['Chroma']
    return HUE_WEIGHT * abs(dh) + VALUE_WEIGHT * abs(dv) + CHROMA_WEIGHT * abs(dc)


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--verbose', help='print stats', action='store_true')
    parser.add_argument(
        '--book', help='print in book format', action='store_true')
    parser.add_argument(
        '--raise-exceptions', help='raise error if value or chroma out of range', action='store_true')
    args = parser.parse_args()

    make_book(args)
