local class = require "lib.middleclass"

local BuildingLeftEvent = class("BuildingLeftEvent")

function BuildingLeftEvent:initialize(building, villager)
	self.building = building
	self.villager = villager
end

function BuildingLeftEvent:getBuilding()
	return self.building
end

function BuildingLeftEvent:getVillager()
	return self.villager
end

return BuildingLeftEvent
