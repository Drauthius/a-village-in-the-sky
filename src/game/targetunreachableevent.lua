local class = require "lib.middleclass"

local TargetUnreachableEvent = class("TargetUnreachableEvent")

function TargetUnreachableEvent:initialize(villager, blocking, instructions)
	self.villager = villager
	self.blocking = blocking
	self.instructions = instructions
end

function TargetUnreachableEvent:getVillager()
	return self.villager
end

function TargetUnreachableEvent:getBlocking()
	return self.blocking
end

function TargetUnreachableEvent:getInstructions()
	return self.instructions
end

return TargetUnreachableEvent
