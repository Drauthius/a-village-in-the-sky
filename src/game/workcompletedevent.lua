local class = require "lib.middleclass"

local WorkCompletedEvent = class("WorkCompletedEvent")

function WorkCompletedEvent:initialize(workSite, villager, temporary)
	self.workSite = workSite
	self.villager = villager
	self.temporary = temporary
end

function WorkCompletedEvent:getWorkSite()
	return self.workSite
end

function WorkCompletedEvent:getVillager()
	return self.villager
end

function WorkCompletedEvent:isTemporary()
	return self.temporary
end

return WorkCompletedEvent
