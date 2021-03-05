import warnings
import pytest
import numpy as np
import colour
from colormath.color_objects import sRGBColor, xyYColor, XYZColor
from colormath import color_conversions
from color_utils import *

def rgb_to_xyy_colormath(r, g, b):
    rgb_color = sRGBColor(r / 255, g / 255, b / 255)
    xyz_color = color_conversions.convert_color(rgb_color, XYZColor) 
    xyy_color = color_conversions.convert_color(rgb_color, xyYColor) 
    xyz = np.array(xyz_color.get_value_tuple())
    xyy = np.array(xyy_color.get_value_tuple())
    return (xyz, xyy)

HARD_COLORS = [
    ('Black Green', '020202'),
    ('Ivory Black', '090909'),
    ('Lamp Black', '0E0E0E'),
    ('Intense White', 'FEFBFB'),
    ('White', 'FEFCFC'),
    ('Burnt Sienna', '1E150F'),
    ('Bistre', '1B1714'),
    ('Naples Yellow', 'FEED40'),
    ('Nickel Yellow', 'FDF384'),
    ('Lemon Yellow', 'FBED28'),
    ('Bronze Green Deep', '161613'),
    ('Intense Blue', '0F1620')
]

REALPAINT_COLORS = [
    ('5YR 4.79/4.23', {
        'P3': (142.7, 110.7, 85.7),
        'sRGB': (148.7, 109.1, 81.6),
        'XYZ': (19.317, 17.911, 10.343),
        'xyY': (0.40607, 0.37651, 0.17911)}),
    ('9.7R 6.60/7.77', {
        'P3': (214.4, 148, 121.5),
        'sRGB': (226, 144.4, 116.2),
        'XYZ': (44.563, 37.496, 21.477),
        'xyY': (0.43041, 0.36216, 0.37496)})
]

CAT_METHODS = [
    'CAT02', 
    'XYZ Scaling', 
    'Von Kries', 
    'Bradford', 
    'Sharp', 
    'Fairchild', 
    'CMCCAT97', 
    'CMCCAT2000', 
    'CAT02 Brill 2008', 
    'Bianco 2010', 
    'Bianco PC 2010'
]

@pytest.mark.skip(reason='all methods are equal')
def test_cat_methods():
    for name, spaces in REALPAINT_COLORS:
        xyz_rp = np.array(spaces['XYZ'])
        srgb = np.array(spaces['sRGB']) / 255
        dist = 1000
        best = None
        for cat_method in CAT_METHODS:
            xyz_csci = colour.sRGB_to_XYZ(srgb, chromatic_adaptation_method=cat_method)
            test = np.square(xyz_rp - xyz_csci).sum()
            print(f'XYZ realpaint {xyz_rp}')
            print(f'XYZ {cat_method} {xyz_csci}')
            print(f'dist was {test}\n')

            if test < dist:
                dist = test
                best = cat_method
        print(f'best method was {best}')

        # P3 is not close -- need to correct
        # rgb_p3 = np.array(spaces['P3']) / 255
        # xyz_p3 = colour.RGB_to_XYZ(rgb_p3, ...)
        # print(f'colour P3 XYZ {xyz_p3}')

@pytest.mark.skip(reason='all illuminants are equal')
def test_realpaint_xyy():
    for name, spaces in REALPAINT_COLORS:
        xyy_rp = np.array(spaces['xyY'])
        srgb = np.array(spaces['sRGB']) / 255
        xyz = colour.sRGB_to_XYZ(srgb)
        for il_name, illuminant in [('C', ILLUMINANT_C), ('D65', ILLUMINANT_D65)]:
            xyy_csci = colour.XYZ_to_xyY(xyz, illuminant=illuminant)
            print(f'xyY realpaint {xyy_rp}')
            print(f'xyY {il_name} {xyy_csci}')

def test_realpaint_to_munsell():
    print(f'C {ILLUMINANT_C}')
    for name, spaces in REALPAINT_COLORS:
        r, g, b = spaces['sRGB']
        spec_csci = new_sRGB_to_munsell_specification(r, g, b)
        spec_interpol = mipr_sRGB_to_munsell_specification(r, g, b)
        csci = colour.notation.munsell.munsell_specification_to_munsell_colour(spec_csci)
        interpol = colour.notation.munsell.munsell_specification_to_munsell_colour(spec_interpol)
        print(f'{name} {r:3.1f}, {g:3.1f}, {b:3.1f} -> colorsci {csci}')
        print(f'{name} {r:3.1f}, {g:3.1f}, {b:3.1f} -> interpol {interpol}')

def test_realpaint_from_munsell():
    for name, spaces in REALPAINT_COLORS:
        rgb_rp = np.array(spaces['sRGB'])
        rgb_csci = new_munsell_colour_to_sRGB(name)
        rgb_csci = rgb_csci * 255
        rgb_mipr = mipr_munsell_color_to_rgb(name)
        print(f'{name} -> rgb realpaint {rgb_rp}')
        print(f'{name} -> rgb colorsci {rgb_csci}')
        print(f'{name} -> rgb interpol {rgb_mipr}')

@pytest.mark.skip(reason='later')
def test_hue_names():
    assert INTERPOL_TO_CSCI_HUE_INDEX[0] == 7
    assert INTERPOL_TO_CSCI_HUE_INDEX[9] == 8

@pytest.mark.skip(reason='later')
def test_rgb_to_xyy_alternatives():
    for name, rgb_hex in HARD_COLORS:
        r = int(rgb_hex[:2], 16)
        g = int(rgb_hex[2:4], 16)
        b = int(rgb_hex[4:6], 16)

        xyz_colormath, xyy_colormath = rgb_to_xyy_colormath(r, g, b)
        xyz_csci, xyy_csci = csci_rgb_to_adapted_xyY(r, g, b)
        np.testing.assert_array_almost_equal(xyz_colormath, xyz_csci, decimal=4)
        np.testing.assert_array_almost_equal(xyy_colormath, xyy_csci, decimal=4)

        spec_interpol = mipr_xyY_to_munsell_specification(xyy_csci)
        spec_csci = csci_xyY_to_munsell_specification(xyy_csci)

        hue, value, chroma = munsell_specification_to_near_munsell_color(spec_csci)
        print(f'{name} [{r} {g} {b}] -> {hue} {value}/{chroma}')

@pytest.mark.skip(reason='later')
def test_to_munsell_alternatives():
    for name, rgb_hex in HARD_COLORS:
        r = int(rgb_hex[:2], 16)
        g = int(rgb_hex[2:4], 16)
        b = int(rgb_hex[4:6], 16)

        xyz_csci, xyy_csci = csci_rgb_to_adapted_xyY(r, g, b)
        spec_csci = csci_xyY_to_munsell_specification(xyy_csci)
        spec_interpol = mipr_xyY_to_munsell_specification(xyy_csci)
        spec_interpol_rgb = mipr_sRGB_to_munsell_specification(r, g, b)
        print(f'{name} [{r} {g} {b}] -> colour {spec_csci}')
        print(f'{name} [{r} {g} {b}] -> R/xyY  {spec_interpol}')
        print(f'{name} [{r} {g} {b}] -> R/sRGB {spec_interpol_rgb}')


@pytest.mark.skip(reason='later')
def test_grays():
    for r, g, b in [(25*v, 25*v, 25*v) for v in range(0, 11)]:
      _xyz, xyy = csci_rgb_to_adapted_xyY(r, g, b)
      spec = csci_xyY_to_munsell_specification(xyy)
      hue, value, chroma = munsell_specification_to_near_munsell_color(spec)

      print(f'[{r} {g} {b}] -> {hue} {value}/{chroma}')
