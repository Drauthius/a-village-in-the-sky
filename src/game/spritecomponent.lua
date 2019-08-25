local class = require "lib.middleclass"

local SpriteComponent = class("SpriteComponent")

SpriteComponent.static.standardColor = { 1, 1, 1, 1 }

function SpriteComponent.static:save(cassette)
	return {
		sprite = self.sprite and cassette:saveSprite(self.sprite) or nil,
		x = self.x,
		y = self.y,
		color = self.color
	}
end

function SpriteComponent.static.load(cassette, data)
	return SpriteComponent(data.sprite and cassette:loadSprite(data.sprite) or nil, data.x, data.y, data.color)
end

function SpriteComponent:initialize(sprite, x, y, color)
	self:setSprite(sprite)
	self:setDrawPosition(x, y)
	self:resetColor()
	self:setNeedsRefresh(sprite == nil)
end

function SpriteComponent:getSprite()
	return self.sprite
end

function SpriteComponent:setSprite(sprite)
	self.sprite = sprite
end

-- Can be tweened/shooked.
function SpriteComponent:getDrawPosition()
	return self.x, self.y
end

function SpriteComponent:getOriginalDrawPosition()
	return self.origx, self.origy
end

function SpriteComponent:setDrawPosition(x, y)
	self.x, self.y = x, y
	self.origx, self.origy = x, y
end

function SpriteComponent:getDrawIndex()
	return self.index
end

function SpriteComponent:setDrawIndex(index)
	self.index = index
end

function SpriteComponent:getColor()
	return self.color
end

function SpriteComponent:setColor(r, g, b, a)
	self.color = { r, g, b, a }
end

function SpriteComponent:resetColor()
	self.color = SpriteComponent.standardColor
end

function SpriteComponent:needsRefresh()
	return self.refresh == true
end

function SpriteComponent:setNeedsRefresh(refresh)
	self.refresh = refresh
end

return SpriteComponent
