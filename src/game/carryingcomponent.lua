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
