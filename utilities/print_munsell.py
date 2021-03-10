#!/usr/bin/env python3

import argparse
import numpy as np

import munsellkit as mkit
import munsellkit.minterpol as mint
import munsellkit.lindbloom as mlin

import colour


# CIECAM JCh data from https://www.stilllifesmatter.com/single-post/2017/08/16/about-pigments

color_list = [
    ('Nickel Titanium Yellow', 'NiTiY', 'DS', 'PY54', 'F0DC69', 84.2, 55.5, 89.9),
    ('Hansa Yellow Medium', 'HaYM', 'DS', 'PY97', 'FDCD00', 80.8, 80.5, 87.0),
    ('Cadmium Lemon', 'CdL', 'WN', 'PY35', 'FADD00', 85.2, 83.1, 93.0),
    ('Hansa Yellow Deep', 'HaYD', 'DS', 'PY65', 'FFA300', 72.4, 81.5, 66.5),
    ('Yellow Ochre', 'YOc', 'WN', 'PY43', 'BF8A44', 53.6, 47.7, 68.6),
    ('Natural Sienna', 'NtS', 'DS', 'PBr7', 'D48830', 56.2, 59.2, 64.2),
    ('New Gamboge', 'NwGb', 'DS', 'PY153', 'FF9416', 66.8, 76.2, 61.7),
    ('Quinacridone Gold', 'QAu', 'DS', 'PO48', 'D47C26', 53.5, 63.3, 60.2),
    ('Raw Umber', 'RwU', 'DS', 'PBr7', 'AF783A', 46.6, 46.6, 64.7),
    ('Raw Sienna', 'RwS', 'DS', 'PBr7', 'CD7632', 51.0, 59.2, 55.9),
    ('Cadmium Orange', 'CdO', 'MG', 'PO20', 'FF7027', 61.1, 86.6, 45.6),
    ('Pyrrol Orange', 'PyO', 'DS', 'PO73', 'F54A22', 51.2, 93.6, 38.0),
    ('Quinacridone Burnt Orange', 'QBtO', 'DS', 'PO48', '9F4136', 33.1, 56.2, 33.1),
    ('Burnt Umber', 'BtU', 'DS', 'PBr7', '4C3835', 19.8, 15.6, 50.3),
    ('Van Dyke Brown', 'VDBr', 'DS', 'PBr7', '3C3837', 17.6, 8.2, 65.8),
    ('Burnt Sienna', 'BtS', 'DS', 'PBr7', 'B14835', 37.5, 61.7, 36.1),
    ('Pyrrol Red', 'PyR', 'DS', 'PR254', 'B93033', 36.0, 75.9, 28.3),
    ('Quinacridone Coral', 'QC', 'DS', 'PR209', 'D8353A', 43.0, 85.8, 28.2),
    ('Cadmium Red', 'CdR', 'MG', 'PR108', 'B73443', 36.2, 71.1, 23.6),
    ('Indian Red', 'InR', 'DS', 'PR101', '794441', 27.6, 33.5, 32.3),
    ('Perylene Maroon', 'PeM', 'DS', 'PR179', '733539', 23.9, 38.6, 25.7),
    ('Quinacridone Violet', 'QV', 'DS', 'PV19', '7B35AC', 25.7, 41.4, 13.6),
    ('Quinacridone Rose', 'QRo', 'DS', 'PV19', 'B9324C', 36.5, 71.7, 19.9),
    ('Quinacridone Magenta', 'QM', 'DS', 'PR122', 'A62D54', 32.3, 65.0, 13.4),
    ('Cobalt Violet', 'CoV', 'Sch', 'PV49', 'D464B6', 51.5, 57.7, 353.7),
    ('Manganese Violet', 'MnV', 'DV', 'PV16', '512D58', 18.5, 28.7, 337.0),
    ('Carbazole Violet', 'CzV', 'DS', 'PV49', '433843', 18.4, 9.7, 13.0),
    ('Lamp Black', 'LBk', 'DS', 'PBk7', '383534', 16.5, 7.9, 64.1),
    ('Ultramarine Blue', 'UlB', 'MG', 'PB29', '213D81', 21.4, 55.5, 264.9),
    ('Cobalt Blue', 'CoB', 'DS', 'PB28', '2837A9', 20.2, 53.8, 268.3),
    ('Phthalo Blue', 'PhB', 'DS', 'PB15', '006BA9', 30.6, 46.1, 232.0),
    ('Prussian Blue', 'PrB', 'DS', 'PB27', '23254E', 12.1, 24.2, 280.0),
    ('Phthalo Turquoise', 'PhTq', 'WN', 'PB16', '274156', 18.6, 15.9, 233.0),
    ('Cerulean Blue', 'CeB', 'WN', 'PB35', '007CB0', 35.3, 48.0, 220.1),
    ('Phthalo Green, Blue Shade', 'PhGBS', 'DS', 'PG7', '006350', 24.7, 44.6, 170.0),
    ('Viridian', 'Vir', 'DS', 'PG18', '009279', 40.7, 47.0, 166.4),
    ('Phthalo Green, Yellow Shade', 'PhGYS', 'DS', 'PG36', '005842', 22.7, 35.6, 159.7),
    ('Cobalt Green', 'CoG', 'DS', 'PG50', '008054', 35.4, 45.4, 150.1)
    #    ('Bismuth Yellow', 'BiY', 'MG', 'PY184'),
    #    ('Cobalt Teal', 'CoT', 'MG', 'PB28'),
    #    ('Cobalt Violet Deep', 'CoVD', 'MG', 'PV14'),
    #    ('Indian Yellow', 'InY', 'MG', 'PY110'),
    #    ('Nickel Azo Yellow', 'NiAzY', 'MG', 'PY150'),
    #    ('Naples Yellow', 'NpY', 'MG', 'PBr24'),
    #    ('Ultramarine Pink', 'UlPk', 'MG', 'PR258'),
    #    ('Ultramarine Violet Deep', 'UlVD', 'MG', 'PV15'),
]


def to_munsell(name, space, color):
    if space == 'rgb':
        spec = mlin.rgb_to_munsell_specification(color[0], color[1], color[2])
    elif space == 'jch_mint':
        spec = mint.jch_to_munsell_specification(color)
    elif space == 'jch_mlin':
        spec = mlin.jch_to_munsell_specification(color)
    elif space == 'xyy':
        spec = mint.xyY_to_munsell_specification(color)
    munsell_color = mkit.normalized_color(spec, out='color')
    print(f'{name:10s} {space:8s} {munsell_color}')



if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Convert colors to Munsell.')
    parser.add_argument('name', type=str, nargs='?')
    parser.add_argument('space', type=str, nargs='?', help='jch or rgb only')
    parser.add_argument('spec', type=float, nargs='*')
    args = parser.parse_args()

    if len(args.spec) == 3:
        if args.name and args.space:
            to_munsell(args.name, args.space.lower(), np.array(args.spec))
        else:
            parser.print_help()
    elif len(args.spec) == 0:
        for name, abbrev, mfr, pigment, hex, j, c, h in color_list:
            jch = np.array([j, c, h])
            to_munsell(abbrev, 'jch_mint', jch)
            to_munsell(abbrev, 'jch_mlin', jch)

            r = int(hex[0:2], 16)
            g = int(hex[2:4], 16)
            b = int(hex[4:6], 16)
            rgb = np.array([r, g, b])
            to_munsell(abbrev, 'rgb', rgb)
    else:
        parser.print_help()
