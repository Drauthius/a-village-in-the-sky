local babel = require "lib.babel"
local class = require "lib.middleclass"

local spriteSheet = require "src.game.spritesheet"

local Widget = class("Widget")

function Widget:initialize(x, y, ox, oy, sprite)
	self.x, self.y = x, y
	self.ox, self.oy = ox, oy
	self.w, self.h = sprite:getDimensions()
	self.sprite = sprite
end

function Widget:draw()
	if not self.sx then
		spriteSheet:draw(self.sprite, self.x, self.y)
	else
		love.graphics.draw(spriteSheet:getImage(), self.sprite:getQuad(), self.x, self.y, 0, self.sx, self.sy)
	end

	if self.text then
		love.graphics.setFont(self.text.font)
		love.graphics.setColor(self.text.color)
		love.graphics.printf(babel.translate(self.text.text),
		                     self.x + self.text.ox, self.y + self.text.oy,
		                     self.text.limit, self.text.align)
	end
end

function Widget:addText(text, font, color, ox, oy, limit, align)
	self.text = {
		text = text,
		font = font,
		color = color,
		ox = ox,
		oy = oy,
		limit = limit,
		align = align
	}
end

function Widget:setText(text)
	assert(self.text, "Text has to be added first.").text = text

end

function Widget:setScale(sx, sy)
	self.sx, self.sy = sx, sy
end

function Widget:getPosition()
	return self.x, self.y
end

function Widget:setPosition(x, y)
	self.x, self.y = x, y
end

function Widget:getWidth()
	return self.w
end

function Widget:getHeight()
	return self.h
end

function Widget:getDimensions()
	return self.w, self.h
end

function Widget:isWithin(x, y)
	local x1 = self.x + self.ox
	local y1 = self.y + self.oy
	local x2 = self.x + (self.w * (self.sx or 1)) - self.ox
	local y2 = self.y + (self.h * (self.sy or 1)) - self.oy

	return x >= math.min(x1, x2) and
	       y >= math.min(y1, y2) and
	       x <= math.max(x1, x2) and
	       y <= math.max(y1, y2)
end

return Widget
