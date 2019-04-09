local class = require "lib.middleclass"

local VillagerAgedEvent = class("VillagerAgedEvent")

function VillagerAgedEvent:initialize(villager)
	self.villager = villager
end

function VillagerAgedEvent:getVillager()
	return self.villager
end

return VillagerAgedEvent
