#!/bin/sh

exec zip -x "dev/*" -x ".git/*" -r -9 ${1:-../avits.love} .
