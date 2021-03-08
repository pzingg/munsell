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

hues = [
    '2.5R',
    '5.0R',
    '7.5R',
    '10.0R',
    '2.5YR',
    '5.0YR',
    '7.5YR',
    '10.0YR',
    '2.5Y',
    '5.0Y',
    '7.5Y',
    '10.0Y',
    '2.5GY',
    '5.0GY',
    '7.5GY',
    '10.0GY',
    '2.5G',
    '5.0G',
    '7.5G',
    '10.0G',
    '2.5BG',
    '5.0BG',
    '7.5BG',
    '10.0BG',
    '2.5B',
    '5.0B',
    '7.5B',
    '10.0B',
    '2.5PB',
    '5.0PB',
    '7.5PB',
    '10.0PB',
    '2.5P',
    '5.0P',
    '7.5P',
    '10.0P',
    '2.5RP',
    '5.0RP',
    '7.5RP',
    '10.0RP'
]

example_swatch = """
<td data-id="112" class="N962189775837e69d2ae huePageSwatch">
  <span class="is-hidden-touch">5.0R </span>
  8/2
  <div>
    <a class="button is-primary is-rounded">1</a>
  </div>
</td>
"""

example_modal = """
<div class="modal-card">
  <header class="modal-card-head">
    <p class="modal-card-title">
      <span class="tag is-primary is-medium Naf19f1a1b455a904f8a" style="vertical-align: middle;"></span>
       5.0R 5/14
    </p> 
    <button aria-label="close" class="delete"></button>
  </header>
  <section class="modal-card-body">
    <table class="table is-striped is-narrow is-size-7 is-fullwidth">
      <thead>
        <tr>
          <th>Brand</th>
          <th>Color</th>
          <th>Pigments</th>
          <th>Notation Method</th>
          <th>Notation</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>Gamblin Artist's Oil Colors</td> 
          <td class="has-text-weight-semibold">Cadmium Red Medium</td> 
         <td>[PR108]</td> 
         <td class="is-italic">Spectrophotometer</td> 
         <td class="has-text-weight-semibold">5.0R 5/14</td>
        </tr>
        <tr>
          <td>Williamsburg Handmade Oil Paints</td> 
          <td class="has-text-weight-semibold">Persian Rose</td> 
         <td>[PY154] [PR112] [PV19] [PW6] [PW4]</td> 
         <td class="is-italic">Spectrophotometer</td> 
         <td class="has-text-weight-semibold">3.9R 5.01/14.74</td>
        </tr>
      </tbody>
    </table>
  </section> 
  <footer class="modal-card-foot">
    <p class="content is-small is-italic">These paint(s) have been included here because they are nearest to the Munsell notation: 5.0R 5/14
    </p>
  </footer>
</div>
"""

def setup_driver():
    chrome_options = Options()  
    chrome_options.headless = True
    driver = webdriver.Chrome(executable_path='./drivers/chromedriver', options=chrome_options)
    return driver


COLUMNS = [
    'Brand Name',
    'Identifier',
    'Munsell Specification',
    'Total Hue',
    'Hue Prefix',
    'Hue Letter(s)',
    'ASTM Hue',
    'Value',
    'Chroma',
    'Pigments'
]

def crawl(driver, filename):
    with open(filename, 'a') as f:
        csv_writer = csv.writer(f)
        csv_writer.writerow(COLUMNS)
        for i, hue in enumerate(hues):
            url = 'http://colorwell.org/munsell/{}'.format(hue)
            scrape_url(url, i, hue, driver, csv_writer)


def scrape_url(url, i, hue, driver, csv_writer):
    print('getting {}'.format(url))
    driver.get(url)
    links = driver.find_elements_by_xpath("//td[contains(@class, 'huePageSwatch')]//a")
    if len(links) == 0:
        print(hue, 'has no associated colors')
        # csv_writer.writerow([i, hue, 'None', 'None', 'None', 'None'])
    else:
      # print('got links {}'.format(links))
      for link in links:
          if link.is_displayed():
              scrape_link(link, i, driver, csv_writer)
            

def scrape_link(link, i, driver, csv_writer):  
    link.click()
    time.sleep(0.5)
    # print('clicked link')
    card = driver.find_element_by_xpath("//div[contains(@class, 'modal-card')]")
    if card.is_displayed():
        # print('got card {}'.format(card))
        dismiss = card.find_element_by_xpath("//button[@aria-label='close']")
        # print('got dismiss {}'.format(dismiss))
        if dismiss:
            closest = card.find_element_by_xpath("//p[contains(@class, 'modal-card-title')]").text
            # print('got closest {}'.format(closest))
            tbody = card.find_element_by_tag_name('tbody')
            # print('got tbody {}'.format(tbody))
            for tr in tbody.find_elements_by_tag_name('tr'):
                cells = [escape_text(cell.text) for cell in tr.find_elements_by_tag_name('td')]
                # print('got cells {}'.format(cells))
                brand = cells[0]
                identifier = cells[1]
                pigments = cells[2]
                # method = cells[3]
                notation = cells[4]
                spec = cnm.munsell_colour_to_munsell_specification(notation)
                cleaned_notation, spec, hue = mkit.normalized_color(spec)
                hue_shade, value, chroma, hue_index = spec
                row = [
                    brand,
                    identifier,
                    cleaned_notation,
                    hue['total_hue'],
                    hue_shade,
                    hue['hue_name'],
                    hue['astm_hue'],
                    value,
                    chroma,
                    pigments
                ]
                print(','.join([str(v) for v in row]))
                csv_writer.writerow(row)
            dismiss.click()
            time.sleep(0.5)


def escape_text(text):
    return text.strip().replace('&#039;', '\'')


if __name__ == '__main__':
    driver = setup_driver()
    crawl(driver, 'colorwell.csv')
