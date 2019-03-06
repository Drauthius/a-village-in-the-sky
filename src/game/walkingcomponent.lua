local class = require "lib.middleclass"

local WalkingComponent = class("WalkingComponent")

WalkingComponent.static.INSTRUCTIONS = {
	NONE = 0,
	DROPOFF = 1,
	WORK = 2,
	BUILD = 3,
	PRODUCE = 4,
	WANDER = 5,
	GET_FOOD = 6,
	GO_HOME = 7,
	GET_OUT_THE_WAY = 8
}

function WalkingComponent:initialize(ti, tj, grids, instructions)
	self:setPath(nil)
	self:setNextGrid(nil)
	self:setTargetTile(ti, tj)
	self:setTargetGrids(grids)
	self:setInstructions(instructions)
	self:setNextStop(nil)
end

function WalkingComponent:getPath()
	return self.path
end

function WalkingComponent:setPath(path)
	self.path = path
end

function WalkingComponent:getNextGrid()
	return self.nextGrid
end

function WalkingComponent:setNextGrid(grid)
	self.nextGrid = grid
end

function WalkingComponent:getTargetTile()
	return self.ti, self.tj
end

function WalkingComponent:setTargetTile(ti, tj)
	self.ti, self.tj = ti, tj
end

function WalkingComponent:getTargetGrids()
	return self.grids
end

function WalkingComponent:setTargetGrids(grids)
	self.grids = grids
end

function WalkingComponent:getTargetEntity()
	return self.targetEntity
end

function WalkingComponent:setTargetEntity(entity)
	self.targetEntity = entity
end

function WalkingComponent:getTargetRotation()
	return self.rotation
end

function WalkingComponent:setTargetRotation(rotation)
	self.rotation = rotation
end

function WalkingComponent:getInstructions()
	return self.instructions
end

function WalkingComponent:setInstructions(instructions)
	self.instructions = instructions
end

function WalkingComponent:getNextStop()
	return self.nextStop
end

function WalkingComponent:setNextStop(nextStop)
	self.nextStop = nextStop
end

return WalkingComponent
