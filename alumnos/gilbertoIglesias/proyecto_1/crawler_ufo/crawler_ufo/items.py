# -*- coding: utf-8 -*-

# Define here the models for your scraped items
#
# See documentation in:
# http://doc.scrapy.org/en/latest/topics/items.html

import scrapy

class CrawlerUfoItem(scrapy.Item):
	report_text = scrapy.Field()
	report_href = scrapy.Field()
	count = scrapy.Field()
	pass

class Crawler_2Item(scrapy.Item):
	date_text = scrapy.Field()
	date_href = scrapy.Field()
	city = scrapy.Field()
	state = scrapy.Field()
	shape = scrapy.Field()
	duration = scrapy.Field()
	summary = scrapy.Field()
	posted = scrapy.Field()
	detalle1 = scrapy.Field()
	detalle2 = scrapy.Field()
	pass

class Crawler_3Item(scrapy.Item):
	campo_1 = scrapy.Field()
	campo_2 = scrapy.Field()
	pass
