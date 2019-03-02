local class = require "lib.middleclass"

local BuildingEnteredEvent = class("BuildingEnteredEvent")

function BuildingEnteredEvent:initialize(building, villager, temporary)
	self.building = building
	self.villager = villager
	self.temporary = temporary
end

function BuildingEnteredEvent:getBuilding()
	return self.building
end

function BuildingEnteredEvent:getVillager()
	return self.villager
end

function BuildingEnteredEvent:isTemporary()
	return self.temporary
end

return BuildingEnteredEvent
