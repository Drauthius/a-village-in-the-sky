local class = require "lib.middleclass"

local TargetUnreachableEvent = class("TargetUnreachableEvent")

function TargetUnreachableEvent:initialize(villager, instructions)
	self.villager = villager
	self.instructions = instructions
end

function TargetUnreachableEvent:getVillager()
	return self.villager
end

function TargetUnreachableEvent:getInstructions()
	return self.instructions
end

return TargetUnreachableEvent
