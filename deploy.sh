#!/bin/sh -x

set -e

nicolino build -B
rsync -rav output/* ralsina@rocky:/home/ralsina/web/websites/nicolino.ralsina.me/
