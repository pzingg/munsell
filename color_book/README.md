# color_book

![Example card output](hues_rit_008_7.5YR_10_16.png)

Python3 scripts to create printable .png files for Munsell color ranges.
These are hopefully useful for student artists who are learning about color matching.

Data from UEF Univeristy of Eastern Finland: http://cs.joensuu.fi/~spectral/databases/programs.htm

And from RIT Rochester Institute of Technology: https://www.rit.edu/cos/colorscience/rc_munsell_renotation.php


## Requirements

`numpy` library to read the Matlab data.

`Pillow` library for creating .png files.


## Usage

To import and use the UEF data, you must convert from the original Matlab format
to CSV files by running `python3 read_mat.py`

Then make `png` pages of Munsell book by running `python3 color_book.py [args]`

You can select the output from 8 1/2 x 11 inch book pages with the `--book` argument.

Or print out a 4 x 6 inch card showing the chroma ranges for a given hue and value
with the `--card` argument.

Or print out a 4 x 6 inch card showing the hues that neighbor a specified
Munsell color with the `--hues` argument.


## Additional References

More info on coverting to sRGB here: http://pteromys.melonisland.net/munsell
