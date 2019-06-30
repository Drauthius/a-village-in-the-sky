local class = require "lib.middleclass"

local BuildingRazedEvent = class("BuildingRazedEvent")

function BuildingRazedEvent:initialize(building)
	self.building = building
end

function BuildingRazedEvent:getBuilding()
	return self.building
end

return BuildingRazedEvent
