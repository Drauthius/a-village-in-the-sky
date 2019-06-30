local class = require "lib.middleclass"

local ConstructionCancelledEvent = class("ConstructionCancelledEvent")

function ConstructionCancelledEvent:initialize(building)
	self.building = building
end

function ConstructionCancelledEvent:getBuilding()
	return self.building
end

return ConstructionCancelledEvent
