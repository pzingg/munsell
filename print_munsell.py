#!/usr/bin/env python3

import argparse
import numpy as np

import munsellkit as mkit
import munsellkit.minterpol as mint
import munsellkit.lindbloom as mlin


# CIECAM JCh data from https://www.stilllifesmatter.com/single-post/2017/08/16/about-pigments

color_list = [
    ('Cadmium Lemon', 'CdL', 'WN', 'PY35', 85.2, 83.1, 93.0),
    ('Nickel Titanium Yellow', 'NiTiY', 'DS', 'PY54', 84.2, 55.5, 89.9),
    ('Hansa Yellow Medium', 'HaYM', 'DS', 'PY97', 80.8, 80.5, 87.0),
    ('Yellow Ochre', 'YOc', 'WN', 'PY43', 53.6, 47.7, 68.6),
    ('Hansa Yellow Deep', 'HaYD', 'DS', 'PY65', 72.4, 81.5, 66.5),
    ('Van Dyke Brown', 'VDBr', 'DS', 'PBr7', 17.6, 8.2, 65.8),
    ('Raw Umber', 'RwU', 'DS', 'PBr7', 46.6, 46.6, 64.7),
    ('Natural Sienna', 'NtS', 'DS', 'PBr7', 56.2, 59.2, 64.2),
    ('Lamp Black', 'LBk', 'DS', 'PBk7', 16.5, 7.9, 64.1),
    ('New Gamboge', 'NwGb', 'DS', 'PY153', 66.8, 76.2, 61.7),
    ('Quinacridone Gold', 'QAu', 'DS', 'PO48', 53.5, 63.3, 60.2),
    ('Raw Sienna', 'RwS', 'DS', 'PBr7', 51.0, 59.2, 55.9),
    ('Burnt Umber', 'BtU', 'DS', 'PBr7', 19.8, 15.6, 50.3),
    ('Cadmium Orange', 'CdO', 'MG', 'PO20', 61.1, 86.6, 45.6),
    ('Pyrrol Orange', 'PyO', 'DS', 'PO73', 51.2, 93.6, 38.0),
    ('Burnt Sienna', 'BtS', 'DS', 'PBr7', 37.5, 61.7, 36.1),
    ('Indian Red', 'InR', 'DS', 'PR101', 27.6, 33.5, 32.3),
    ('Quinacridone Burnt Orange', 'QBtO', 'DS', 'PO48', 33.1, 56.2, 33.1),
    ('Pyrrol Red', 'PyR', 'DS', 'PR254', 36.0, 75.9, 28.3),
    ('Quinacridone Coral', 'QC', 'DS', 'PR209', 43.0, 85.8, 28.2),
    ('Perylene Maroon', 'PeM', 'DS', 'PR179', 23.9, 38.6, 25.7),
    ('Cadmium Red', 'CdR', 'MG', 'PR108', 36.2, 71.1, 23.6),
    ('Quinacridone Rose', 'QRo', 'DS', 'PV19', 36.5, 71.7, 19.9),
    ('Quinacridone Violet', 'QV', 'DS', 'PV19', 25.7, 41.4, 13.6),
    ('Quinacridone Magenta', 'QM', 'DS', 'PR122', 32.3, 65.0, 13.4),
    ('Carbazole Violet', 'CzV', 'DS', 'PV49', 18.4, 9.7, 13.0),
    ('Cobalt Violet', 'CoV', 'Sch', 'PV49', 51.5, 57.7, 353.7),
    ('Manganese Violet', 'MnV', 'DV', 'PV16', 18.5, 28.7, 337.0),
    ('Prussian Blue', 'PrB', 'DS', 'PB27', 12.1, 24.2, 280.0),
    ('Cobalt Blue', 'CoB', 'DS', 'PB28', 20.2, 53.8, 268.3),
    ('Ultramarine Blue', 'UlB', 'MG', 'PB29', 21.4, 55.5, 264.9),
    ('Phthalo Turquoise', 'PhTq', 'WN', 'PB16', 18.6, 15.9, 233.0),
    ('Phthalo Blue', 'PhB', 'DS', 'PB15', 30.6, 46.1, 232.0),
    ('Cerulean Blue', 'CeB', 'WN', 'PB35', 35.3, 48.0, 220.1),
    ('Phthalo Green, Blue Shade', 'PhGBS', 'DS', 'PG7', 24.7, 44.6, 170.0),
    ('Viridian', 'Vir', 'DS', 'PG18', 40.7, 47.0, 166.4),
    ('Phthalo Green, Yellow Shade', 'PhGYS', 'DS', 'PG36', 22.7, 35.6, 159.7),
    ('Cobalt Green', 'CoG', 'DS', 'PG50', 35.4, 45.4, 150.1)
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
        spec = mlin.rgb_to_munsell_specification(color)
    elif space == 'jch':
        spec = mint.jch_to_munsell_specification(color)
    elif space == 'xyy':
        spec = mint.xyY_to_munsell_specification(color)
    munsell_color = mkit.normalized_color(spec, out='color')
    print(f'{name}\t{munsell_color}')


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
        for name, abbrev, mfr, pigment, j, c, h in color_list:
            name = '{:5} {}'.format(pigment, name)
            to_munsell(name, 'jch', np.array([j, c, h]))
    else:
        parser.print_help()
