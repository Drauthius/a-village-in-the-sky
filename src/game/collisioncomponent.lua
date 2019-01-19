local class = require "lib.middleclass"

local CollisionComponent = class("CollisionComponent")

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
