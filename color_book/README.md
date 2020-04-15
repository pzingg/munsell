# color_book

Data from Univeristy of Eastern Finland: http://cs.joensuu.fi/~spectral/databases/programs.htm

And from RIT: https://www.rit.edu/cos/colorscience/rc_munsell_renotation.php

To use the UEF data, you must convert from Matlab format to CSV files by running `python3 read_mat.py`

Then make `png` pages of Munsell book by running `python3 color_book.py [args]`

You can select the output from 8 1/2 x 11 inch book pages with the `--book` argument.

Or print out a 4 x 6 inch card showing the chroma ranges for a given hue and value
with the `--card` argument.

Or print out a 4 x 6 inch card showing the hues that neighbor a specified
Munsell color with the `--hues` argument.

Requirements: `numpy` and `Pillow` libraries.

More info on coverting to sRGB here: http://pteromys.melonisland.net/munsell
