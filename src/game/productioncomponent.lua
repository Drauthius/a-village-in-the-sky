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
		},
		entrance = {
			rotation = 0, ogi = -1, ogj = -8
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
	self.workers = {}
	self.completion = setmetatable({}, { __mode = 'k' })
	self.reserved = setmetatable({}, { __mode = 'k' })
end

function ProductionComponent:assign(villager)
	assert(#self.workers < self.specs.maxWorkers, "Too many workers")
	table.insert(self.workers, villager)
	self.completion[villager] = 0.0
end

function ProductionComponent:unassign(villager)
	for k,v in ipairs(self.workers) do
		if v == villager then
			table.remove(self.workers, k)
			self.completion[villager] = nil
			for resource,amount in pairs(self.reserved[villager] or {}) do
				self.storedResources[resource] = self.storedResource[resource] + amount
				error("TODO: No real support for this yet.")
				-- Villagers will not work more if there are resources left, meaning that they are currently WASTED.
			end
			return
		end
	end

	error("Villager does not work here.")
end

function ProductionComponent:getAssignedVillagers()
	return self.workers
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

function ProductionComponent:getEntrance()
	return self.specs.entrance
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

function ProductionComponent:increaseCompletion(villager, value)
	assert(self.completion[villager], "Villager does not work here.")
	self.completion[villager] = self.completion[villager] + value
end

function ProductionComponent:isComplete(villager)
	assert(self.completion[villager], "Villager does not work here.")
	return self.completion[villager] >= 100.0
end

function ProductionComponent:reset(villager)
	self.completion[villager] = 0.0
	self.reserved[villager] = {}
end

return ProductionComponent
