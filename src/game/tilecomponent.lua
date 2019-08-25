local class = require "lib.middleclass"

local TileComponent = class("TileComponent")

TileComponent.static.GRASS = 0
TileComponent.static.FOREST = 1
TileComponent.static.MOUNTAIN = 2

TileComponent.static.TILE_NAME = {
	[TileComponent.static.GRASS] = "grass",
	[TileComponent.static.FOREST] = "forest",
	[TileComponent.static.MOUNTAIN] = "mountain"
}

function TileComponent.static:save()
	return {
		type = self.type,
		ti = self.ti,
		tj = self.tj
	}
end

function TileComponent.static.load(_, data)
	return TileComponent(data.type, data.ti, data.tj)
end

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
