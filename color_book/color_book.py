import csv
import math
import operator
import sys
from PIL import Image, ImageDraw, ImageFont

# Column headers from UEF tables
s_colnames = [
    'h', 'V', 'C'
]

c_colnames = [
    'x', 'y', 'z', 'X', 'Y', 'Z',
    'R', 'G', 'B', 'L*', 'a*', 'b*',
    'u', 'v', 'u*', 'v*'
]

munsell_colnames = [
    '{}'.format(wavelength) for wavelength in range(400, 700+5, 5)
]

# Gamma correction for UEF data (see munsellpageaotf.m)
gamma = 0.5


# Page (color wheel) order
ordered_hues = [
    'N',
    '2.5R',
    '5R',
    '7.5R',
    '10R',
    '2.5YR',
    '5YR',
    '7.5YR',
    '10YR',
    '2.5Y',
    '5Y',
    '7.5Y',
    '10Y',
    '2.5GY',
    '5GY',
    '7.5GY',
    '10GY',
    '2.5G',
    '5G',
    '7.5G',
    '10G',
    '2.5BG',
    '5BG',
    '7.5BG',
    '10BG',
    '2.5B',
    '5B',
    '7.5B',
    '10B',
    '2.5PB',
    '5PB',
    '7.5PB',
    '10PB',
    '2.5P',
    '5P',
    '7.5P',
    '10P',
    '2.5RP',
    '5RP',
    '7.5RP',
    '10RP'
]

# Page parameters for PIL
image_w = 1100
image_h = 850

small_font_size = 18
large_font_size = 32
small_font = ImageFont.truetype('./RobotoMono-BoldItalic.ttf', small_font_size)
large_font = ImageFont.truetype('./RobotoMono-BoldItalic.ttf', large_font_size)

patch_x0 = 100
value_label_x0 = patch_x0 - 50
patch_w = 72
patch_w_stride = patch_w + 12

patch_y0 = 780
chroma_label_y0 = patch_y0 + 15
patch_h = 72
patch_h_stride = patch_h + 12


def cast(row, filter):
    parsed_row = dict()
    for k, v in row.items():
        parsed_row[k] = filter(k, v)
    return parsed_row

def clamped_rgb_gamma(value):
    clamped = max(0, min(value/100.0, 1.0))
    return max(0, min(int(round(math.pow(clamped, gamma) * 255.0)), 255))

def cast_uef(row, filter):
    color = cast(row, filter)
    color['dR'], color['dG'], color['dB'] = [clamped_rgb_gamma(color[key]) for key in ['R', 'G', 'B']]
    return color

def rit_filter(k, v):
    if k == 'h':
        return v
    elif k == 'V':
        return 10 * int(v)
    elif k in ['file order', 'C', 'dR', 'dG', 'dB']:
        return int(v)
    else:
        return float(v)

def new_color_source(name):
    if name == 'uef':
        return UEFColorSource(name)
    else:
        return RITColorSource(name)


# Munsell value (*10) and dRGB value
neutrals = [
    ( 95, 243 ),
    ( 90, 232 ),
    ( 85, 220 ),
    ( 80, 203 ),
    ( 70, 179 ),
    ( 60, 150 ),
    ( 50, 124 ),
    ( 40, 97 ),
    ( 30, 70 ),
    ( 25, 59 ),
    ( 20, 48 ),
    ( 10, 28 )
]

neutral_colors = [{
        'h': 'N', 'V': v, 'C': 0,
        'dR': rgb_val, 'dG': rgb_val, 'dB': rgb_val
    } for (v, rgb_val) in neutrals]


class ColorSource:
    def __init__(self, name):
        self.name = name

    def read_data(self):
        raise Exception('Must use subclass!')

    def get_rgb(self, color):
        return [color[key] for key in ['dR', 'dG', 'dB']]

    def find_chroma_x(self, h, c):
        if h == 'N':
            return (0, '')
        for x, chroma in enumerate(self.chroma_labels):
            (c_test, c_label) = chroma
            if (c == c_test):
                return (x, c_label)
        return None

    def find_location(self, color):
        h = color['h']
        v = color['V']
        c = color['C']
        found = self.find_chroma_x(h, c)
        if found is not None:
            (x, c_label) = found
            for y, value in enumerate(self.value_labels):
                (v_test, v_label) = value
                if (v == v_test):
                    return (x, y, v_label, c_label)
        return None

    def print_colors(self):
        for idx, color in enumerate(self.data):
            r, g, b = self.get_rgb(color)
            print('idx {} rgb {} hex {}'.format(idx, (color['R'], color['G'], color['B']), '#{:02X}{:02X}{:02X}'.format(r, g, b)))


class UEFColorSource(ColorSource):
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

    def read_data(self):
        with open('munsell400_700_5.munsell.csv') as munsell_file:
            filter = lambda k, v: v
            self.munsell = [cast(row, filter) for row in csv.DictReader(munsell_file)]

        with open('munsell400_700_5.s.csv') as s_file:
            filter = lambda k, v: int(v) if k in ['V', 'C'] else v
            s = [cast(row, filter) for row in csv.DictReader(s_file)]

        with open('munsell400_700_5.c.csv') as c_file:
            filter = lambda k, v: float(v)
            c = [cast_uef(row, filter) for row in csv.DictReader(c_file)]

        self.data = neutral_colors
        for i in range(0, len(s)):
            s_row = s[i]
            c_row = c[i]
            print('{}: s {} c {}'.format(i, s_row, c_row))
            s_row.update(c_row)
            self.data.append(s_row)


class RITColorSource(ColorSource):
    chroma_labels = [
        (2, '/2 '),
        (4, '/4 '),
        (6, '/6 '),
        (8, '/8 '),
        (10, '/10'),
        (12, '/12'),
        (14, '/14'),
        (16, '/16'),
        (18, '/18'),
        (20, '/20')
    ]

    value_labels = [
        # (10, '  1/'),
        (20, '  2/'),
        (30, '  3/'),
        (40, '  4/'),
        (50, '  5/'),
        (60, '  6/'),
        (70, '  7/'),
        (80, '  8/'),
        (85, '8.5/'),
        (90, '  9/')
    ]

    def read_data(self):
        with open('rit_munsell.csv') as c_file:
            data = [cast(row, rit_filter) for row in csv.DictReader(c_file)]
        data.sort(key = operator.itemgetter('h', 'V', 'C'))
        self.data = neutral_colors + data


class MunsellPage:
    def __init__(self, source, hue):
        self.page_num = ordered_hues.index(hue) + 1
        self.h = hue
        self.source = source
        self.init_image()

    def text_ralign(self, xy, text, font):
        (w, h) = self.draw.textsize(text, font = font)
        (x, y) = xy
        self.draw.text((x - w, y), text, font = font, fill = '#000000')

    def init_image(self):
        self.img = Image.new('RGB', (image_w, image_h), color = 'white')
        self.draw = ImageDraw.Draw(self.img)

        x0 = patch_x0 + (len(self.source.chroma_labels) * patch_w_stride)
        y0 = patch_y0 - (len(self.source.value_labels) * patch_h_stride)
        # print('{} {}'.format((x0, y0), self.h))
        self.text_ralign((x0, y0), self.h, large_font)
        self.text_ralign((x0, y0 + 40), 'p. {}'.format(self.page_num), small_font)

        for y, vl in enumerate(self.source.value_labels):
            (v, label) = vl
            y0 = patch_y0 - patch_h - (y * patch_h_stride)
            # print('{} {}'.format((value_label_x0, y0), label))
            self.draw.text((value_label_x0, y0), label, font = small_font, fill = '#000000', align = 'left')

        if self.h != 'N':
            for x, cl in enumerate(self.source.chroma_labels):
                (c, label) = cl
                x0 = patch_x0 + (x * patch_w_stride)
                # print('{} {}'.format((x0, chroma_label_y0), label))
                self.draw.text((x0, chroma_label_y0), label, font = small_font, fill = '#000000', align = 'left')

    def add_patch(self, color):
        location = self.source.find_location(color)
        if location:
            (x, y, v_label, c_label) = location
            x0 = patch_x0 + (x * patch_w_stride)
            y0 = patch_y0 - (y * patch_h_stride)
            x1 = x0 + patch_w
            y1 = y0 - patch_h
            xy = [x0, y0, x1, y1]
            r, g, b = self.source.get_rgb(color)
            fill = '#{:02X}{:02X}{:02X}'.format(r, g, b)
            # print('spec{} idx {} xy {} fill {}'.format(spec, idx, xy, fill))
            self.draw.rectangle(xy, fill = fill)
        else:
            print('Patch {} {}/{} will not be printed'.format(color['h'], color['V'], color['C']))

    def print(self):
        self.img.save('{}_{:03d}_{}.png'.format(self.source.name, self.page_num, self.h.replace(' ', '_')))
        pass


class MunsellBook:
    def __init__(self, source_name = 'rit'):
        self.source = new_color_source(source_name)
        self.current_hue = ''
        self.current_page = None
        self.source.read_data()

    def print_pages(self, page_max = -1):
        page_count = 0
        for idx, color in enumerate(self.source.data):
            hue = color['h']
            if hue != self.current_hue:
                if page_count == page_max:
                    break
                if self.current_page is not None:
                    self.current_page.print()
                page_count = page_count + 1
                self.current_hue = color['h']
                self.current_page = MunsellPage(self.source, hue)
            self.current_page.add_patch(color)

        if self.current_page is not None:
            self.current_page.print()

if __name__ == '__main__':
    book = MunsellBook('rit')
    book.print_pages()
