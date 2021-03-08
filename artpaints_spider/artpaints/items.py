# -*- coding: utf-8 -*-

# Define here the models for your scraped items
#
# See documentation in:
# https://doc.scrapy.org/en/latest/topics/items.html

import scrapy


class ArtPaintsItem(scrapy.Item):
    name = scrapy.Field()
    identifier = scrapy.Field()
    html = scrapy.Field()
    c = scrapy.Field()
    m = scrapy.Field()
    y = scrapy.Field()
    k = scrapy.Field()
    r = scrapy.Field()
    g = scrapy.Field()
    b = scrapy.Field()
