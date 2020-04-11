from scipy.io import loadmat
import numpy as np
import re
import yaml

# From http://cs.joensuu.fi/~spectral/databases/programs.htm
# Convert Matlab formats into csv files.

data = loadmat('munsell400_700_5.mat')

def parse_spectrum(s):
    # 10rpV40C12.NM5
    # 2_5bgV60C10.NM5
    s = s.strip()
    m = re.match(r'([_0-9]+)(.+)V([0-9]+)C([0-9]+)\.', s)
    if not m:
        raise 'No match for {}'.format(s)
    hue_num = float(m.group(1).replace('_', '.'))
    hue_name = m.group(2).upper()
    value = int(m.group(3))
    chroma = int(m.group(4))
    return ['{:.1f}{}'.format(hue_num, hue_name), str(value), str(chroma)]

def write_list(file_name, spectrum_list, header):
    with open(file_name, 'w') as f:
        f.write(header)
        f.write('\n')
        for s in spectrum_list:
            parts = parse_spectrum(s)
            f.write(','.join(parts))
            f.write('\n')

def print_shape(data, key):
    print('{}: shape {}'.format(key, data[key].shape))

s_colnames = [
    'h', 'v', 'c'
]

c_colnames = [
    'x', 'y', 'z', 'X', 'Y', 'Z',
    'R', 'G', 'B', 'L*', 'a*', 'b*',
    'u', 'v', 'u*', 'v*'
]

munsell_colnames = [
    '{}'.format(wavelength) for wavelength in range(400, 700+5, 5)
]

print_shape(data, 'C')
print_shape(data, 'S')
print_shape(data, 'munsell')
write_list('munsell400_700_5.s.csv', data['S'].tolist(), ','.join(s_colnames))
np.savetxt('munsell400_700_5.c.csv', np.transpose(data['C']), delimiter = ',', header = ','.join(c_colnames), comments = '')
np.savetxt('munsell400_700_5.munsell.csv', np.transpose(data['munsell']), delimiter = ',', header = ','.join(munsell_colnames), comments = '')
