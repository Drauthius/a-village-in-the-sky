--- Defines a simple text widget.
-- @classmod TextWidget
-- @author Albert Diserholt

local prefix = ... and (...):match("(.-%.?)[^%.]+$") or ""
local BoundingBox = require(prefix .. "boundingbox")
local Widget = require(prefix .. "widget")

local TextWidget = Widget:subclass("TextWidget")

--- Create a new text widget.
-- @tparam Bound bound The bounding area of the widget.
-- @tparam string text The text to display.
-- @tparam Font font The font to use for the text.
-- @tparam[opt] number width The number of pixels before wrapping the text.
-- @tparam[opt=left] string alignment The alignment of the text.
function TextWidget:initialize(bound, text, font, width, alignment)
	Widget.initialize(self, bound)

	self._text = text
	self._font = font
	self._width = width
	self._align = alignment

	local x, y = self:getBound():getCentre()
	local w, h = font:getWidth(text), font:getHeight()

	if width then
		while w > width do
			w = w - width
			h = h + font:getHeight()
		end
	end

	self._x = x - w / 2
	self._y = y - h / 2
end

--- Helper function to create a text widget with a bounding box.
-- @tparam x The x-coordinate to start the bounding box.
-- @tparam y The y-coordinate to start the bounding box.
-- @tparam[opt=0] ox The number of pixels to add or subtract from the bounding box
-- width.
-- @tparam[opt=0] oy The number of pixels to add or subtract from the bounding box
-- height.
-- @tparam[noopt] string text The text to display.
-- @tparam[noopt] Font font The font to use for the text.
-- @tparam[opt] number width The number of pixels before wrapping the text.
-- @tparam[opt=left] string alignment The alignment of the text.
function TextWidget:newWithBoundingBox(x, y, ox, oy, text, font, width, alignment)
	local x, y = x - ox, y - oy
	local w, h = font:getWidth(text), font:getHeight() + oy

	if width then
		while w > width do
			w = w - width
			h = h + font:getHeight()
		end
	end
	w = w + ox

	return self:new(BoundingBox:new(x, y, w, h), text, font, width, alignment)
end

function TextWidget:draw()
	Widget.draw(self)

	love.graphics.setFont(self._font)
	if self._width then
		love.graphics.printf(self._text, self._x, self._y, self._width, self._alignment)
	else
		love.graphics.print(self._text, self._x, self._y)
	end
end

return TextWidget
