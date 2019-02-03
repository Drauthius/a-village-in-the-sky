local class = require "lib.middleclass"

local TargetReachedEvent = class("TargetReachedEvent")

function TargetReachedEvent:initialize(villager, target, rotation, nextStop)
	self.villager = villager
	self.target = target
	self.rotation = rotation
	self.nextStop = nextStop
end

function TargetReachedEvent:getVillager()
	return self.villager
end

function TargetReachedEvent:getTarget()
	return self.target
end

function TargetReachedEvent:getRotation()
	return self.rotation
end

function TargetReachedEvent:getNextStop()
	return self.nextStop
end

return TargetReachedEvent
