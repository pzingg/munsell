import warnings
import numpy as np
import colour
from colormath.color_objects import sRGBColor, xyYColor, XYZColor
from colormath import color_conversions
from safe_xyy_to_munsell import safe_xyY_to_munsell_specification, munsell_specification_to_near_munsell_color


def rgb_to_xyy_colormath(r, g, b):
    rgb_color = sRGBColor(r / 255, g / 255, b / 255)
    xyz_color = color_conversions.convert_color(rgb_color, XYZColor) 
    xyy_color = color_conversions.convert_color(rgb_color, xyYColor) 
    xyz = np.array(xyz_color.get_value_tuple())
    xyy = np.array(xyy_color.get_value_tuple())
    return (xyz, xyy)

def rgb_to_xyy_colour(r, g, b):
    rgb = np.array([r / 255, g / 255, b / 255])
    xyz = colour.sRGB_to_XYZ(rgb)
    xyy = colour.XYZ_to_xyY(xyz)
    return (xyz, xyy)

def test_rgb_to_xyy():
    hardcolors = [
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


    for name, rgb_hex in hardcolors:
        r = int(rgb_hex[:2], 16)
        g = int(rgb_hex[2:4], 16)
        b = int(rgb_hex[4:6], 16)

        xyz_colormath, xyy_colormath = rgb_to_xyy_colormath(r, g, b)
        xyz_colour, xyy_colour = rgb_to_xyy_colour(r, g, b)
        np.testing.assert_array_almost_equal(xyz_colormath, xyz_colour, decimal=4)
        np.testing.assert_array_almost_equal(xyy_colormath, xyy_colour, decimal=4)

        spec = safe_xyY_to_munsell_specification(xyy_colour)
        hue, value, chroma = munsell_specification_to_near_munsell_color(spec)

        print(f'{name} [{r} {g} {b}] -> {hue} {value}/{chroma}')


def test_grays():
    for r, g, b in [(25*v, 25*v, 25*v) for v in range(0, 11)]:
      _xyz, xyy = rgb_to_xyy_colour(r, g, b)
      spec = safe_xyY_to_munsell_specification(xyy)
      hue, value, chroma = munsell_specification_to_near_munsell_color(spec)

      print(f'[{r} {g} {b}] -> {hue} {value}/{chroma}')
