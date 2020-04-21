# nupastel_spider

Get the color information on Prismacolor Nupastel, Sennelier and Unison soft pastel
colors from art-paints.com website.

Invoke with:

```
scrapy crawl nupastel -s FEED_URI='file:///home/pzingg/Projects/munsell/nupastel.json' -s FEED_FORMAT=jsonlines
scrapy crawl sennelier -s FEED_URI='file:///home/pzingg/Projects/munsell/sennelier.json' -s FEED_FORMAT=jsonlines
scrapy crawl unison -s FEED_URI='file:///home/pzingg/Projects/munsell/unison.json' -s FEED_FORMAT=jsonlines
```
