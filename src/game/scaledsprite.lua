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
