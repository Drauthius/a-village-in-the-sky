-- Defines a simple menu compromised of multiple widgets.
--  @classmod Menu
--  @author Albert Diserholt

local prefix = ... and (...):match("(.-%.?)[^%.]+$") or ""
--local BoundingBox = require(prefix .. "boundingbox")
local Widget = require(prefix .. "widget")

local Menu = Widget:subclass("Menu")

return Menu
