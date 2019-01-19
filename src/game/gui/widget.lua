local class = require "lib.middleclass"

local spriteSheet = require "src.game.spritesheet"

local Widget = class("Widget")

function Widget:initialize(x, y, ox, oy, sprite, text)
	self.x, self.y = x, y
	self.ox, self.oy = ox, oy
	self.w, self.h = sprite:getDimensions()
	self.sprite = sprite
end

function Widget:draw()
	spriteSheet:draw(self.sprite, self.x, self.y)
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
