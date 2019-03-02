local lovetoys = require "lib.lovetoys.lovetoys"

local TimerComponent = require "src.game.timercomponent"

local BuildingSystem = lovetoys.System:subclass("BuildingSystem")

BuildingSystem.static.DOOR_OPEN_TIME = 0.5

function BuildingSystem.requires()
	return {"BuildingComponent"}
end

function BuildingSystem:update(dt)
end

function BuildingSystem:buildingEnteredEvent(event)
	local entity = event:getBuilding()

	self:_openDoor(entity)

	if not event:isTemporary() then
		for _,chimney in ipairs(entity:get("BuildingComponent"):getChimneys()) do
			if chimney:get("AssignmentComponent"):getNumAssignees() < 1 then
				chimney:get("AssignmentComponent"):assign(event:getVillager())
				chimney:get("ParticleComponent"):getParticleSystem():start()
				return
			end
		end

		error("No free chimney?")
	end
end

function BuildingSystem:buildingLeftEvent(event)
	local entity = event:getBuilding()

	self:_openDoor(entity)

	for _,chimney in ipairs(entity:get("BuildingComponent"):getChimneys()) do
		if chimney:get("AssignmentComponent"):isAssigned(event:getVillager()) then
			chimney:get("AssignmentComponent"):unassign(event:getVillager())
			chimney:get("ParticleComponent"):getParticleSystem():pause()
			return
		end
	end

	error("Villager not assigned to chimney?")
end

function BuildingSystem:_openDoor(entity)
	entity:get("EntranceComponent"):setOpen(true)
	entity:get("SpriteComponent"):setNeedsRefresh(true)
	entity:set(TimerComponent(BuildingSystem.DOOR_OPEN_TIME, function()
		entity:get("EntranceComponent"):setOpen(false)
		entity:get("SpriteComponent"):setNeedsRefresh(true)
	end))
end

return BuildingSystem
