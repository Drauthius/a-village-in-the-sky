local class = require "lib.middleclass"

local FieldComponent = class("FieldComponent")

FieldComponent.static.UNCULTIVATED = 0
FieldComponent.static.PLOWED = 1
FieldComponent.static.SEEDED = 2
FieldComponent.static.GROWING = 3
FieldComponent.static.HARVESTING = 4
FieldComponent.static.IN_PROGRESS = 5

FieldComponent.static.STATE_NAMES = {
	[FieldComponent.UNCULTIVATED] = "uncultivated",
	[FieldComponent.PLOWED] = "plowed",
	[FieldComponent.SEEDED] = "seeded",
	[FieldComponent.GROWING] = "growing",
	[FieldComponent.HARVESTING] = "harvesting"
}

function FieldComponent:initialize()
end

function FieldComponent:getState()
	return self.state
end

function FieldComponent:setState(state)
	self.state = state
end

function FieldComponent:getPatches()
	return self.patches
end

function FieldComponent:setPatches(patches)
	self.patches = patches
end

function FieldComponent:getWorkedPatch()
	return self.workedPatch
end

function FieldComponent:setWorkedPatch(index)
	self.workedPatech = index
end

function FieldComponent:getWorkGrids(villager)
	self:reserve(villager)
	for _,patch in ipairs(self.patches) do
		if patch:get("AssignmentComponent"):isAssigned(villager) then
			return patch:get("WorkComponent"):getWorkGrids()
		end
	end
end

function FieldComponent:reserve(villager)
	for _,patch in ipairs(self.patches) do
		if not patch:get("WorkComponent"):isComplete() and patch:get("AssignmentComponent"):getNumAssignees() < 1 then
			patch:get("AssignmentComponent"):assign(villager)
			break
		end
	end
end

function FieldComponent:unreserve(villager)
	for _,patch in ipairs(self.patches) do
		if patch:get("AssignmentComponent"):isAssigned(villager) then
			patch:get("AssignmentComponent"):unassign(villager)
			break
		end
	end
end

return FieldComponent
