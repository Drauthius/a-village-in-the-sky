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
