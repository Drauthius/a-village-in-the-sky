stds.love = require("love_standard")

std = "luajit+love"
ignore = { "212" } -- Unused arguments

files["spec/*_spec.lua"].std = 'luajit+busted'
