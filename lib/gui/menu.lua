--[[
Copyright (C) 2019  Albert Diserholt (@Drauthius)

This file is part of A Village in the Sky.

A Village in the Sky is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

A Village in the Sky is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with A Village in the Sky. If not, see <http://www.gnu.org/licenses/>.
--]]

-- Defines a simple menu compromised of multiple widgets.
--  @classmod Menu
--  @author Albert Diserholt
--  @license GPLv3+

local prefix = ... and (...):match("(.-%.?)[^%.]+$") or ""
--local BoundingBox = require(prefix .. "boundingbox")
local Widget = require(prefix .. "widget")

local Menu = Widget:subclass("Menu")

return Menu
