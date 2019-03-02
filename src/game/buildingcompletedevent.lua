local class = require "lib.middleclass"

local BuildingCompletedEvent = class("BuildingCompletedEvent")

function BuildingCompletedEvent:initialize(building)
	self.building = building
end

function BuildingCompletedEvent:getBuilding()
	return self.building
end

return BuildingCompletedEvent
