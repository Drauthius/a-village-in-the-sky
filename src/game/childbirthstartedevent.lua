local class = require "lib.middleclass"

local ChildbirthStartedEvent = class("ChildbirthStartedEvent")

function ChildbirthStartedEvent:initialize(villager)
	self.villager = villager
end

function ChildbirthStartedEvent:getVillager()
	return self.villager
end

return ChildbirthStartedEvent
