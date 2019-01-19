local class = require "lib.middleclass"

local PositionComponent = class("PositionComponent")

function PositionComponent:initialize(grid)
	self:setPosition(grid)
end

function PositionComponent:getPosition()
	return self.grid
end

function PositionComponent:setPosition(grid)
	self.grid = grid
end

return PositionComponent
