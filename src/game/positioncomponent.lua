local class = require "lib.middleclass"

local PositionComponent = class("PositionComponent")

function PositionComponent:initialize(grid, ti, tj)
	self:setGrid(grid)
	self:setTile(ti, tj)
end

function PositionComponent:getGrid()
	return self.grid
end

function PositionComponent:setGrid(grid)
	self.grid = grid
end

function PositionComponent:getTile()
	return self.ti, self.tj
end

function PositionComponent:setTile(ti, tj)
	self.ti, self.tj = ti, tj
end

return PositionComponent
