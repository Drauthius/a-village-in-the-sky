local class = require "lib.middleclass"

local Sprite = class("Sprite")

function Sprite:initialize(spritesheet, quad, data)
	self.spritesheet = spritesheet
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
	local unpack = _G["unpack"] or table.unpack

	if self.trimmed then
		return unpack(self.trimmed)
	end

	local topx, topy = math.huge, math.huge
	local bottomx, bottomy = -math.huge, -math.huge

	-- Increase by one to avoid not calculate the outline
	local ox, oy = 1, 1

	for x=0,self.w - 1 do
		for y=0,self.h - 1 do
			local _, _, _, a = self:getPixel(x, y)
			if a >= 1 then
				if x < topx then
					topx = x + ox
				end
				if x > bottomx then
					bottomx = x -- - ox -- Already added, somehow
				end

				if y < topy then
					topy = y + oy
				end
				if y > bottomy then
					bottomy = y -- - oy -- Already added, somehow
				end
			end
		end
	end

	assert(topx < bottomx, "No width")
	assert(topy < bottomy, "No height")

	self.trimmed = { topx, topy, bottomx - topx, bottomy - topy }
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
	return self.w
end

function Sprite:getHeight()
	return self.h
end

return Sprite
