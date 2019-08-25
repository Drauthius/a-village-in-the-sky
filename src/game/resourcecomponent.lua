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
		reservedAmount = self.reservedAmount
	}
end

function ResourceComponent.static.load(cassette, data)
	local component = ResourceComponent(data.resource, data.stack, data.extracted)

	component:setReserved(data.reserved and cassette:loadEntity(data.reserved) or nil, data.reservedAmount)

	return component
end

function ResourceComponent:initialize(resource, num, extracted)
	self.resource = resource
	self.stack = num or 3
	self.extracted = extracted or false
	self.reserved = nil
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

function ResourceComponent:setReserved(target, amount)
	self.reserved = target
	self.reservedAmount = amount or 0
end

return ResourceComponent
