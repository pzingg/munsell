import csv
import os
import colour
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import munsellkit as mkit
import munsellkit.minterpol as mint
import munsellkit.lindbloom as mlin

def sample_file(path, sample_size, max_search):
    with Image.open(path) as im:
        name, _ext = os.path.splitext(path)
        with open(name + '.csv', 'w', newline='') as csvfile:
            w = im.width
            h = im.height
            largest = max(w, h)
            span = largest // sample_size
            if largest == w:
                orientation = 'landscape'
                span_w = span
                sample_size_h = (2 * h + span) // (2 * span)
                span_h = h // sample_size_h
                search_size = min(span_h // 3, max_search)
            else:
                orientation = 'portrait'
                span_h = span
                sample_size_w = (2 * w + span) // (2 * span)
                span_w = w // sample_size_w
                search_size = min(span_w // 3, max_search)
            print(f'{path}: {orientation}, h {h} w {w} span_h {span_h} span_w {span_w} search {search_size}')

            out = csv.writer(csvfile, quoting=csv.QUOTE_MINIMAL)
            out.writerow(['i', 'j', 'x', 'y', 'munsell', 'hue_index', 'total_hue', 'value', 'chroma'])

            y = span_h // 2
            i = 1
            while y < h:
                x = span_w // 2
                j = 1
                while x < w:
                    xp, yp, r, g, b, = find_most_saturated(im, x, y, search_size)
                    print(f'{i}, {j} ({xp}, {yp}): {r} {g} {b}')
                    spec = mint.rgb_to_munsell_specification(r, g, b)
                    munsell_color, spec, data = mkit.normalized_color(spec, rounding='renotation', out='all')
                    out.writerow([i, j, xp, yp, munsell_color, spec[3]*10.0 + spec[0], data['total_hue'], spec[1], spec[2]])
                    x += span_w
                    j += 1
                y += span_h
                i += 1

def find_most_saturated(im, x, y, search_size):
    if search_size < 1:
        r, g, b = im.getpixel((x, y))
        return (x, y, r, g, b)

    highest_s = -1.0
    highest = (-1, -1, 0, 0, 0)
    for xp in range(x - search_size, x + search_size + 1):
        for yp in range(y - search_size, y + search_size + 1):
            r, g, b = im.getpixel((xp, yp))
            rgb = np.array([r / 255.0, g / 255.0, b / 255.0])
            s = colour.RGB_to_HSV(rgb)[1]
            if s > highest_s:
                highest_s = s
                highest = (xp, yp, r, g, b)
    return highest

if __name__ == '__main__':
    import argparse
    import re

    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-n', '--num-samples', help='number of samples in longest dimension', type=int, default=12, metavar='SAMPLES')
    parser.add_argument(
        '-b', '--search-box', help='search box size for highest saturation', type=int, default=10, metavar='PIXELS')
    parser.add_argument(
        'file', help='path to image file (.jpg, .png) to be sampled', metavar='FILE')

    args = parser.parse_args()
    sample_file(args.file, args.num_samples, args.search_box)
