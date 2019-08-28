local class = require "lib.middleclass"

local TargetUnreachableEvent = class("TargetUnreachableEvent")

function TargetUnreachableEvent:initialize(villager)
	self.villager = villager
end

function TargetUnreachableEvent:getVillager()
	return self.villager
end

return TargetUnreachableEvent
