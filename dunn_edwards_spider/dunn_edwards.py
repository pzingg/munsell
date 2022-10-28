import csv
import os
import re
import sys
import time
from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager

from colour.notation import munsell as cnm
import munsellkit as mkit

color_id_ranges = [
  ('DEA', 2, 2),
  ('DEA', 100, 195),
  ('DE', 5000, 6399),
  ('DEHW', 1, 10),
  ('DEW', 300, 399),
  ('DET', 400, 699),
  ('DEC', 700, 799),
]

example_hero_footer = """
<div class="color-detail-hero-footer">
  <a href="https://www.dunnedwards.com/colors/browser/de6356/">
    <span>Sheet Metal | DE6356</span>
  </a>
  <a
    href="javascript:;"
    class="favorite-link favorite-modal"
    data-type="color"
    data-key="DE6356"
    aria-label="favorites"
  >
    <svg>
      <use
        xlink:href="https://www.dunnedwards.com/wp-content/themes/dunnedwards/dist/svg/sprite.svg#favorite"
        class="favorite-link-inactive"
      ></use>
      <use
        xlink:href="https://www.dunnedwards.com/wp-content/themes/dunnedwards/dist/svg/sprite.svg#favorite-active"
        class="favorite-link-active"
      ></use>
    </svg>
  </a>
  <a href="javascript:;" class="share share-btn" aria-label="share icon">
    <svg>
      <use
        xlink:href="https://www.dunnedwards.com/wp-content/themes/dunnedwards/dist/svg/sprite.svg#share"
      ></use>
    </svg>
  </a>
</div>
"""

example_info_box = """
<div class="content-info-box-inner">
  <div class="content-info-box-row">
    <p>Dunn-Edwards ID:</p>
    <p>DE6356 RL#590</p>
  </div>

  <div class="content-info-box-row">
    <p>Hex color code:</p>
    <p>
      5E6063
      <button
        class="info-toolip"
        data-toggle="tooltip"
        title="A hex color is expressed as a six-digit combination of numbers and letter defined by its mix of red, green and blue (RGB)."
      >
        <img
          src="https://www.dunnedwards.com/wp-content/themes/dunnedwards/assets/img/icons/icon.svg"
          alt=""
          role="presentation"
          width="100%"
          height="auto"
        />
      </button>
    </p>
  </div>

  <div class="content-info-box-row">
    <p>RGB color code:</p>
    <p>
      94, 96, 99
      <button
        class="info-toolip"
        data-toggle="tooltip"
        title="An RGB color is expressed by the red, green and blue three digit light values."
      >
        <img
          src="https://www.dunnedwards.com/wp-content/themes/dunnedwards/assets/img/icons/icon.svg"
          alt=""
          role="presentation"
          width="100%"
          height="auto"
        />
      </button>
    </p>
  </div>

  <div class="content-info-box-row">
    <p>CMYK color code:</p>
    <p>
      5, 3, 0, 61
      <button
        class="info-toolip"
        data-toggle="tooltip"
        title="A CMYK color is expressed as the cyan, magenta, yellow and black color values which mixed produce different colors."
      >
        <img
          src="https://www.dunnedwards.com/wp-content/themes/dunnedwards/assets/img/icons/icon.svg"
          alt=""
          role="presentation"
          width="100%"
          height="auto"
        />
      </button>
    </p>
  </div>

  <div class="content-info-box-row">
    <p>Munsell:</p>
    <p>
      HUE=3.53PB | VALUE=3.9 | CHROMA=0.6
      <button
        class="info-toolip"
        data-toggle="tooltip"
        title="A munsell color is expressed by the hue, chroma and value dimension values."
      >
        <img
          src="https://www.dunnedwards.com/wp-content/themes/dunnedwards/assets/img/icons/icon.svg"
          alt=""
          role="presentation"
          width="100%"
          height="auto"
        />
      </button>
    </p>
  </div>

  <div class="content-info-box-row">
    <p>Light Reflectance Value:</p>
    <p>
      LRV 11
      <button
        class="info-toolip"
        data-toggle="tooltip"
        title="A light reflectance value color is expressed as the percentage value of light a paint color reflects."
      >
        <img
          src="https://www.dunnedwards.com/wp-content/themes/dunnedwards/assets/img/icons/icon.svg"
          alt=""
          role="presentation"
          width="100%"
          height="auto"
        />
      </button>
    </p>
  </div>

  <div class="content-info-box-links">
    <ul>
      <li>
        <a
          href="https://www.dunnedwards.com/colors/collections/perfect-palette/"
          class="outline-button"
          aria-label="Perfect Palette®"
          >Perfect Palette®</a
        >
      </li>
      <li>
        <a
          href="https://www.dunnedwards.com/colors/collections/perfect-palette/cool-neutrals/#cool-neutrals"
          class="outline-button"
          aria-label="Cool Neutrals"
          >Cool Neutrals</a
        >
      </li>
    </ul>
  </div>
</div>
"""


COLUMNS = [
    'Brand Name',
    'Color Name',
    'Identifier',
    'Munsell Specification',
    'Total Hue',
    'Hue Prefix',
    'Hue Letter(s)',
    'ASTM Hue',
    'Value',
    'Chroma'
]


def setup_driver():
    options = Options()
    options.headless = True

    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)

    return driver


def crawl(driver, filename):
    with open(filename, 'at') as f:
        csv_writer = csv.writer(f)
        csv_writer.writerow(COLUMNS)

        for prefix, first, last in color_id_ranges:
          precision = 6 - len(prefix)
          fmt = f'0{precision}'
          for n in range(first, last+1):
            num_part = format(n, fmt)
            identifier = prefix + num_part
            scrape_detail(identifier, driver, csv_writer)
            time.sleep(0.2)

def scrape_detail(identifier, driver, csv_writer):
    url = f'https://www.dunnedwards.com/colors/browser/{identifier}'
    driver.get(url)

    print(f'Reading {url}')
    driver.implicitly_wait(1) # seconds

    try:
      is_404 = driver.find_element('xpath', "//*[@class='error404']")
      if is_404:
        print(f'Color page for {identifier} not found')
        return
    except:
      pass

    footer_span = driver.find_element('xpath', "//div[@class='color-detail-hero-footer']/a/span")
    if footer_span:
      span_text = footer_span.text
      m = re.match(r'(.+)\s?[|]', span_text)
      if m:
        color_name = escape_text(m.group(1))
      else:
        raise RuntimeError(f"No match in color hero '{span_text}'")
    else:
      raise RuntimeError('No color-hero-detail-footer span found')

    raw_hue = None
    raw_value = None
    raw_chroma = None
    info_box_rows = driver.find_elements('xpath', "//div[@class='content-info-box-row']")
    for row in info_box_rows:
      cols = row.find_elements('xpath', './p')
      if len(cols) >= 2:
        label_text = cols[0].text.upper()
        spec_text = cols[1].text.upper()
        print(f'{label_text} {spec_text}')
        if label_text.startswith('MUNSELL'):
          matches = re.findall(r'(HUE|VALUE|CHROMA)=([.0-9A-Z]+)', spec_text)
          if matches:
            for key, value in matches:
              if key == 'HUE':
                raw_hue = value
                if len(raw_hue) > 0 and raw_hue[0] == '.':
                    raw_hue = '0' + raw_hue
              elif key == 'VALUE':
                raw_value = value
              elif key == 'CHROMA':
                raw_chroma = value
            break
          else:
              raise RuntimeError(f"No match in munsell dimension '{spec_text}'")

    if raw_hue is None or raw_value is None or raw_chroma is None:
      raise RuntimeError('failed to find Munsell p')

    notation = f'{raw_hue} {raw_value}/{raw_chroma}'
    spec = cnm.munsell_colour_to_munsell_specification(notation)
    hue_shade, value, chroma, hue_index = spec
    hue = mkit.hue_data(hue_index, hue_shade=hue_shade, decimals=2)
    row = [
        'Dunn-Edwards',
        color_name,
        identifier,
        notation,
        hue['total_hue'],
        hue_shade,
        hue['hue_name'],
        hue['astm_hue'],
        value,
        chroma
    ]
    print(','.join([str(v) for v in row]))
    csv_writer.writerow(row)

def escape_text(text):
    return text.strip().replace('&#039;', '\'')


if __name__ == '__main__':
    driver = setup_driver()
    crawl(driver, 'dunn_edwards.csv')
