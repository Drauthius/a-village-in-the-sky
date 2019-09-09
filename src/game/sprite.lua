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

local class = require "lib.middleclass"

local Sprite = class("Sprite")

function Sprite:initialize(spritesheet, name, quad, data)
	self.spritesheet = spritesheet
	self.name = name

	if type(quad) == "table" then
		self.spriteBatch = love.graphics.newSpriteBatch(spritesheet:getImage(), #quad, "static")
		for _,v in ipairs(quad) do
			self.spriteBatch:add(v)
		end
		self.quad = quad[1]
	else
		self.quad = quad
	end
	self.data = data
	if self.quad then
		local _, _, w, h = self.quad:getViewport()
		self.w, self.h = w, h
	else
		self.w, self.h = 64, 64
	end
end

function Sprite:draw(image, x, y)
	if self.spriteBatch then
		love.graphics.draw(self.spriteBatch, x, y)
	elseif self.quad then
		love.graphics.draw(image, self.quad, x, y)
	else
		love.graphics.setColor(1, 0, 1)
		love.graphics.rectangle("fill", x, y, self.w, self.h)
		love.graphics.setColor(1, 1, 1)
	end
end

function Sprite:getName()
	return self.name
end

function Sprite:getQuad()
	return self.quad
end

function Sprite:getData()
	if self.data then
		return self.data
	end

	print("No data")
	return nil
end

function Sprite:getTrimmedDimensions()
	if self.trimmed then
		return unpack(self.trimmed)
	end

	local topx, topy = math.huge, math.huge
	local bottomx, bottomy = -math.huge, -math.huge

	-- Can be increase by one to avoid including the outline, but why would you?
	local ox, oy = 0, 0

	for x=0,self.w - 1 do
		for y=0,self.h - 1 do
			local _, _, _, a = self:getPixel(x, y)
			if a >= 1 then
				if x < topx then
					topx = x
				end
				if x > bottomx then
					bottomx = x
				end

				if y < topy then
					topy = y
				end
				if y > bottomy then
					bottomy = y
				end
			end
		end
	end

	assert(topx < bottomx, "No width")
	assert(topy < bottomy, "No height")

	self.trimmed = { topx + ox, topy + oy, bottomx - topx - ox * 2 + 1, bottomy - topy - oy * 2 + 1}
	return unpack(self.trimmed)
end

function Sprite:getPixel(px, py)
	if self.spritesheet and self.quad then
		local x, y = self.quad:getViewport()
		return self.spritesheet:getImageData():getPixel(x + px, y + py)
	end
end

function Sprite:getDimensions()
	return self.w, self.h
end

function Sprite:getWidth()
	return (select(1, self:getDimensions()))
end

function Sprite:getHeight()
	return (select(2, self:getDimensions()))
end

return Sprite
