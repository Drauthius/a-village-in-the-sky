--[[
Copyright (C) 2019  Albert Diserholt (@Drauthius)

This file is part of A Village in the Sky.

A Village in the Sky is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

A Village in the Sky is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with A Village in the Sky. If not, see <http://www.gnu.org/licenses/>.
--]]

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

function ProductionComponent.static:save(cassette)
	local data = {
		type = self.type,
		storedResources = self.storedResources,
		completion = {},
		reserved = {}
	}

	for villager,completion in pairs(self.completion) do
		table.insert(data.completion, { cassette:saveEntity(villager), completion })
	end
	for villager,reserved in pairs(self.reserved) do
		table.insert(data.reserved, { cassette:saveEntity(villager), reserved })
	end

	return data
end

function ProductionComponent.static.load(cassette, data)
	local component = ProductionComponent(data.type)

	component.storedResources = data.storedResources

	for _,completion in ipairs(data.completion) do
		component.completion[cassette:loadEntity(completion[1])] = completion[2]
	end
	for _,reserved in ipairs(data.reserved) do
		component.reserved[cassette:loadEntity(reserved[1])] = reserved[2]
	end

	return component
end

function ProductionComponent:initialize(type)
	self.type = type
	assert(ProductionComponent.SPECS[self.type], "No specification for "..tostring(type))

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
	local specs = ProductionComponent.SPECS[self.type]
	for resource,amount in pairs(specs.input) do
		if amount > 0 and (not blacklist or not blacklist[resource]) and
		   (not reserved or not reserved[resource] or reserved[resource] < amount) then
			amount = amount - (reserved and reserved[resource] or 0)
			if self.storedResources[resource] > 0 then
				local borrowed = math.min(self.storedResources[resource], amount)
				amount = amount - borrowed
				self:reserveResource(villager, resource, borrowed)
			end
			if amount > 0 then
				table.insert(resourcesNeeded, {resource, amount})
			end
		end
	end

	local len = #resourcesNeeded
	if len < 1 then
		return nil
	end

	local index = love.math.random(1, len)
	return resourcesNeeded[index][1], resourcesNeeded[index][2]
end

function ProductionComponent:getInput()
	return ProductionComponent.SPECS[self.type].input
end

function ProductionComponent:getOutput()
	return ProductionComponent.SPECS[self.type].output
end

function ProductionComponent:getMaxWorkers()
	return ProductionComponent.SPECS[self.type].maxWorkers
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
	if not self.reserved[villager] then
		return
	end

	for resource,amount in pairs(self.reserved[villager]) do
		self.storedResources[resource] = self.storedResources[resource] + amount
	end

	self.reserved[villager] = nil
end

function ProductionComponent:getCompletion(villager)
	return self.completion[villager] or 0.0
end

function ProductionComponent:increaseCompletion(villager, value)
	self.completion[villager] = math.min(100.0, self:getCompletion(villager) + value)
end

function ProductionComponent:isComplete(villager)
	return (self.completion[villager] or 0.0) >= 100.0
end

function ProductionComponent:reset(villager)
	self.completion[villager] = 0.0
	self.reserved[villager] = {}
end

return ProductionComponent
