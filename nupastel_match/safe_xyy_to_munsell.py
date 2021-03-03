import warnings
import numpy as np
import colour
from colour import notation, utilities, volume

MUNSELL_HUE_NAMES = [
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


def safe_xyY_to_munsell_specification(xyY):
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
    hue_name = MUNSELL_HUE_NAMES[(code - 1) % 10]
    value = round(value / value_lcd) * value_lcd
    return (f'{hue}{hue_name}', value, chroma)