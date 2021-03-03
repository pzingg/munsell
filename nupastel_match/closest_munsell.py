#!/usr/bin/env python3

import colour
import csv
import json
import numpy as np
from safe_xyy_to_munsell import safe_xyY_to_munsell_specification, munsell_specification_to_near_munsell_color


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

def generate_csv(name):
    colors = read_jsonline(f'{name}.jsonl')
    with open(f'{name}_munsell.csv', 'w') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['id', 'name', 'rgb', 'x', 'y', 'big_Y', 'h', 'v', 'c'])
        for ni, color in enumerate(colors):
            spec = safe_xyY_to_munsell_specification(color.xyy)
            hue, value, chroma = munsell_specification_to_near_munsell_color(spec)
            writer.writerow([color.name, color.data[0],
                color.rgb, f'{color.xyy[0]:04f}', f'{color.xyy[1]:04f}', 
                f'{color.xyy[2]:04f}',
                hue, str(value), str(chroma)])

if __name__ == '__main__':
    generate_csv('sennelier')
    # generate_csv('unison')
    # generate_csv('nupastel')
