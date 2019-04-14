local class = require "lib.middleclass"

local CarryingComponent = class("CarryingComponent")

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
