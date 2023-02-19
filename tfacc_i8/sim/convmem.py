#!/usr/bin/env python3

import sys

f1 = open("prog.mem",   "w")
fu = open("prog_u.mem", "w")
fl = open("prog_l.mem", "w")

with open(sys.argv[1], 'r') as f:
  for line in f:
    f1.write(line)
    col = line.split()
#    print(col)
    lu = ""
    ll = ""
    for c in col:
      lu += " "+c[0:4]
      ll += " "+c[4:8]

    fu.write(lu+"\n")
    fl.write(ll+"\n")

