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
	spriteSheet:draw(self.sprite, self.x, self.y)

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

function Widget:getPosition()
	return self.x, self.y
end

function Widget:getDimensions()
	return self.w, self.h
end

function Widget:isWithin(x, y)
	return x >= self.x - self.ox and
	       y >= self.y - self.oy and
	       x <= self.x + self.w + self.ox and
	       y <= self.y + self.h + self.oy
end

return Widget
