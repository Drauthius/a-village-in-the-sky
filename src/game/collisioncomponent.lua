local class = require "lib.middleclass"

local CollisionComponent = class("CollisionComponent")

function CollisionComponent.static:save(cassette)
	return {
		sprite = cassette:saveSprite(self.sprite)
	}
end

function CollisionComponent.static.load(cassette, data)
	return CollisionComponent(cassette:loadSprite(data.sprite))
end

function CollisionComponent:initialize(sprite)
	self:setCollisionSprite(sprite)
end

function CollisionComponent:setCollisionSprite(sprite)
	self.sprite = sprite
end

function CollisionComponent:getCollisionSprite()
	return self.sprite
end

return CollisionComponent
