import csv
import os
import re
import sys
import time
from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.options import Options

from colour.notation import munsell as cnm
import munsellkit as mkit

example_color_family = """
<article class="page colors-browser">
  <div class="container">
    <section class="page-content makasi-page-content">
      <div class="tabber tabbed initialized">
        <div class="tabber-tab active">
          <section class="colors-group-outer">
            <span id="high-hide-whites-1" class="wcag-h3">
              High Hide Whites
              <small>10 Colors</small>
            </span>
            <div class="colors-group">
              <a class="colors-box" style="background-color: rgb(236, 235, 227)" href="/colors/browser/dehw01">
                <div class="colors-color-tooltip">
                  <div class="name">
                    <p>Almond Milk
                    <br>
                    <small>DEHW01</small></p>
                  </div>
                </div>
                <figure style="background-color: rgb(236, 235, 227)"></figure>
              </a>
            </div>
          </section>
        </div>
      </div>
    </section>
  </div>
</article>
"""

example_color_detail = """
<article class="page colors-color-details">
  <div class="container">
    <section class="page-content makasi-page-content">
      <section class="full-description">
        <div class="color-preview ">
          <img alt="Beaded Blue paint color DE5909 #494D8B" width="100%" height="100%" src="https://de-production.imgix.net/colors/browser/de5909.jpg?fit=fill&amp;bg=ffffff&amp;fm=jpeg&amp;auto=format&amp;lossless=1">
        </div>
        <section class="page-content-flat">
          <h2>Beaded Blue</h2>
          <section class="color-information">
            DE5909  RL#184 
            <br>
            <div class="color-collections">
              <a href="/colors/color-family#blue-violets-red-violets-purples">Blue Violets, Red Violets, Purples</a>, 
              <a href="/colors/curated-collections/perfect-palette-r#blue-violets-red-violets-purples-1">Perfect Palette<sup class="registered-trademark">®</sup></a>
            </div>
            <div>
              LRV 8&nbsp;
              <span class="sprites-code-A"></span>Alkali Sensitive&nbsp;
            </div>
            <div class="color-munsell">
              Munsell:
              <span class="munsell-dimension">&nbsp;HUE=8.23PB&nbsp;</span>
              <span class="munsell-dimension">&nbsp;VALUE=3.4&nbsp;</span>
              <span class="munsell-dimension">&nbsp;CHROMA=8.3&nbsp;</span>
            </div>
          </section>
        </section>
      </section>
    </section>
  </div>
</article>
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
    chrome_options = Options()
    chrome_options.headless = True
    driver = webdriver.Chrome(executable_path='./drivers/chromedriver', options=chrome_options)
    return driver


def crawl(driver, filename):
    with open(filename, 'at') as f:
        csv_writer = csv.writer(f)
        csv_writer.writerow(COLUMNS)
        driver.get('https://www.dunnedwards.com/colors/color-family')

        detail_urls = get_detail_urls(driver)

        for i, url in enumerate(detail_urls):
            scrape_detail(url, i, driver, csv_writer)
            time.sleep(0.2)


def get_detail_urls(driver):
    if os.path.exists('detail_urls.txt'):
        return [line.rstrip() for line in open('detail_urls.txt', 'rt').readlines()]
    else:
        links = driver.find_elements_by_xpath("//div[contains(@class, 'colors-group')]//a[contains(@class, 'colors-box')]")
        print(f'got {len(links)} links')
        detail_urls = [link.get_attribute('href') for link in links]
        with open('detail_urls.txt', 'wt') as t:
            for url in detail_urls:
                t.write(url)
                t.write('\n')
        return detail_urls


def scrape_detail(url, i, driver, csv_writer):
    driver.get(url)
    print(f'reading {url}')
    driver.implicitly_wait(20) # seconds

    color_h2 = driver.find_element_by_xpath("//section[contains(@class, 'page-content-flat')]/h2")
    color_name = escape_text(color_h2.text)

    color_preview = driver.find_element_by_xpath("//div[contains(@class, 'color-preview')]")
    style = color_preview.get_attribute('style')
    m = re.search(r'background-color\:\s*rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)', style)
    if m:
        r = int(m.group(1))
        g = int(m.group(2))
        b = int(m.group(3))
    else:
        # print('no background-color found')
        color_img = color_preview.find_element_by_xpath('./img')
        alt = color_img.get_attribute('alt')
        m = re.search(r'#([0-9A-F]{2})([0-9A-F]{2})([0-9A-F]{2})', alt)
        if m:
            r = int(m.group(1), 16)
            g = int(m.group(2), 16)
            b = int(m.group(3), 16)
        else:
            raise RuntimeError(f"No match in color preview '{alt}'")

    info_div = driver.find_element_by_xpath("//section[contains(@class, 'color-information')]")
    info_text = get_content_of_first_text_child(driver, info_div)
    m = re.search(r'^\s*([^ ]+)', info_text)
    if m:
        identifier = m.group(1)
    else:
        raise RuntimeError(f"Not enough info in color information '{info_text}'")

    munsell_dims = driver.find_elements_by_xpath("//span[contains(@class, 'munsell-dimension')]")
    for span in munsell_dims:
        m = re.search(r'(HUE|VALUE|CHROMA)=([.0-9A-Z]+)', span.text)
        if m:
            key = m.group(1)
            if key == 'HUE':
                raw_hue = m.group(2)
                if len(raw_hue) > 0 and raw_hue[0] == '.':
                    raw_hue = '0' + raw_hue
            elif key == 'VALUE':
                raw_value = m.group(2)
            elif key == 'CHROMA':
                raw_chroma = m.group(2)
        else:
            raise RuntimeError(f"No match in munsell dimension '{span.txt}'")

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


def get_content_of_first_text_child(driver, element):
    return driver.execute_script("""
var parent = arguments[0];
var child = parent.firstChild;
while (child) {
    if (child.nodeType === Node.TEXT_NODE)
        return child.textContent;
}
return "";
""", element) 


def escape_text(text):
    return text.strip().replace('&#039;', '\'')


if __name__ == '__main__':
    driver = setup_driver()
    crawl(driver, 'dunn_edwards.csv')
