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
		pathAge = self.pathAge,
		nextGrid = self.nextGrid and cassette:saveGrid(self.nextGrid),
		ti = self.ti,
		tj = self.tj,
		grids = self.targetGrids and cassette:saveGridList(self.grids),
		rotation = self.rotation,
		instructions = self.instructions,
		speedModifier = self.speedModifier,
		delay = self.delay,
		numRetries = self.numRetries
	}

	if self.targetEntity then -- XXX: A little bonkers.
		if self.targetEntity.gi then
			data.targetEntity = cassette:saveGrid(self.targetEntity)
		else
			data.targetEntity = cassette:saveEntity(self.targetEntity)
		end
	end

	if self.nextStop then -- XXX: A little bonkers.
		if self.nextStop.gi then
			data.nextStop = cassette:saveGrid(self.nextStop)
		else
			data.nextStop = {
				cassette:saveGrid(self.nextStop[1]),
				self.nextStop[2],
				self.nextStop[3] and cassette:saveEntity(self.nextStop[3]) or nil
			}
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
	component.pathAge = data.pathAge
	component.nextGrid = data.nextGrid and cassette:loadGrid(data.nextGrid) or nil
	component.rotation = data.rotation
	component.delay = data.delay
	component.numRetries = data.numRetries

	if data.targetEntity then -- XXX: A little bonkers.
		if type(data.targetEntity[1]) == "number" then
			component.targetEntity = cassette:loadGrid(data.targetEntity)
		else
			component.targetEntity = cassette:loadEntity(data.targetEntity)
		end
	end

	if data.nextStop then -- XXX: A little bonkers.
		if type(data.nextStop[1]) == "number" then
			component.nextStop = cassette:loadGrid(data.nextStop)
		else
			component.nextStop = {
				cassette:loadGrid(data.nextStop[1]),
				data.nextStop[2],
				data.nextStop[3] and cassette:loadEntity(data.nextStop[3]) or nil
			}
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
	self:setDelay(0.0)
	self:setNumRetries(0)
end

function WalkingComponent:getPath()
	return self.path
end

function WalkingComponent:setPath(path)
	self.path = path
	self.pathAge = 0.0
end

function WalkingComponent:getPathAge()
	return self.pathAge
end

function WalkingComponent:increasePathAge(dt)
	self.pathAge = self.pathAge + dt
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

function WalkingComponent:getDelay()
	return self.delay
end

function WalkingComponent:setDelay(dt)
	self.delay = dt
end

function WalkingComponent:getNumRetries()
	return self.numRetries
end

function WalkingComponent:setNumRetries(retries)
	self.numRetries = retries
end

return WalkingComponent
