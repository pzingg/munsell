#!/usr/bin/env python3

import colour
import csv
import json
import numpy as np


import munsellkit as mkit
import munsellkit.lindbloom as mlin


class NamedColor:
    def __init__(self, name, data, rgb):
        self.name = name
        self.data = data
        self.rgb = rgb


def read_jsonline(fname):
    colors = []
    with open(fname) as f:
        for line in f.readlines():
            row = json.loads(line)
            # cmyk = np.array([float(row[s])/100.0 for s in ['c', 'm', 'y', 'k']], dtype=float)
            rgb = [min(255, max(0, int(row[s]))) for s in ['r', 'g', 'b']]
            color = NamedColor(row['identifier'], [row['name']],
                               rgb)
            colors.append(color)
        return colors


COLUMNS = [
    'Brand Name',
    'Identifier',
    'Munsell Specification',
    'Total Hue',
    'Hue Prefix',
    'Hue Letter(s)',
    'ASTM Hue',
    'Value',
    'Chroma',
    'Color Name',
    'HTML RGB'
]

def generate_csv(brand):
    colors = read_jsonline(f'{brand.lower()}.jsonl')
    with open(f'{brand}Munsell.csv', 'w') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(COLUMNS)
        for ni, color in enumerate(colors):
            hex = f'#{color.rgb[0]:02X}{color.rgb[1]:02X}{color.rgb[2]:02X}'
            spec = mlin.rgb_to_munsell_specification(color.rgb[0], color.rgb[1], color.rgb[2])
            munsell_color, spec, hue = mkit.normalized_color(spec, out='all')
            hue_shade, value, chroma, hue_index = spec
            row = [
                brand,
                color.name,
                munsell_color,
                hue['total_hue'],
                hue_shade,
                hue['hue_name'],
                hue['astm_hue'],
                value,
                chroma,
                color.data[0],
                hex
            ]
            print(','.join([str(v) for v in row]))
            writer.writerow(row)

if __name__ == '__main__':
    generate_csv('Sennelier')
    generate_csv('Unison')
    generate_csv('Nupastel')
