local class = require "lib.middleclass"

local ResourceComponent = require "src.game.resourcecomponent"

local State = class("State")

function State:initialize()
	self.mouseCoords = {
		x = 0,
		y = 0
	}
	self.placing = nil
	self.selected = nil
	self.resources = {
		[ResourceComponent.WOOD] = 0,
		[ResourceComponent.IRON] = 0,
		[ResourceComponent.TOOL] = 0,
		[ResourceComponent.GRAIN] = 0,
		[ResourceComponent.BREAD] = 0
	}
	self.reservedResources = {
		[ResourceComponent.WOOD] = 0,
		[ResourceComponent.IRON] = 0,
		[ResourceComponent.TOOL] = 0,
		[ResourceComponent.GRAIN] = 0,
		[ResourceComponent.BREAD] = 0
	}
	self.villagers = {
		maleVillagers = 0,
		femaleVillagers = 0,
		maleChildren = 0,
		femaleChildren = 0
	}
end

--
-- Mouse position (in world coordinates)
--

function State:getMousePosition()
	return self.mouseCoords.x, self.mouseCoords.y
end

function State:setMousePosition(x, y)
	self.mouseCoords.x, self.mouseCoords.y = x, y
end

--
-- Placing
--
function State:isPlacing()
	return self.placing ~= nil
end

function State:getPlacing()
	return self.placing
end

function State:setPlacing(placeable)
	self.placing = placeable
	self:clearSelection()
end

function State:clearPlacing()
	self.placing = nil
end

--
-- Selecting
--
function State:hasSelection()
	return self.selected ~= nil
end

function State:getSelection()
	return self.selected
end

function State:setSelection(selected)
	self.selected = selected
end

function State:clearSelection()
	self.selected = nil
end

--
-- Resources
--
function State:getNumResources(resource)
	return assert(self.resources[resource], "Resource " .. tostring(resource) .. " doesn't exist.")
end

function State:getNumReservedResources(resource)
	return assert(self.reservedResources[resource], "Resource " .. tostring(resource) .. " doesn't exist.")
end

function State:getNumAvailableResources(resource)
	return math.max(0, self:getNumResources(resource) - self:getNumReservedResources(resource))
end

function State:reserveResource(resource, amount)
	self.reservedResources[resource] = self.reservedResources[resource] + (amount or 1)
end

function State:removeReservedResource(resource, amount)
	self.reservedResources[resource] = self.reservedResources[resource] - (amount or 1)
	assert(self.reservedResources[resource] >= 0)
end

function State:increaseResource(resource, amount)
	self.resources[resource] = self.resources[resource] + (amount or 1)
end

function State:decreaseResource(resource, amount)
	self.resources[resource] = self.resources[resource] - (amount or 1)
	assert(self.resources[resource] >= 0)
end

function State:getNumWood()
	return self:getNumResources(ResourceComponent.WOOD)
end

function State:increaseNumWood(amount)
	self:increaseResource(ResourceComponent.WOOD, amount)
end

function State:getNumIron()
	return self:getNumResources(ResourceComponent.IRON)
end

function State:increaseNumIron(amount)
	self:increaseResource(ResourceComponent.IRON, amount)
end

function State:getNumTool()
	return self:getNumResources(ResourceComponent.IRON)
end

function State:increaseNumTool(amount)
	self:increaseResource(ResourceComponent.TOOL, amount)
end

function State:getNumGrain()
	return self:getNumResources(ResourceComponent.GRAIN)
end

function State:increaseNumGrain(amount)
	self:increaseResource(ResourceComponent.GRAIN, amount)
end

function State:getNumBread()
	return self:getNumResources(ResourceComponent.BREAD)
end

function State:increaseNumBread(amount)
	self:increaseResource(ResourceComponent.BREAD, amount)
end

--
-- Villagers
--
function State:increaseNumMaleVillagers()
	self.villagers.maleVillagers = self.villagers.maleVillagers + 1
end

function State:getNumMaleVillagers()
	return self.villagers.maleVillagers
end

function State:increaseNumFemaleVillagers()
	self.villagers.femaleVillagers = self.villagers.femaleVillagers + 1
end

function State:getNumFemaleVillagers()
	return self.villagers.femaleVillagers
end

function State:increaseNumMaleChildren()
	self.villagers.maleChildren = self.villagers.maleChildren + 1
end

function State:getNumMaleChildren()
	return self.villagers.maleChildren
end

function State:increaseNumFemaleChildren()
	self.villagers.femaleChildren = self.villagers.femaleChildren + 1
end

function State:getNumFemaleChildren()
	return self.villagers.femaleChildren
end

return State()
