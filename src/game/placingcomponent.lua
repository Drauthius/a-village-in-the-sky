local class = require "lib.middleclass"

local PlacingComponent = class("PlacingComponent")

function PlacingComponent:initialize(isTile, type)
	self.isTileType = isTile
	self:setType(type)
end

function PlacingComponent:setType(type)
	self.type = type
end

function PlacingComponent:getType()
	return self.type
end

function PlacingComponent:isTile()
	return self.isTileType
end

return PlacingComponent
