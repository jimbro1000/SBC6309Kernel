#!/bin/bash
docker run asm6809:1.0 --env SRC=$1 -v .:/src
