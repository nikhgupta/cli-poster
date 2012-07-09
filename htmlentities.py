#!/usr/bin/env python3
# Functions to handle conversion between unicode and latin html characters.
from html.entities import codepoint2name, name2codepoint
from sys import argv, stdin, stdout
import re

__version__ = '0.2.1'

def encode(source):
    new_source = ''
    for char in source:
        if ord(char) in codepoint2name:
            char = '&%s;' % codepoint2name[ord(char)]
        new_source += char
    return new_source

def decode(source):
    for entity in re.findall('&(?:[a-z][a-z0-9]+);', source):
        entity = entity.replace('&', '')
        entity = entity.replace(';', '')
        source = source.replace('&%s;' % entity, chr(name2codepoint[entity]))
    return source

def main():
    Query = stdin.read()
    Result = encode(Query)
    stdout.write(Result)
    
if __name__ == "__main__":
    main()
