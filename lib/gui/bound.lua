--- Defines a generic interface for GUI bounding areas.
-- @classmod Bound
-- @author Albert Diserholt

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
