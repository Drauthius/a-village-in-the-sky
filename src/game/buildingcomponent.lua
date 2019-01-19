local class = require "lib.middleclass"

local BuildingComponent = class("BuildingComponent")

BuildingComponent.static.DWELLING = 0
BuildingComponent.static.BLACKSMITH = 1
BuildingComponent.static.FIELD = 2
BuildingComponent.static.BAKERY = 3

function BuildingComponent:initialize(type, ti, tj)
	self:setType(type)
	self:setPosition(ti, tj)
end

function BuildingComponent:setType(type)
	self.type = type
end

function BuildingComponent:getType()
	return self.type
end

function BuildingComponent:getPosition()
	return self.ti, self.tj
end

function BuildingComponent:setPosition(ti, tj)
	self.ti, self.tj = ti, tj
end

return BuildingComponent
