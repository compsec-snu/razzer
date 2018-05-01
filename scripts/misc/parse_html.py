#!/usr/bin/python

import HTMLParser
import sys


class TableParser(HTMLParser.HTMLParser):
    def __init__(self):
        HTMLParser.HTMLParser.__init__(self)
        self.in_td = False
        self.table = []
    def handle_starttag(self, tag, attrs):
        if tag == 'td':
            self.in_td = True
        elif tag == 'tr':
            self.line = []
    def handle_data(self, data):
        if self.in_td:
            self.line.append(data)
    def handle_endtag(self, tag):
        if tag == 'td':
            self.in_td = False
        if tag == 'tr' and len(self.line) != 0:
            self.table.append(self.line)
        if tag == 'table':
            for l in self.table:
                for i in l:
                    print i,
                print

with open(sys.argv[1]) as f:
    html = f.read()
    parser = TableParser()
    parser.feed(html)
