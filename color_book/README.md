# color_book

Data from Univeristy of Eastern Finland: http://cs.joensuu.fi/~spectral/databases/programs.htm

And from RIT: https://www.rit.edu/cos/colorscience/rc_munsell_renotation.php

To use the UEF data, you must convert from Matlab format to CSV files by running `python3 read_mat.py`

Then make `png` pages of Munsell book by running `python3 color_book.py`

Requirements: numpy and Pillow libraries.

More info on coverting to sRGB here: http://pteromys.melonisland.net/munsell
