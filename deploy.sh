#!/bin/sh -x

set -e

nicolino -B
rsync -rav output/* ralsina@pinky:/data/websites/nicolino.ralsina.me/
