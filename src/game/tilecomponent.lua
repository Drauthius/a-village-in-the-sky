local class = require "lib.middleclass"

local TileComponent = class("TileComponent")

TileComponent.static.GRASS = 0
TileComponent.static.FOREST = 1
TileComponent.static.MOUNTAIN = 2

function TileComponent:initialize(type, ti, tj)
	self:setType(type)
	self:setPosition(ti, tj)
end

function TileComponent:setType(type)
	self.type = type
end

function TileComponent:getType()
	return self.type
end

function TileComponent:getPosition()
	return self.ti, self.tj
end

function TileComponent:setPosition(ti, tj)
	self.ti, self.tj = ti, tj
end

return TileComponent
