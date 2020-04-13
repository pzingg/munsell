# uef_color_book

Data from Univeristy of Eastern Finland: http://cs.joensuu.fi/~spectral/databases/programs.htm

And from RIT: https://www.rit.edu/cos/colorscience/rc_munsell_renotation.php

To use the UEF data, you must convert from Matlab format to CSV files by running `python3 read_mat.py`

Then make `png` pages of Munsell book by running `python3 color_book.py`

Requirements: numpy and Pillow libraries.

More info on coverting to sRGB here: http://pteromys.melonisland.net/munsell

255 255 255
N9.5
243 243 243
N9
232 232 232
N8
203 203 203
N7
179 179 179
N6
150 150 150
N5
124 124 124
N4
97 97 97
N3
70 70 70
N2
48 48 48
N1
28 28 28
N0
0 0 0
