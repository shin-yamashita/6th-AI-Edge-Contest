#!/usr/bin/env python3
# -*- coding : utf-8 -*-
#

import time
import re
#import sys
#print(sys.path)
from pynq import Overlay
from pynq import PL
from pynq import MMIO

fpgadir = 'fpga-data/'
firm = 'rvmon.mot'
#dump = True
dump = False

print('** Load "design_1.bit" to Overlay')
OL = Overlay(fpgadir + 'design_1.bit', download=True)
#if not OL.is_loaded():
#  OL.download()

# get clock frequency from hardware configuration file
print("PL clock frequency")
freq = {}
clkname = {'s00_axi_aclk':'rv32core', 'M00_AXI_ACLK':'tfacc'}
with open(fpgadir + 'design_1.hwh', 'r') as f:
  for line in f:
    if 'CLKFREQUENCY=' in line:
      for clk, block in clkname.items():
        if clk in line:
          freq[block] = int(re.search(r'CLKFREQUENCY="\d+', line).group()[14:])
          print("  %-8s : %5.1f MHz" % (block, freq[block] / 1e6))

#for k in PL.ip_dict.keys():
#  if k.startswith('tfacc'): print(k, PL.ip_dict[k])
#  if k.startswith('s00'): print(k, PL.ip_dict[k])

#adr_base = PL.ip_dict["tfacc_cpu_v1_0_0/s00_axi"]['phys_addr']
#adr_range = PL.ip_dict["tfacc_cpu_v1_0_0/s00_axi"]['addr_range']
adr_base = PL.ip_dict["tfacc_cpu_v1_0_0"]['phys_addr']
adr_range = PL.ip_dict["tfacc_cpu_v1_0_0"]['addr_range']

print("base:%x range:%x"%(adr_base, adr_range))
#mmio = MMIO(adr_base, adr_range)
#for a in range(6):
#  mmio.write(a*4, a+1)
#for a in range(6):
#  print("adr:%x %x"%(a*4, mmio.read(a*4)))

print('*** Load "%s" to processor memory'%(firm))
import numpy as np

reset_reg = 0x80
freq_reg  = 0xf0

mmio = MMIO(adr_base, adr_range)

mmio.write(reset_reg, 0)	# reset cpu

#sfile = "fpga-data/rvmon.mot"
sfile = fpgadir + firm

buf = np.zeros(32768, dtype=int)

with open(sfile, 'r') as f:
  recs = f.readlines()

ladr = 0

for rec in recs:
  rec = rec.strip()
  sr = rec[0:2]
  if sr == 'S3' :
    nb = int(rec[2:4], 16) - 5
    addr = int(rec[5:12], 16)
#    print("nb:%d addr:%x"%(nb,addr))
    for i in range(nb):
      buf[addr+i] = int(rec[12+i*2:12+i*2+2], 16)
#      print("%02x"%int(rec[i:i+2], 16))
      ladr = max(ladr, addr+i)

for i in range(0,ladr+4,4):
#  if i % 16 == 0: print("\n%04x : "%i, end='')
#  wd = buf[i]<<24 | buf[i+1]<<16 | buf[i+2]<<8 | buf[i+3] # Big endian
  wd = buf[i+3]<<24 | buf[i+2]<<16 | buf[i+1]<<8 | buf[i+0] # Little endian
#  print("%08x "%wd, end='')
  mmio.write(i, int(wd))

if dump:
  for i in range(0,ladr+4,4):
    if i % 16 == 0: print("\n%04x : "%i, end='')
    rd = mmio.read(i)
    print("%08x "%rd, end='')
  print()


mmio.write(freq_reg, freq['rv32core'])	# clock freq(Hz) @ 0xf0

mmio.write(reset_reg, 1)	# release reset



