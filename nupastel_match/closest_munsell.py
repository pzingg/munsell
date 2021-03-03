#!/usr/bin/env python3

import colour
import csv
import json
import numpy as np


HUES = ['R', 'YR', 'Y', 'GY', 'G', 'BG', 'B', 'PB', 'P', 'RP']
VERBOSE = False
ORDER_BY_VALUE = False
ORDER_BY_MUNSELL = False


class NamedColor:
    def __init__(self, name, data, xyy, rgb, hue_key, value_key):
        self.name = name
        self.data = data
        self.xyy = xyy
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

def hsv_keys(hsv):
    # print(f'hsv {hsv}')
    h_val = round(hsv[0] * 3600)    # in range(0, 3600)
    c_val = round(hsv[1] * 100.0)   # in range(0, 100)
    v_val = round(hsv[2] * 100.0)   # in range(0, 100)
    hue_key = (h_val * 100 * 100) + (v_val * 100) + c_val
    value_key = (v_val * 1000 * 100) + (h_val * 100) + c_val
    return (hue_key, value_key)


def clamp_to_macadam(xyy, hsv):
    if xyy[2] < 0.15:
        # print(f'low Y {hsv}')
        xyy[2] = 0.2
    elif xyy[2] > 0.6:
        # print(f'high Y {hsv}')
        xyy[2] = 0.6
    return xyy

def my_RGB_to_XYZ(rgb):
    illuminant_RGB = np.array([0.31270, 0.32900])
    illuminant_XYZ = np.array([0.34570, 0.35850])
    chromatic_adaptation_transform = 'Bradford'
    matrix_RGB_to_XYZ = np.array(
        [[0.41240000, 0.35760000, 0.18050000],
        [0.21260000, 0.71520000, 0.07220000],
        [0.01930000, 0.11920000, 0.95050000]]
    )
    return colour.RGB_to_XYZ(rgb, illuminant_RGB, illuminant_XYZ, 
        matrix_RGB_to_XYZ,
        chromatic_adaptation_transform)  

def read_jsonline(fname):
    colors = []
    with open(fname) as f:
        for line in f.readlines():
            row = json.loads(line)
            # cmyk = np.array([float(row[s])/100.0 for s in ['c', 'm', 'y', 'k']], dtype=float)
            rgb = [min(255, max(0, int(row[s]))) for s in ['r', 'g', 'b']]
            hex = f'#{rgb[0]:02X}{rgb[1]:02X}{rgb[2]:02X}'
            rgb = np.array(rgb, dtype=float)
            rgb = rgb / 255.
            hsv = colour.RGB_to_HSV(rgb)
            xyz = colour.sRGB_to_XYZ(rgb)
            xyy = colour.XYZ_to_xyY(xyz)
            xyy = clamp_to_macadam(xyy, hsv)

            # print(f'xyy {xyy}')
            hue_key, value_key = hsv_keys(hsv)
            color = NamedColor(row['identifier'], [row['name']],
                               xyy, hex, hue_key, value_key)
            colors.append(color)
    if ORDER_BY_VALUE:
        return sorted(colors, key=lambda x: x.value_key)
    else:
        return sorted(colors, key=lambda x: x.hue_key)


MUNSELL_HUE_LETTER_CODES = [
    'B', #: 1,
    'BG', #: 2,
    'G', # : 3,
    'GY', # : 4,
    'Y', # : 5,
    'YR', # : 6,
    'R', # : 7,
    'RP', # : 8,
    'P', # : 9
    'PB' #: 10,
]

def generate_csv(name):
    colors = read_jsonline(f'{name}.jsonl')
    with open(f'{name}_munsell.csv', 'w') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['id', 'name', 'rgb', 'x', 'y', 'big_Y', 'h', 'v', 'c'])
        for ni, color in enumerate(colors):
            try:
                spec = colour.notation.munsell.xyY_to_munsell_specification(color.xyy)
                if spec[2] < 2:
                    spec[2] == 2
                hue_code = int(spec[3])
                hue_scale = round(spec[0]/2.5) * 2.5
                if hue_scale == 0:
                    hue_scale = 10
                else:
                    hue_code = hue_code - 1
                hue_letter = MUNSELL_HUE_LETTER_CODES[hue_code % 10]
                hue = f'{hue_scale}{hue_letter}'
                # munsell_color = colour.notation.munsell.munsell_specification_to_munsell_colour(spec, hue_decimals=1, value_decimals=0, chroma_decimals=0)
                # print(f'hue {hue} <-> {munsell_color}')
                value = round(spec[1])
                chroma = round(spec[2])
            except Exception as e:
                hue = 'N'
                value = 0
                chroma = 0
            writer.writerow([color.name, color.data[0],
                color.rgb, f'{color.xyy[0]:04f}', f'{color.xyy[1]:04f}', 
                f'{color.xyy[2]:04f}',
                hue, str(value), str(chroma)])

if __name__ == '__main__':
    generate_csv('sennelier')
    # generate_csv('unison')
    # generate_csv('nupastel')
