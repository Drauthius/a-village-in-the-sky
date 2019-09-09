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

--- Defines a generic interface for GUI bounding areas.
-- @classmod Bound
-- @author Albert Diserholt
-- @license GPLv3+

local class = require("lib.middleclass")

local Bound = class("Bound")

--- Whether debug information should be drawn.
Bound.static.debug = false

--- Determines whether the given point is within the bounding area.
-- @tparam number x The x-coordinate of the point.
-- @tparam number y The y-coordinate of the point.
-- @treturn bool Always returns `false`.
function Bound:isWithin(x, y)
	return false
end

--- Get the centre of the bounding area.
-- @treturn number Always returns zero.
-- @treturn number Always returns zero.
function Bound:getCentre()
	return 0, 0
end

--- Called when the bound should be drawn.
-- Probably only useful when drawing a debug area.
function Bound:draw()
end

return Bound
