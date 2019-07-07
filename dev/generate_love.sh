#!/bin/sh

exec zip -x "dev/*" -x ".git/*" -r -9 ../love-android-sdl2/app/src/main/assets/game.love .
