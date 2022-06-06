import csv
import os
from PIL import Image, ImageDraw, ImageFont
import munsellkit as mkit
import munsellkit.minterpol as mint
import munsellkit.lindbloom as mlin

def sample_file(path, sample_size):
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
            else:
                orientation = 'portrait'
                span_h = span
                sample_size_w = (2 * w + span) // (2 * span)
                span_w = w // sample_size_w
            print(f'{path}: {orientation}, h {h} w {w} span_h {span_h} span_w {span_w}')

            out = csv.writer(csvfile, quoting=csv.QUOTE_MINIMAL)
            out.writerow(['i', 'j', 'x', 'y', 'munsell', 'hue_index', 'total_hue', 'value', 'chroma'])

            y = span_h // 2
            i = 1
            while y < h:
                x = span_w // 2
                j = 1
                while x < w:

                    print(f'{i}, {j} ({x}, {y})')
                    r, g, b = im.getpixel((x, y))
                    print(f'   : {r} {g} {b}')
                    spec = mint.rgb_to_munsell_specification(r, g, b)
                    munsell_color, spec, data = mkit.normalized_color(spec, rounding='renotation', out='all')
                    out.writerow([i, j, x, y, munsell_color, spec[3]*10.0 + spec[0], data['total_hue'], spec[1], spec[2]])
                    x += span_w
                    j += 1
                y += span_h
                i += 1

if __name__ == '__main__':
    import argparse
    import re

    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--size', help='number of samples in longest dimension', type=int, default=10, metavar='COLOR')
    parser.add_argument(
        'file', help='path to image file (.jpg, .png) to be sampled', metavar='FILE')

    args = parser.parse_args()
    sample_file(args.file, args.size)
