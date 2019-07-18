#/usr/bin/python3.5

from colormath.color_objects import XYZColor, CMYKColor, sRGBColor, LabColor, HSVColor
from colormath.color_diff import delta_e_cie1976
from colormath.color_conversions import convert_color
import csv
import json
import re
import sys

HUES = [ 'R', 'YR', 'Y', 'GY', 'G', 'BG', 'B', 'PB', 'P', 'RP' ]
VERBOSE = False
ORDER_BY_VALUE = False
ORDER_BY_MUNSELL = False


class MunsellError(Exception):
    """Exception raised for errors in the input.

    Attributes:
        message -- explanation of the error
    """

    def __init__(self, message):
        self.message = message

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
    nupastel_colors = []
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
            nupastel_colors.append(color)
    if ORDER_BY_VALUE:
        return sorted(nupastel_colors, key = lambda x: x.value_key)
    else:
        return sorted(nupastel_colors, key = lambda x: x.hue_key)

# h is string of form "2.5BG"
# v is int in range(1, 9)
# c is int in range(2, 26)
def munsell_keys(name, h, v, c):
    if v < 1 or v > 9:
        raise MunsellError('Bad value in {0}: {1}'.format(name, c))

    if c < 2 or c > 26:
        raise MunsellError('Bad chroma in {0}: {1}'.format(name, c))

    m = re.match(r'([.0-9]+)([BGPRY]+)', h)
    if m is None:
        raise MunsellError("Bad hue in {0}: {1}".format(name, h))

    hi = HUES.index(m.group(2))
    if hi < 0:
        raise MunsellError("Hue not found in {0}: {1}".format(name, h))
    astm_base = hi*10           # in range (0, 90)

    h_factor = m.group(1)
    hb = float(h_factor)
    if hb < 0.0 or hb > 10.0:
        raise MunsellError("Bad hue factor in {0}: {1}".format(name, h_factor))

    h_val = astm_base + float(m.group(1)) # in range (0, 100)
    v_val = v * 10                        # in range (10, 100)
    c_val = c * 3                         # in range (6, 78)
    hue_key =   (h_val * 100 * 100) + (v_val * 100) + c_val
    value_key = (v_val * 100 * 100) + (h_val * 100) + c_val
    return (hue_key, value_key)

def read_munsell(fname = 'munsell_data.txt'):
    munsell_colors = []
    with open(fname) as f:
        reader = csv.DictReader(f, delimiter = '\t', lineterminator = '\n')
        for row in reader:
            xyz_color = XYZColor(float(row['X_D65']), float(row['Y_D65']), float(row['Z_D65']),
                observer='2', illuminant='d65')
            lab_color = convert_color(xyz_color, LabColor)
            h, v, c = row['h'], row['V'], row['C']
            data = [ h, v, c ]
            name = '{0} {1}/{2}'.format(h, v, c)
            hue_key, value_key = munsell_keys(name, h, int(v), int(c))
            r, g, b = int(row['dR']), int(row['dG']), int(row['dB'])
            rgb = '#{0:02x}{1:02x}{2:02x}'.format(r, g, b)
            color = NamedColor(name, data,
                lab_color, rgb, hue_key, value_key)
            munsell_colors.append(color)
    if ORDER_BY_VALUE:
        return sorted(munsell_colors, key = lambda x: x.value_key)
    else:
        return sorted(munsell_colors, key = lambda x: x.hue_key)

def color_diffs(source_colors, target_colors):
    diffs = []
    for si, source_color in enumerate(source_colors):
        for ti, target_color in enumerate(target_colors):
            delta_e = delta_e_cie1976(source_color.lab_color, target_color.lab_color)
            diff = ColorDiff(si, source_color.name, ti, target_color.name, delta_e)
            diffs.append(diff)
    return sorted(diffs, key = lambda d: d.delta_e)

def closest_target_for_source(diffs, source_name):
    return (d for d in diffs if d.source_name == source_name)

def closest_source_for_target(diffs, target_name):
    return (d for d in diffs if d.target_name == target_name)

def generate_html():
    munsell_colors = read_munsell()
    nupastel_colors = read_nupastel()
    diffs = color_diffs(nupastel_colors, munsell_colors)
    nupastel_to_munsell = []

    print('<html><head><title>Colors</title></head><body>')
    print('<h2>Closest Munsell Color(s) for each NuPastel</h2>')
    print('<table><tr><th>{0:6} {1:>20}</th><th>&nbsp;</th><th>&nbsp;</th><th>&nbsp;</th><th>{2:5} {3:>2} {4:>2}</th></tr>'.format('SKU', 'Color Name', 'Hue', 'V', 'C'))

    for ni, nupastel_color in enumerate(nupastel_colors):
        for closest in closest_target_for_source(diffs, nupastel_color.name):
            mi = closest.target_index
            nupastel_to_munsell.append((ni, mi))
            break

    if ORDER_BY_MUNSELL:
        nupastel_to_munsell = sorted(nupastel_to_munsell, key = lambda x: x[1])

    for ni, mi in nupastel_to_munsell:
        nupastel_color = nupastel_colors[ni]
        munsell_color = munsell_colors[mi]
        print('<tr><td>{0:6} {1:>20}</td><td width="60" height="30" style="background-color: {2}">&nbsp;</td>'.format(
            nupastel_color.name, nupastel_color.data[0], nupastel_color.rgb))
        print('<td>-&gt;</td>')
        print('<td width="60" height="30" style="background-color: {0}">&nbsp;</td><td>{1:5} {2:>2} {3:>2}</td></tr>'.format(
            munsell_color.rgb, munsell_color.data[0], munsell_color.data[1], munsell_color.data[2]))

    print('</table>')

    print('<h2>Closest NuPastel(s) for each Munsell Color</h2>')
    print('<table><tr><th>{0:6} {1:>20}</th><th>&nbsp;</th><th>&nbsp;</th><th>&nbsp;</th><th>{2:5} {3:>2} {4:>2}</th></tr>'.format('SKU', 'Color Name', 'Hue', 'V', 'C'))

    for mi, munsell_color in enumerate(munsell_colors):
        closest_3 = []
        i = 0
        for closest in closest_source_for_target(diffs, munsell_color.name):
            closest_3.append(closest.source_index)
            i = i + 1
            if i == 3:
                break

        for i, ni in enumerate(closest_3):
            nupastel_color = nupastel_colors[ni]
            print('<tr><td>{0:6} {1:>20}</td><td width="60" height="30" style="background-color: {2}">&nbsp;</td>'.format(
                nupastel_color.name, nupastel_color.data[0], nupastel_color.rgb))
            if i == 0:
                print('<td>&lt;-</td>')
                print('<td width="60" height="30" style="background-color: {0}">&nbsp;</td><td>{1:5} {2:>2} {3:>2}</td></tr>'.format(
                    munsell_color.rgb, munsell_color.data[0], munsell_color.data[1], munsell_color.data[2]))
            else:
                print('<td colspan="3">&nbsp;</td></tr>')

    print('</table>')
    print('</body></html>')

def generate_csv():
    munsell_colors = read_munsell()
    nupastel_colors = read_nupastel()
    diffs = color_diffs(nupastel_colors, munsell_colors)
    nupastel_to_munsell = []

    for ni, nupastel_color in enumerate(nupastel_colors):
        for closest in closest_target_for_source(diffs, nupastel_color.name):
            mi = closest.target_index
            nupastel_to_munsell.append((ni, mi))
            break

    with open('nupastel-munsell.csv', 'w') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['id', 'name', 'h', 'v', 'c'])
        for ni, mi in nupastel_to_munsell:
            nupastel_color = nupastel_colors[ni]
            munsell_color = munsell_colors[mi]
            writer.writerow([nupastel_color.name[0:3], nupastel_color.data[0],
                munsell_color.data[0], munsell_color.data[1], munsell_color.data[2]])


if __name__ == '__main__':
    generate_csv()
