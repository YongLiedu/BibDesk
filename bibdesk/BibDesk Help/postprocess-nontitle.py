#!/usr/bin/python

import sys

fnames = sys.argv[1:]

for fname in fnames:

    f = open(fname)
    lines = f.readlines()

    teximetaline = 0
    metaline = 0
    encodingline = 0

    for line in lines:
        if line[:34] == "<meta name=\"description\" content=\"":
            teximetaline = lines.index(line)
        if line[:24] == "<META NAME=\"DESCRIPTION\"":
            metaline = lines.index(line)
        if line[:31] == "<meta http-equiv=\"Content-Type\"":
            encodingline = lines.index(line)

    f.close()
    f = open(fname, 'w')

    if teximetaline > 0 and metaline > 0:
        lines[teximetaline] = lines[metaline]
        lines[metaline] = ""
    if encodingline > 0:
        lines[encodingline] = "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">\n"

    f.seek(0)
    for line in lines:
        f.write(line)
    f.close()
