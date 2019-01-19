local class = require "lib.middleclass"

local WorkEvent = class("WorkEvent")

function WorkEvent:initialize(villager, workPlace)
	self.villager = villager
	self.workPlace = workPlace
end

function WorkEvent:getVillager()
	return self.villager
end

function WorkEvent:getWorkPlace()
	return self.workPlace
end

return WorkEvent
