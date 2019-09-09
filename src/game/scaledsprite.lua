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

local Sprite = require "src.game.sprite"

local ScaledSprite = Sprite:subclass("ScaledSprite")

function ScaledSprite:initialize(spritesheet, quad, data, sx, sy)
	Sprite.initialize(self, spritesheet, quad, data)
	self:setScale(sx, sy)
end

function ScaledSprite:fromSprite(sprite, sx, sy)
	-- The sprite mustn't be modified, since it is cached.
	local newSprite = ScaledSprite:allocate()
	for k,v in pairs(sprite) do
		newSprite[k] = v
	end
	newSprite:setScale(sx, sy)
	return newSprite
end

function ScaledSprite:getScale()
	return self.sx, self.sy
end

function ScaledSprite:setScale(sx, sy)
	self.sx = sx or 1
	self.sy = sy or self.sx
end

function ScaledSprite:draw(image, x, y)
	if self.spriteBatch then
		love.graphics.draw(self.spriteBatch, x, y, 0, self.sx, self.sy)
	elseif self.quad then
		love.graphics.draw(image, self.quad, x, y, 0, self.sx, self.sy)
	else
		love.graphics.setColor(1, 0, 1)
		love.graphics.rectangle("fill", x, y, self.w * self.sx, self.h * self.sy)
		love.graphics.setColor(1, 1, 1)
	end
end

function ScaledSprite:getTrimmedDimensions()
	Sprite.getTrimmedDimensions(self)
	local x, y, w, h = unpack(self.trimmed)

	return x, y, w * self.sx, h * self.sy
end

function ScaledSprite:getDimensions()
	return self.w * self.sx, self.h * self.sy
end

return ScaledSprite
