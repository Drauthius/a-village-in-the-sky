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

function WalkingComponent.static:save(cassette)
	local data = {
		path = self.path and cassette:saveGridList(self.path),
		nextGrid = self.nextGrid and cassette:saveGrid(self.nextGrid),
		ti = self.ti,
		tj = self.tj,
		grids = self.targetGrids and cassette:saveGridList(self.grids),
		rotation = self.rotation,
		instructions = self.instructions,
		speedModifier = self.speedModifier
	}

	if self.targetEntity then -- XXX: A little bonkers.
		if self.targetEntity.gi then
			data.targetEntity = cassette:saveGrid(self.targetEntity)
		else
			data.targetEntity = cassette:saveEntity(self.targetEntity)
		end
	end

	if self.nextStop then -- XXX: A lot bonkers.
		if self.nextStop.gi then
			data.nextStop = cassette:saveGrid(self.nextStop)
		elseif type(self.nextStop[2]) == "number" then
			data.nextStop = {
				cassette:saveGrid(self.nextStop[1]),
				self.nextStop[2],
				self.nextStop[3] and cassette:saveEntity(self.nextStop[3]) or nil
			}
		else
			data.nextStop = cassette:saveGridList(self.nextStop)
		end
	end

	return data
end

function WalkingComponent.static.load(cassette, data)
	local component = WalkingComponent(
		data.ti, data.tj,
		data.grids and cassette:loadGridList(data.grids),
		data.instructions)

	component.path = data.path and cassette:loadGridList(data.path) or nil
	component.nextGrid = data.nextGrid and cassette:loadGrid(data.nextGrid) or nil
	component.rotation = data.rotation

	if data.targetEntity then -- XXX: A little bonkers.
		if data.targetEntity.gi then
			component.targetEntity = cassette:loadGrid(data.targetEntity)
		else
			component.targetEntity = cassette:loadEntity(data.targetEntity)
		end
	end

	if data.nextStop then -- XXX: A lot bonkers.
		if data.nextStop.gi then
			component.nextStop = cassette:loadGrid(data.nextStop)
		elseif type(data.nextStop[2]) == "number" then
			component.nextStop = {
				cassette:loadGrid(data.nextStop[1]),
				data.nextStop[2],
				data.nextStop[3] and cassette:loadEntity(data.nextStop[3]) or nil
			}
		else
			component.nextStop = cassette:loadGridList(data.nextStop)
		end
	end

	return component
end

function WalkingComponent:initialize(ti, tj, grids, instructions)
	self:setPath(nil)
	self:setNextGrid(nil)
	self:setTargetTile(ti, tj)
	self:setTargetGrids(grids)
	self:setTargetRotation(nil)
	self:setInstructions(instructions)
	self:setNextStop(nil)
	self:setSpeedModifier(1.0)
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

function WalkingComponent:getSpeedModifier()
	return self.speedModifier
end

function WalkingComponent:setSpeedModifier(speed)
	self.speedModifier = speed
end

return WalkingComponent
