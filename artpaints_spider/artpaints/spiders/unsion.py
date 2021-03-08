# -*- coding: utf-8 -*-
import scrapy
from artpaints.items import ArtPaintsItem



def list_of_numbers(str):
    return [int(x.strip()) for x in str.split(',')]


class UnisonSpider(scrapy.Spider):
    name = 'unison'
    allowed_domains = ['art-paints.com']
    start_urls = [
        'http://www.art-paints.com/Paints/Pastel/Unison/Soft/Unison-Soft.html' ]
    other_urls = [
        'http://www.art-paints.com/Paints/Pastel/Unison/Starter-Set/Unison-Starter-Set.html',
        'http://www.art-paints.com/Paints/Pastel/Unison/Starter-36/Unison-Starter-36.html',
        'http://www.art-paints.com/Paints/Pastel/Unison/Starter-72/Unison-Starter-72.html',
        'http://www.art-paints.com/Paints/Pastel/Unison/Landscape/Unison-Landscape.html',
        'http://www.art-paints.com/Paints/Pastel/Unison/Landscape-18/Unison-Landscape-18.html',
        'http://www.art-paints.com/Paints/Pastel/Unison/Portrait/Unison-Portrait.html',
        'http://www.art-paints.com/Paints/Pastel/Unison/Portrait-18/Unison-Portrait-18.html' ]

    def parse(self, response):
        table = response.xpath('//center/table[5]')
        if table:
            for link in table.xpath('.//a[not(descendant::img)]'):
                name = " ".join(link.xpath('text()').getall()).strip()
                next_page = link.attrib['href']
                if name != '' and next_page != '':
                    yield scrapy.Request(
                        response.urljoin(next_page),
                        callback=self.parse_color,
                        flags=[ {'name': name} ]
                    )

    def parse_color(self, response):
        flags = response.request.flags
        strongs = response.xpath('//center/table[5]//table[1]//tr[2]/td[1]/table[1]//tr[1]/td[3]/table//tr[1]/td[1]/strong')
        texts = [strong.xpath('.//text()').get() for strong in strongs]
        cmyk = list_of_numbers(texts[3])
        rgb = list_of_numbers(texts[4])
        yield ArtPaintsItem(name=texts[0], identifier=texts[1],
            html=texts[2], c=cmyk[0], m=cmyk[1], y=cmyk[2], k=cmyk[3], r=rgb[0], g=rgb[1], b=rgb[2])
