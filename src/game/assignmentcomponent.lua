local class = require "lib.middleclass"

local AssignmentComponent = class("AssignmentComponent")

function AssignmentComponent.static:save(cassette)
	local data = {
		maxAssignees = self.maxAssignees,
		assignees = cassette:saveEntityList(self.assignees)
	}

	return data
end

function AssignmentComponent.static.load(cassette, data)
	local component = AssignmentComponent(data.maxAssignees)

	component.assignees = cassette:loadEntityList(data.assignees)

	return component
end

function AssignmentComponent:initialize(maxAssignees)
	self.maxAssignees = maxAssignees
	self.assignees = setmetatable({}, { __mode = 'v' })
end

function AssignmentComponent:assign(entity)
	if not self:isAssigned(entity) then
		table.insert(self.assignees, entity)
	end
end

function AssignmentComponent:unassign(entity)
	local _, k = self:isAssigned(entity)
	if k then
		table.remove(self.assignees, k)
	end
end

function AssignmentComponent:isAssigned(entity)
	for k,v in ipairs(self.assignees) do
		if v == entity then
			return true, k
		end
	end

	return false
end

function AssignmentComponent:getAssignees()
	return self.assignees
end

function AssignmentComponent:getNumAssignees()
	return #self.assignees
end

function AssignmentComponent:getMaxAssignees()
	return self.maxAssignees
end

return AssignmentComponent
