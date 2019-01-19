local class = require "lib.middleclass"

local BuildingComponent = require "src.game.buildingcomponent"
local ResourceComponent = require "src.game.resourcecomponent"

local table = require "lib.table"

local UnderConstructionComponent = class("UnderConstructionComponent")

UnderConstructionComponent.static.MATERIALS = {
	[BuildingComponent.DWELLING] = {
		[ResourceComponent.WOOD] = 9,
		[ResourceComponent.IRON] = 0,
		[ResourceComponent.TOOL] = 2
	},
	[BuildingComponent.BLACKSMITH] = {
		[ResourceComponent.WOOD] = 9,
		[ResourceComponent.IRON] = 3,
		[ResourceComponent.TOOL] = 2
	},
	[BuildingComponent.FIELD] = {
		[ResourceComponent.WOOD] = 0,
		[ResourceComponent.IRON] = 0,
		[ResourceComponent.TOOL] = 2
	},
	[BuildingComponent.BAKERY] = {
		[ResourceComponent.WOOD] = 15,
		[ResourceComponent.IRON] = 3,
		[ResourceComponent.TOOL] = 3
	}
}

function UnderConstructionComponent:initialize(type)
	self.buildingType = type
	self.resourcesLeft = table.clone(UnderConstructionComponent.MATERIALS[self.buildingType])
	assert(self.resourcesLeft, "Missing resource information for building type "..tostring(self.buildingType))

	self.numCommittedResources = 0
	self.numAvailableResources = 0
	self.numTotalResources = 0
	for _,num in pairs(self.resourcesLeft) do
		self.numTotalResources = self.numTotalResources + num
	end
	assert(self.numTotalResources > 0, "No resources :(")
end

function UnderConstructionComponent:getPercentDone()
	return math.floor((self.numCommittedResources / self.numTotalResources) * 100)
end

function UnderConstructionComponent:updateWorkGrids(adjacent)
	if not self.workGrids then
		self.workGrids = adjacent
		return
	end

	for _,grid in ipairs(adjacent) do
		local added = false
		for _,workGrid in ipairs(self.workGrids) do
			if grid[1] == workGrid[1] then
				added = true
				break
			end
		end

		if not added then
			table.insert(self.workGrids, grid)
		end
	end
end

function UnderConstructionComponent:getFreeWorkGrids()
	local workGrids = {}
	for _,workGrid in ipairs(self.workGrids) do
		if not workGrid[3] then
			table.insert(workGrids, workGrid)
		end
	end

	return workGrids
end

function UnderConstructionComponent:getAssignedVillagers()
	local villagers = {}
	for _,workGrid in ipairs(self.workGrids or {}) do
		if workGrid[3] then
			table.insert(villagers, workGrid[3])
		end
	end

	return villagers
end

function UnderConstructionComponent:getRemainingResources(blacklist)
	local resourcesLeft = {}
	for resource,amount in pairs(self.resourcesLeft) do
		if amount > 0 and (not blacklist or not blacklist[resource]) then
			table.insert(resourcesLeft, resource)
		end
	end

	local len = #resourcesLeft
	if len < 1 then
		return nil
	end

	local index = love.math.random(1, len)
	return resourcesLeft[index], self.resourcesLeft[resourcesLeft[index]]
end

function UnderConstructionComponent:reserveResource(resource, amount)
	self.resourcesLeft[resource] = self.resourcesLeft[resource] - amount
	assert(self.resourcesLeft[resource] >= 0)
end

function UnderConstructionComponent:reserveGrid(villager, workGrid)
	workGrid[3] = villager
end

function UnderConstructionComponent:unreserveGrid(villager)
	for _,workGrid in ipairs(self.workGrids) do
		if workGrid[3] == villager then
			workGrid[3] = nil
			return
		end
	end

	error("Villager had not reserved a grid.")
end

function UnderConstructionComponent:addResources(resource, amount)
	self.numAvailableResources = self.numAvailableResources + amount
	assert(self.numAvailableResources <= self.numTotalResources,
		"Too many resources: "..self.numAvailableResources.."/"..self.numTotalResources)
end

function UnderConstructionComponent:commitResources(amount)
	self.numCommittedResources = math.min(self.numCommittedResources + amount, self.numAvailableResources)
end

function UnderConstructionComponent:canBuild()
	return self.numCommittedResources < self.numAvailableResources
end

function UnderConstructionComponent:isComplete()
	return self.numCommittedResources == self.numTotalResources
end

return UnderConstructionComponent
