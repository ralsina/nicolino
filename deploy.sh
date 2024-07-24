#!/bin/sh -x

set -e

nicolino build -B
rsync -rav output/* ralsina@pinky:/data/websites/nicolino.ralsina.me/
