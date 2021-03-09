# artpaints_spider

Get the color information on Prismacolor Nupastel, Sennelier and Unison
soft pastel colors from the http://www.art-paints.com website.

Munsell information for the colors in each brand will be dumped into
jsonline (.jsonl) files.

Invoke with:

```
scrapy crawl nupastel -s FEED_URI='file:///home/pzingg/Projects/munsell/nupastel.jsonl' -s FEED_FORMAT=jsonlines
scrapy crawl sennelier -s FEED_URI='file:///home/pzingg/Projects/munsell/sennelier.jsonl' -s FEED_FORMAT=jsonlines
scrapy crawl unison -s FEED_URI='file:///home/pzingg/Projects/munsell/unison.jsonl' -s FEED_FORMAT=jsonlines
```
