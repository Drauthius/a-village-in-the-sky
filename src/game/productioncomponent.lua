local class = require "lib.middleclass"

local BuildingComponent = require "src.game.buildingcomponent"
local ResourceComponent = require "src.game.resourcecomponent"

local ProductionComponent = class("ProductionComponent")

ProductionComponent.static.SPECS = {
	[BuildingComponent.BLACKSMITH] = {
		maxWorkers = 1,
		input = {
			[ResourceComponent.WOOD] = 1,
			[ResourceComponent.IRON] = 2
		},
		output = {
			[ResourceComponent.TOOL] = 1
		}
	},
	[BuildingComponent.BAKERY] = {
		maxWorkers = 3,
		input = {
			[ResourceComponent.GRAIN] = 2
		},
		output = {
			[ResourceComponent.BREAD] = 3
		}
	}
}

function ProductionComponent:initialize(type)
	self.specs = ProductionComponent.SPECS[type]
	assert(self.specs, "No specification for "..tostring(type))
	self.storedResources = {
		[ResourceComponent.WOOD] = 0,
		[ResourceComponent.IRON] = 0,
		[ResourceComponent.TOOL] = 0,
		[ResourceComponent.GRAIN] = 0,
		[ResourceComponent.BREAD] = 0
	}
	self.completion = setmetatable({}, { __mode = 'k' })
	self.reserved = setmetatable({}, { __mode = 'k' })
end

function ProductionComponent:getNeededResources(villager, blacklist)
	local resourcesNeeded = {}
	local reserved = self.reserved[villager]
	for resource,amount in pairs(self.specs.input) do
		if amount > 0 and (not blacklist or not blacklist[resource]) and
		   (not reserved or not reserved[resource] or reserved[resource] < amount) then
			table.insert(resourcesNeeded, resource)
		end
	end

	local len = #resourcesNeeded
	if len < 1 then
		return nil
	end

	-- TODO: This can get more resources than needed, resulting in WASTE.
	local index = love.math.random(1, len)
	return resourcesNeeded[index], self.specs.input[resourcesNeeded[index]]
end

function ProductionComponent:getOutput()
	return self.specs.output
end

function ProductionComponent:getMaxWorkers()
	return self.specs.maxWorkers
end

function ProductionComponent:addResource(resource, amount)
	self.storedResources[resource] = self.storedResources[resource] + amount
end

function ProductionComponent:reserveResource(villager, resource, amount)
	if not self.reserved[villager] then
		self.reserved[villager] = {}
	end
	if not self.reserved[villager][resource] then
		self.reserved[villager][resource] = 0
	end
	self.reserved[villager][resource] = self.reserved[villager][resource] + amount
	self.storedResources[resource] = self.storedResources[resource] - amount
end

function ProductionComponent:releaseResources(villager)
	error("Unimplemented.")
end

function ProductionComponent:getCompletion(villager)
	return self.completion[villager] or 0.0
end

function ProductionComponent:increaseCompletion(villager, value)
	self.completion[villager] = (self.completion[villager] or 0.0) + value
end

function ProductionComponent:isComplete(villager)
	return (self.completion[villager] or 0.0) >= 100.0
end

function ProductionComponent:reset(villager)
	self.completion[villager] = 0.0
	self.reserved[villager] = {}
end

return ProductionComponent
