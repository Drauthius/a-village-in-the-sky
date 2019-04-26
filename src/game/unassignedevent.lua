local class = require "lib.middleclass"

local UnassignedEvent = class("UnassignedEvent")

function UnassignedEvent:initialize(assigner, assignee)
	self.assigner = assigner
	self.assignee = assignee
end

function UnassignedEvent:getAssigner()
	return self.assigner
end

function UnassignedEvent:getAssignee()
	return self.assignee
end

return UnassignedEvent
