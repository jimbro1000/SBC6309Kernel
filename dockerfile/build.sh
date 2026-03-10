#!/bin/bash
cd /src
asm6809.exe -B -3 -l $1.list -o $1.bin $1.asm 
