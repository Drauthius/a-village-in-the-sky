local class = require "lib.middleclass"

local TargetUnreachableEvent = class("TargetUnreachableEvent")

function TargetUnreachableEvent:initialize(villager, blocking, retry, instructions)
	self.villager = villager
	self.blocking = blocking
	self.retry = retry
	self.instructions = instructions
end

function TargetUnreachableEvent:getVillager()
	return self.villager
end

function TargetUnreachableEvent:getBlocking()
	return self.blocking
end

function TargetUnreachableEvent:shouldRetry()
	return self.retry
end

function TargetUnreachableEvent:setRetry(retry)
	self.retry = retry
end

function TargetUnreachableEvent:getInstructions()
	return self.instructions
end

return TargetUnreachableEvent
