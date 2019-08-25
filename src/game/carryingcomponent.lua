local class = require "lib.middleclass"

local CarryingComponent = class("CarryingComponent")

function CarryingComponent.static:save()
	return {
		resource = self.resource,
		amount = self.amount
	}
end

function CarryingComponent.static.load(_, data)
	return CarryingComponent(data.resource, data.amount)
end

function CarryingComponent:initialize(resource, amount)
	self.resource = resource
	self.amount = amount
end

function CarryingComponent:getResource()
	return self.resource
end

function CarryingComponent:getAmount()
	return self.amount
end

function CarryingComponent:setAmount(amount)
	self.amount = amount
end

return CarryingComponent
