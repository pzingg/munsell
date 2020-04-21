#/usr/bin/python3.5

from colormath.color_objects import XYZColor, CMYKColor, sRGBColor, LabColor, HSVColor
from colormath.color_diff import delta_e_cie1976
from colormath.color_conversions import convert_color
import csv
import json
import re
import subprocess
import sys


HUES = [ 'R', 'YR', 'Y', 'GY', 'G', 'BG', 'B', 'PB', 'P', 'RP' ]
VERBOSE = False
ORDER_BY_VALUE = False
ORDER_BY_MUNSELL = False

class NamedColor:
    def __init__(self, name, data, lab_color, rgb, hue_key, value_key):
        self.name = name
        self.data = data
        self.lab_color = lab_color
        self.rgb = rgb
        self.hue_key = hue_key
        self.value_key = value_key


class ColorDiff:
    def __init__(self, source_index, source_name, target_index, target_name, delta_e):
        self.source_index = source_index
        self.source_name = source_name
        self.target_index = target_index
        self.target_name = target_name
        self.delta_e = delta_e

# h is float in range(0, 360)
# s and v are floats in range (0, 1)
def hsv_keys(h, s, v):
    h_val = round(h * 10)      # in range(0, 3600)
    v_val = round(v * 100.0)   # in range(0, 100)
    c_val = round(s * 100.0)   # in range(0, 100)
    hue_key = (h_val * 100 * 100) + (v_val * 100) + c_val
    value_key = (v_val * 1000 * 100) + (h_val * 100) + c_val
    return (hue_key, value_key)

def read_nupastel(fname = 'nupastel_data.json'):
    colors = []
    with open(fname) as f:
        data = json.load(f)
        for row in data['maincolors']:
            c, m, y, k = [ float(s)/100.0 for s in row['CMYK'].split(',') ]
            cmyk_color = CMYKColor(c, m, y, k)
            lab_color = convert_color(cmyk_color, LabColor)
            hsv_color = convert_color(cmyk_color, HSVColor)
            hue_key, value_key = hsv_keys(hsv_color.hsv_h, hsv_color.hsv_s, hsv_color.hsv_v)
            r, g, b = [ int(s) for s in row['rgb'].split(',') ]
            rgb = '#{0:02x}{1:02x}{2:02x}'.format(r, g, b)
            color = NamedColor(row['colorCode'], [ row['colorName'] ],
                lab_color, rgb, hue_key, value_key)
            colors.append(color)
    if ORDER_BY_VALUE:
        return sorted(colors, key = lambda x: x.value_key)
    else:
        return sorted(colors, key = lambda x: x.hue_key)

def read_unison(fname = 'unison_data.csv'):
    colors = []
    with open(fname) as f:
        reader = csv.DictReader(f)
        for row in reader:
            r, g, b = int(row['r']), int(row['g']), int(row['b'])
            rgb_color = sRGBColor(r, g, b, is_upscaled=True)
            lab_color = convert_color(rgb_color, LabColor)
            hsv_color = convert_color(rgb_color, HSVColor)
            hue_key, value_key = hsv_keys(hsv_color.hsv_h, hsv_color.hsv_s, hsv_color.hsv_v)
            rgb = '#{0:02x}{1:02x}{2:02x}'.format(r, g, b)
            color = NamedColor(row['id'], [ row['name'] ],
                lab_color, rgb, hue_key, value_key)
            colors.append(color)
    if ORDER_BY_VALUE:
        return sorted(colors, key = lambda x: x.value_key)
    else:
        return sorted(colors, key = lambda x: x.hue_key)

def generate_nupastel_csv():
    colors = read_nupastel()
    with open('nupastel_munsell.csv', 'w') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['id', 'name', 'h', 'v', 'c'])
        for ni, nupastel_color in enumerate(colors):
            hue, value, chroma = interpolate(nupastel_color)
            writer.writerow([nupastel_color.name[0:3], nupastel_color.data[0],
                hue, '{:g}'.format(value), '{:g}'.format(chroma)])

def generate_unison_csv():
    colors = read_unison()
    with open('unison_munsell.csv', 'w') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['id', 'name', 'h', 'v', 'c'])
        for ni, nupastel_color in enumerate(colors):
            hue, value, chroma = interpolate(nupastel_color)
            writer.writerow([nupastel_color.name[0:3], nupastel_color.data[0],
                hue, '{:g}'.format(value), '{:g}'.format(chroma)])

def interpolate(color):
    l, a, b = color.lab_color.get_value_tuple()
    arg = '{:.4f} {:.4f} {:.4f}'.format(l, a, b)
    result = subprocess.check_output([ '/usr/bin/Rscript', 'lab_to_munsell.R', arg ])
    result = ''.join(map(chr, result)).strip()
    hue, value, chroma = result.split(' ')
    value = float(value)
    if hue == 'NA':
        hue = 'N'
        chroma = 0
    else:
        chroma = float(chroma)
    print('{} -> {} {:g}/{:g}'.format(color.data[0], hue, value, chroma))
    return (hue, value, chroma)

if __name__ == '__main__':
    generate_unison_csv()
