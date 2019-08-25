local class = require "lib.middleclass"

local PositionComponent = class("PositionComponent")

function PositionComponent.static:save(cassette)
	return {
		fromGrid = cassette:saveGrid(self.fromGrid),
		toGrid = self.toGrid and cassette:saveGrid(self.toGrid) or nil,
		ti = self.ti,
		tj = self.tj
	}
end

function PositionComponent.static.load(cassette, data)
	return PositionComponent(
		cassette:loadGrid(data.fromGrid),
		data.toGrid and cassette:loadGrid(data.toGrid),
		data.ti, data.tj)
end

function PositionComponent:initialize(fromGrid, toGrid, ti, tj)
	self:setGrid(fromGrid, toGrid)
	self:setTile(ti, tj)
end

function PositionComponent:getFromGrid()
	return self.fromGrid
end

function PositionComponent:getToGrid()
	return self.toGrid
end

function PositionComponent:getGrid()
	return self:getToGrid()
end

function PositionComponent:setGrid(fromGrid, toGrid)
	self.fromGrid, self.toGrid = fromGrid, toGrid or fromGrid
end

function PositionComponent:getTile()
	return self.ti, self.tj
end

function PositionComponent:setTile(ti, tj)
	self.ti, self.tj = ti, tj
end

return PositionComponent
