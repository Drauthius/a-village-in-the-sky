--- Defines an axis-aligned bounding box (AABB) for use by widgets.
-- @classmod BoundingBox
-- @alias AABB
-- @author Albert Diserholt

local prefix = ... and (...):match("(.-%.?)[^%.]+$") or ""

local Bound = require(prefix .. "bound")

local AABB = Bound:subclass("AxisAlignedBoundingBox")

--- Create a new axis-aligned bounding box.
-- @tparam number x The x-coordinate of the top-left corner.
-- @tparam number y The y-coordinate of the top-left corner.
-- @tparam number w The width of the bounding box.
-- @tparam number h The height of the bounding box.
function AABB:initialize(x, y, w, h)
	self._area = {
		x1 = x,
		y1 = y,
		x2 = x + w,
		y2 = y + h,
		w = w,
		h = h
	}
end

--- Determine whether the given point is within the bounding box.
-- @tparam number x The x-coordinate of the point.
-- @tparam number y The y-coordinate of the point.
-- @treturn bool Whether the point lies inside the bounding box.
function AABB:isWithin(x, y)
	return x >= self._area.x1 and x <= self._area.x2 and
	       y >= self._area.y1 and y <= self._area.y2
end

--- Get the centre of the bounding box.
-- @treturn number The x-coordinate of the centre.
-- @treturn number The y-coordinate of the centre.
function AABB:getCentre()
	return self._area.x1 + self._area.w / 2, self._area.y1 + self._area.h / 2
end

--- Draws a debug rectangle if the static flag `Bound.debug` is set.
function AABB:draw()
	if Bound.debug then
		love.graphics.setColor(0.8, 0.8, 1, 1)
		love.graphics.rectangle("line", self._area.x1, self._area.y1, self._area.w, self._area.h)
		love.graphics.setColor(1, 1, 1, 1)
	end
end

return AABB
