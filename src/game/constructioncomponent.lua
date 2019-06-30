local class = require "lib.middleclass"

local BuildingComponent = require "src.game.buildingcomponent"
local ResourceComponent = require "src.game.resourcecomponent"

local table = require "lib.table"

local ConstructionComponent = class("ConstructionComponent")

ConstructionComponent.static.MATERIALS = {
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
	},
	[BuildingComponent.RUNESTONE] = {
		-- Stages
		[1] = {
			[ResourceComponent.WOOD] = 1,
			[ResourceComponent.IRON] = 0,
			[ResourceComponent.TOOL] = 2
		},
		[2] = {
			[ResourceComponent.WOOD] = 2,
			[ResourceComponent.IRON] = 2,
			[ResourceComponent.TOOL] = 3
		},
		[3] = {
			[ResourceComponent.WOOD] = 4,
			[ResourceComponent.IRON] = 6,
			[ResourceComponent.TOOL] = 4
		},
		[4] = {
			[ResourceComponent.WOOD] = 8,
			[ResourceComponent.IRON] = 14,
			[ResourceComponent.TOOL] = 5
		},
		[5] = {
			[ResourceComponent.WOOD] = 14,
			[ResourceComponent.IRON] = 18,
			[ResourceComponent.TOOL] = 6
		}
	}
}

function ConstructionComponent.static:getRefundedResources(type)
	local refund = {}
	for resource,amount in pairs(ConstructionComponent.MATERIALS[type]) do
		refund[resource] = math.floor(amount * 0.75)
	end

	return refund
end

function ConstructionComponent:initialize(type, level)
	self.buildingType = type
	self.blueprint = ConstructionComponent.MATERIALS[self.buildingType]
	if level then
		self.blueprint = self.blueprint[level]
	end
	assert(self.blueprint, "Missing resource information for building type "..tostring(self.buildingType))

	self.missingResources = table.clone(self.blueprint)
	self.unreservedResources = table.clone(self.blueprint)

	self.numCommittedResources = 0
	self.numAvailableResources = 0
	self.numTotalResources = 0
	for _,num in pairs(self.missingResources) do
		self.numTotalResources = self.numTotalResources + num
	end
	assert(self.numTotalResources > 0, "No resources :(")
end

function ConstructionComponent:getType()
	return self.buildingType
end

function ConstructionComponent:getPercentDone()
	return math.floor(self:getValueDone() * 100)
end

function ConstructionComponent:getValueDone()
	return self.numCommittedResources / self.numTotalResources
end

function ConstructionComponent:getValueBuildable()
	return self.numAvailableResources / self.numTotalResources
end

function ConstructionComponent:updateWorkGrids(adjacent)
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

function ConstructionComponent:getFreeWorkGrids()
	local workGrids = {}
	for _,workGrid in ipairs(self.workGrids) do
		if not workGrid[3] then
			table.insert(workGrids, workGrid)
		end
	end

	return workGrids
end

function ConstructionComponent:getRemainingResources()
	return self.missingResources
end

function ConstructionComponent:getRefundedResources()
	local refund = {}
	for resource,amount in pairs(self.blueprint) do
		refund[resource] = math.floor((amount - self.missingResources[resource]) * 0.75)
	end

	return refund
end

function ConstructionComponent:getRandomUnreservedResource(blacklist)
	local resourcesLeft = {}
	for resource,amount in pairs(self.unreservedResources) do
		if amount > 0 and (not blacklist or not blacklist[resource]) then
			table.insert(resourcesLeft, resource)
		end
	end

	local len = #resourcesLeft
	if len < 1 then
		return nil
	end

	local index = love.math.random(1, len)
	return resourcesLeft[index], self.unreservedResources[resourcesLeft[index]]
end

function ConstructionComponent:reserveResource(resource, amount)
	self.unreservedResources[resource] = self.unreservedResources[resource] - amount
	assert(self.unreservedResources[resource] >= 0)
end

function ConstructionComponent:unreserveResource(resource, amount)
	self.unreservedResources[resource] = self.unreservedResources[resource] + amount
	--assert(self.unreservedResources[resource] <= ConstructionComponent.MATERIALS[self.buildingType][resource])
end

function ConstructionComponent:reserveGrid(villager, workGrid)
	workGrid[3] = villager
end

function ConstructionComponent:unreserveGrid(villager)
	for _,workGrid in ipairs(self.workGrids) do
		if workGrid[3] == villager then
			workGrid[3] = nil
			return
		end
	end
end

function ConstructionComponent:addResources(resource, amount)
	self.numAvailableResources = self.numAvailableResources + amount
	assert(self.numAvailableResources <= self.numTotalResources,
		"Too many resources: "..self.numAvailableResources.."/"..self.numTotalResources)

	self.missingResources[resource] = self.missingResources[resource] - amount
	assert(self.missingResources[resource] >= 0)
end

function ConstructionComponent:commitResources(amount)
	-- The amount is in percent completion. Convert it to number of resources.
	amount = self.numTotalResources * (amount / 100)
	self.numCommittedResources = math.min(self.numCommittedResources + amount, self.numAvailableResources)
end

function ConstructionComponent:canBuild()
	return self.numCommittedResources < self.numAvailableResources
end

function ConstructionComponent:isComplete()
	return self.numCommittedResources == self.numTotalResources
end

return ConstructionComponent
