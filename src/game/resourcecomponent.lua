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

local ResourceComponent = class("ResourceComponent")

ResourceComponent.static.WOOD = 0
ResourceComponent.static.IRON = 1
ResourceComponent.static.TOOL = 2
ResourceComponent.static.GRAIN = 3
ResourceComponent.static.BREAD = 4

ResourceComponent.static.RESOURCE_NAME = {
	[ResourceComponent.WOOD] = "wood",
	[ResourceComponent.IRON] = "iron",
	[ResourceComponent.TOOL] = "tool",
	[ResourceComponent.GRAIN] = "grain",
	[ResourceComponent.BREAD] = "bread",
}

function ResourceComponent.static:save(cassette)
	return {
		resource = self.resource,
		stack = self.stack,
		extracted = self.extracted,
		reserved = self.reserved and cassette:saveEntity(self.reserved) or nil,
		reservedAmount = self.reservedAmount,
		allocation = self.allocation and cassette:saveEntity(self.allocation) or nil
	}
end

function ResourceComponent.static.load(cassette, data)
	local component = ResourceComponent(data.resource, data.stack, data.extracted)

	component:setReserved(
		data.reserved and cassette:loadEntity(data.reserved) or nil,
		data.reservedAmount,
		data.allocation and cassette:loadEntity(data.allocation) or nil)

	return component
end

function ResourceComponent:initialize(resource, num, extracted)
	self.resource = resource
	self.stack = num or 3
	self.extracted = extracted or false
	self.reserved = nil
	self.allocation = nil
	self.reservedAmount = 0
end

function ResourceComponent:getResource()
	return self.resource
end

function ResourceComponent:getResourceAmount()
	return self.stack
end

function ResourceComponent:decreaseAmount(amount)
	self.stack = self.stack - amount
	assert(self.stack >= 0)
end

function ResourceComponent:isUsable()
	return self.extracted and self.reserved == nil
end

function ResourceComponent:isExtracted()
	return self.extracted
end

function ResourceComponent:getReservedBy()
	return self.reserved
end

function ResourceComponent:getReservedAmount()
	return self.reservedAmount
end

function ResourceComponent:setReserved(target, amount, allocation)
	self.reserved = target
	self.reservedAmount = amount or 0
	self.allocation = allocation
end

function ResourceComponent:getAllocation()
	return self.allocation
end

return ResourceComponent
