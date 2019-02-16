local class = require "lib.middleclass"

local AssignedEvent = class("AssignedEvent")

function AssignedEvent:initialize(assigner, assignee)
	self.assigner = assigner
	self.assignee = assignee
end

function AssignedEvent:getAssigner()
	return self.assigner
end

function AssignedEvent:getAssignee()
	return self.assignee
end

return AssignedEvent
