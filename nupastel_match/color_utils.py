import json
import warnings
import subprocess
import numpy as np
import colour
from colour import notation, utilities, volume

INTERPOL_HUE_NAMES = [
    'R',
    'YR',
    'Y',
    'GY',
    'G',
    'BG',
    'B',
    'PB',
    'P',
    'RP'
]

COLORSCI_HUE_NAMES = [
    'B', # 1,
    'BG', # 2
    'G', # 3
    'GY', # 4
    'Y', # 5
    'YR', # 6
    'R', # 7
    'RP', # 8
    'P', # 9
    'PB' # 10
]

# 7, 6, 5, 4, 3, 2, 1, 10, 9, 8
INTERPOL_TO_CSCI_HUE_INDEX = list([
    COLORSCI_HUE_NAMES.index(name) + 1 for name in INTERPOL_HUE_NAMES
])

# These two functions from 
# https://stackoverflow.com/questions/3620663/color-theory-how-to-convert-munsell-hvc-to-rgb-hsb-hsl

# See https://patapom.com/blog/Colorimetry/Illuminants
# CIE 1931 2 Degree Standards
# D65 is sRGB standard
ILLUMINANT_D65 = np.array([0.31270, 0.32900])
# C is Munsell standard
# np.array([0.31006, 0.31616])
ILLUMINANT_C = colour.ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['C']
# Another standard
ILLUMINANT_D50 = np.array([0.34570, 0.35850])

def new_munsell_colour_to_sRGB(color):
    # The first step is to convert the Munsell color to *CIE xyY* 
    # colorspace.
    xyY = colour.notation.munsell.munsell_colour_to_xyY(color)

    # We then perform conversion to *CIE XYZ* tristimulus values.
    XYZ = colour.xyY_to_XYZ(xyY)

    # The last step will involve using the *Munsell Renotation System*
    # illuminant which is *CIE Illuminant C*:
    # http://nbviewer.ipython.org/github/colour-science/colour-ipython/blob/master/notebooks/colorimetry/illuminants.ipynb#CIE-Illuminant-C
    # It is necessary in order to ensure white stays white when
    # converting to *sRGB* colourspace and its different whitepoint 
    # (*CIE Standard Illuminant D65*) by performing chromatic 
    # adaptation between the two different illuminant.
    return colour.XYZ_to_sRGB(XYZ, ILLUMINANT_C)

def new_sRGB_to_munsell_specification(r, g, b):
    rgb = np.array([r / 255, g / 255, b / 255])
    XYZ = colour.sRGB_to_XYZ(rgb, ILLUMINANT_C)
    xyY = colour.XYZ_to_xyY(XYZ)
    return colour.notation.munsell.xyY_to_munsell_specification(xyY)

# CAT
# See http://brucelindbloom.com/index.html?Eqn_ChromAdapt.html
CAT_BRADFORD_D65_TO_C = np.array([
    [ 0.9821687, -0.0067531,  0.0518013],
    [-0.0044921,  0.9893393,  0.0162333],
    [ 0.0114719, -0.0199953,  1.2928395]])
CAT_BRADFORD_C_TO_D65 = np.array([
    [ 0.9904476, -0.0071683, -0.0116156],
    [-0.0123712,  1.0155950, -0.0029282],
    [-0.0035635,  0.0067697,  0.9181569]])

def csci_rgb_to_adapted_xyY(r, g, b):
    '''Convert RGB input into CIE XYZ and xyY coordinates.'''
    rgb = np.array([r / 255, g / 255, b / 255])

    # xyz = colour.RGB_to_XYZ(rgb, ILLUMINANT_D65, ILLUMINANT_C, 
    #    CAT_BRADFORD_D65_TO_C, 'Bradford')
    xyz = colour.sRGB_to_XYZ(rgb, chromatic_adaptation_method='Bradford')

    # adapt xyY from the RGB space white to C
    xyy_adapted = colour.XYZ_to_xyY(xyz, ILLUMINANT_C)
    return (xyz, xyy_adapted)

def get_munsell_value(Y):
    with utilities.common.domain_range_scale('ignore'):
        return notation.munsell_value_ASTMD1535(Y * 100)

def adjust_to_macadam_limits(xyY):
    if volume.is_within_macadam_limits(xyY, munsell.ILLUMINANT_NAME_MUNSELL):
        return xyY

    Y = xyY[2]
    xyY_temp = np.array(xyY)
    step = (0.5 - Y) / 100.
    for i in range(0, 100):
        xyY_temp[2] = Y + i * step
        if volume.is_within_macadam_limits(xyY_temp, munsell.ILLUMINANT_NAME_MUNSELL):
            warnings.warn(f'Y adjusted from {Y:.03f} to {xyY_temp[2]:.03f}')
            return xyY_temp
    
    raise RuntimeError(f'Could not adjust MacAdam for xyY {xyY}')

def adjust_value_up(xyY):
    Y = xyY[2]
  
    # Already in domain '1'
    # Y = to_domain_1(Y)

    value = get_munsell_value(Y)
    if value > 10:
        raise RuntimeError(f'Munsell value {value:.03f} exceeds 10 for xyY {xyY}')
    if Y == 0 or value >= 1:
        return (xyY, value)

    xyY_temp = np.array(xyY)
    step = (0.2 - Y) / 100.
    i = 1
    while i <= 100:
        Y_temp = Y + i * step
        new_value = get_munsell_value(Y_temp)
        if new_value > 10:
            break
        if new_value >= 1:
            warnings.warn(f'Y adjusted up from {Y:.03f} to {Y_temp:.03f}: value from {value:.03f} to {new_value:.03f}')
            xyY_temp[2] = Y_temp
            return (xyY_temp, new_value)
        i += 1

    raise RuntimeError(f'Could not adjust Munsell value up for xyY {xyY}, last Y tested was {Y_temp:.03f}')

def adjust_value_down(xyY, value):
    Y = xyY[2]

    # Already in domain '1'
    # Y = to_domain_1(Y)
    if Y < 0.8:
        raise RuntimeError(f'Xyy value {Y:.03f} is too low to adjust down')

    if value is None:
        value = get_munsell_value(Y)
    if value > 10:
        raise RuntimeError(f'Munsell value {value:.03f} exceeds 10 for xyY {xyY}')

    xyY_temp = np.array(xyY)
    step = (0.8 - Y) / 100.
    i = 1
    while i <= 100:
        Y_temp = Y + i * step
        new_value = get_munsell_value(Y_temp)
        if new_value > 10:
            break
        xyY_temp[2] = Y_temp
        try:
            munsell_spec = notation.munsell.xyY_to_munsell_specification(xyY_temp)
            warnings.warn(f'Y adjusted down from {Y:.03f} to {Y_temp:.03f}: value from {value:.03f} to {new_value:.03f}')
            return (xyY_temp, new_value, munsell_spec)
        except Exception as e:
            pass
        i = i + 1

    raise RuntimeError(f'Could not adjust Munsell value down for xyY {xyY}, last Y tested was {Y_temp:.03f}')

def r_hue_to_code(hue):
    if hue == 0:
        hue = 100

    idx, frac = divmod(hue, 10)
    idx = int(idx)
    if frac == 0:
        frac = 10
        idx = idx - 1
    return frac, float(INTERPOL_TO_CSCI_HUE_INDEX[idx % 10])

def mipr_hvc_to_munsell_specification(hvc):
    if hvc[2] <= 0:
        return np.array([np.nan, hvc[1], np.nan, np.nan])
    hue, code = r_hue_to_code(hvc[0])
    return np.array([hue, hvc[1], hvc[2], code])

def mipr_sRGB_to_munsell_specification(r, g, b):
    '''r, g, b in [0, 255]'''
    out = subprocess.check_output(['/usr/bin/Rscript', 'to_munsell.R', 'sRGB', str(r), str(g), str(b)])
    try:
        res = json.loads(out)
        # res should be [[2., 3., 4.]]
    except:
        res = None
    if not isinstance(res, list) or len(res) == 0:
        raise Exception(f"to_munsell.R returned unexpected output '{out}'")
    return mipr_hvc_to_munsell_specification(res[0])

def mipr_xyY_to_munsell_specification(xyY):
    '''x, y, Y in [0, 1]'''
    x, y, Y = utilities.tsplit(xyY)
    out = subprocess.check_output(['/usr/bin/Rscript', 'to_munsell.R', 'xyY', str(x), str(y), str(Y * 100)])
    try:
        res = json.loads(out)
        # res should be [[2., 3., 4.]]
    except:
        res = None
    if not isinstance(res, list) or len(res) == 0:
        raise Exception(f"to_munsell.R returned unexpected output '{out}'")
    return mipr_hvc_to_munsell_specification(res[0])

def mipr_munsell_color_to_xyY(color, xyC='NBS'):
    out = subprocess.check_output(['/usr/bin/Rscript', 'munsell_to_xyy.R', color, xyC])
    try:
        res = json.loads(out)
        # res should be [[0.2, 0.3, 0.4]]
    except:
        res = None
    if not isinstance(res, list) or len(res) == 0:
        raise Exception(f"munsell_to_xyy.R returned unexpected output '{out}'")
    return np.array(res[0])

def mipr_munsell_color_to_rgb(color):
    out = subprocess.check_output(['/usr/bin/Rscript', 'munsell_to_rgb.R', color])
    try:
        res = json.loads(out)
        # res should be [[0.2, 0.3, 0.4]]
    except:
        res = None
    if not isinstance(res, list) or len(res) == 0:
        raise Exception(f"munsell_to_rgb.R returned unexpected output '{out}'")
    return np.array(res[0])

def csci_xyY_to_munsell_specification(xyY):
    xyY_adjusted, value = adjust_value_up(xyY)
    if value < 1:
        return np.array([np.nan, value, np.nan, np.nan])

    adjust_down = False
    try:
        munsell_spec = notation.munsell.xyY_to_munsell_specification(xyY_adjusted)
    except Exception as e:
        warnings.warn(str(e))
        adjust_down = True

    if adjust_down:
        xyY_adjusted, value, munsell_spec = adjust_value_down(xyY_adjusted, value)
    return munsell_spec

def munsell_specification_to_near_munsell_color(spec, hue_lcd=2.5, value_lcd=1, chroma_lcd=2):
    hue, value, chroma, code = utilities.tsplit(spec)
    value = round(value / value_lcd) * value_lcd

    # hue and chroma could be nan
    if notation.munsell.is_grey_munsell_colour(spec):
        return ('N', value, 0)

    chroma = round(chroma / chroma_lcd) * chroma_lcd
    if value == 10 or chroma == 0:
        return ('N', value, 0)

    code = int(code)
    assert code >= 1
    assert code <= 10
    hue = round(hue/hue_lcd) * hue_lcd
    if hue == 0:
        hue = 10
        code = code + 1
    hue_name = COLORSCI_HUE_NAMES[(code - 1) % 10]
    value = round(value / value_lcd) * value_lcd
    return (f'{hue}{hue_name}', value, chroma)