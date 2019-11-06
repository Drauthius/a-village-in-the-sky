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

function Widget:draw(ox, oy)
	ox, oy = ox or 0, oy or 0
	if not self.sx then
		spriteSheet:draw(self.sprite, self.x + ox, self.y + oy)
	else
		love.graphics.draw(spriteSheet:getImage(), self.sprite:getQuad(), self.x + ox, self.y + oy, 0, self.sx, self.sy)
	end

	if self.text then
		love.graphics.setFont(self.text.font)
		love.graphics.setColor(self.text.color)
		if self.isDown then
			ox, oy = ox + 1, oy + 1
		end
		love.graphics.printf(babel.translate(self.text.text),
		                     self.x + self.text.ox + ox, self.y + self.text.oy + oy,
		                     self.text.limit, self.text.align, 0, self.sx, self.sy)
		love.graphics.setColor(1, 1, 1, 1)
	end
end

function Widget:addText(text, font, color, ox, oy, limit, align)
	self.text = {
		text = text,
		font = font,
		color = color,
		ox = (ox or 0) + (font:getDPIScale() == 1 and 0 or font:getDPIScale()),
		oy = (oy or 0) + (font:getDPIScale() == 1 and 0 or font:getDPIScale()),
		limit = limit or -1,
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
