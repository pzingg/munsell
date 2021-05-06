# dunn_edwards_spider

The `dunn_edwards.py` script uses Selenium and chromedriver to pull color 
information from https://dunnedwards.com.

Munsell data is written to a CSV file.

Before running the script, make sure to download the appropriate
chromedriver binary for your version of Google Chrome and save it
to the `drivers` folder.

The `de_book.py` script reads the data from the CSV file and 
creates either text output or a series of PNG files that allows you
to build a sparsely-populated Munsell book with the closest 
Dunn-Edwards paint chips.

To create the PNG files, you need to have the appropriate TrueType
font files downloaded into the project directory.
