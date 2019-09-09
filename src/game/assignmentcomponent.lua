--[[
Copyright (C) 2019  Albert Diserholt (@Drauthius)

This file is part of A Village in the Sky.

A Village in the Sky is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

A Village in the Sky is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with A Village in the Sky. If not, see <http://www.gnu.org/licenses/>.
--]]

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
