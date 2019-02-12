local class = require "lib.middleclass"

local PositionComponent = class("PositionComponent")

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
