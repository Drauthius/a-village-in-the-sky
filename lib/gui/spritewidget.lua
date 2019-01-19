local prefix = ... and (...):match("(.-%.?)[^%.]+$") or ""
local BoundingBox = require(prefix .. "boundingbox")
local Widget = require(prefix .. "widget")

local SpriteWidget = Widget:subclass("SpriteWidget")

function SpriteWidget:initialize(bound, image, quad)
	Widget.initialize(self, bound)

	self._image = image
	self._quad = quad

	local cx, cy = self:getBound():getCentre()
	local w, h, _
	if quad then
		_, _, w, h = quad:getViewport()
	else
		w, h = image:getDimensions()
	end

	self._x = cx - math.floor(w/2)
	self._y = cy - math.floor(h/2)
end

function SpriteWidget:newWithBoundingBox(cx, cy, ox, oy, image, quad)
	local w, h, _
	if quad then
		_, _, w, h = quad:getViewport()
	else
		w, h = image:getDimensions()
	end

	return self:new(BoundingBox:new(cx - math.floor(w/2) - ox, cy - math.floor(h/2) - oy, w + ox, h + oy), image, quad)
end

function SpriteWidget:draw()
	if self._quad then
		love.graphics.draw(self._image, self._quad, self._x, self._y)
	else
		love.graphics.draw(self._image, self._x, self._y)
	end

	Widget.draw(self)
end

return SpriteWidget
