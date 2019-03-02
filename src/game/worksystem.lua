local Timer = require "lib.hump.timer"
local lovetoys = require "lib.lovetoys.lovetoys"

local BuildingCompletedEvent = require "src.game.buildingcompletedevent"
local BuildingLeftEvent = require "src.game.buildingleftevent"
local CarryingComponent = require "src.game.carryingcomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local VillagerComponent = require "src.game.villagercomponent"
local WorkComponent = require "src.game.workcomponent"

local soundManager = require "src.soundmanager"

local WorkSystem = lovetoys.System:subclass("WorkSystem")

WorkSystem.static.DIR_CONV = {
	N  = {  0, -1 },
	NE = {  1, -1 },
	E  = {  1,  0 },
	SE = {  1,  1 },
	S  = {  0,  1 },
	SW = { -1,  1 },
	W  = { -1,  0 },
	NW = { -1, -1 }
}

-- TODO: Currently handles both Work, Construction, and Production
function WorkSystem.requires()
	return {"ProductionComponent"}
end

function WorkSystem:initialize(engine, eventManager)
	lovetoys.System.initialize(self)

	self.engine = engine
	self.eventManager = eventManager
end

function WorkSystem:update(dt)
	for _,entity in pairs(self.targets) do
		local production = entity:get("ProductionComponent")
		for _,villagerEntity in ipairs(entity:get("AssignmentComponent"):getAssignees()) do
			if villagerEntity:has("WorkingComponent") and villagerEntity:get("WorkingComponent"):getWorking() then
				production:increaseCompletion(villagerEntity, 10.0 * dt) -- TODO: Value!
				if production:isComplete(villagerEntity) then
					production:reset(villagerEntity)
					villagerEntity:add(CarryingComponent(next(production:getOutput())))

					self.eventManager:fireEvent(BuildingLeftEvent(entity, villagerEntity))
				end
			end
		end
	end
end

function WorkSystem:workEvent(event)
	local entity = event:getVillager()
	local workPlace = event:getWorkPlace()

	if workPlace:has("FieldComponent") then
		-- Handled elsewhere.
		return
	end

	local shake = 2
	local workSprite = workPlace:get("SpriteComponent")
	local cardinalDir = entity:get("VillagerComponent"):getCardinalDirection()
	local dx, dy = workSprite.x, workSprite.y
	workSprite.x = workSprite.x + WorkSystem.DIR_CONV[cardinalDir][1] * shake
	workSprite.y = workSprite.y + WorkSystem.DIR_CONV[cardinalDir][2] * shake
	Timer.tween(0.12, workSprite, { x = dx, y = dy }, "in-bounce")

	if workPlace:has("ConstructionComponent") then
		local crafts = entity:get("VillagerComponent"):getCraftsmanship()

		local construction = workPlace:get("ConstructionComponent")
		construction:commitResources(crafts * 1) -- TODO: Value

		soundManager:playEffect("building")

		-- TODO: Maybe send this off in an event.
		if not construction:canBuild() then
			for _,worker in ipairs(workPlace:get("AssignmentComponent"):getAssignees()) do
				if construction:isComplete() then
					if worker:has("WorkingComponent") then
						worker:remove("WorkingComponent")
					end
					worker:get("AdultComponent"):setWorkPlace(nil)
					worker:get("VillagerComponent"):setGoal(VillagerComponent.GOALS.NONE)
				else
					if worker:has("WorkingComponent") and worker:get("WorkingComponent"):getWorking() then
						construction:unreserveGrid(worker)
						worker:remove("WorkingComponent")
						worker:get("VillagerComponent"):setGoal(VillagerComponent.GOALS.NONE)
					end
				end
			end

			if construction:isComplete() then
				workPlace:remove("ConstructionComponent")
				workPlace:remove("AssignmentComponent")
				soundManager:playEffect("buildingComplete") -- TODO: Add type

				self.eventManager:fireEvent(BuildingCompletedEvent(workPlace))
			end
		end
	else
		local work = workPlace:get("WorkComponent")
		work:increaseCompletion(10.0) -- TODO: Value!

		-- TODO: Maybe send this off in an event.
		if work:isComplete() then
			local workers = workPlace:get("AssignmentComponent"):getAssignees()
			local numWorkers = workPlace:get("AssignmentComponent"):getNumAssignees()

			if work:getType() == WorkComponent.WOODCUTTER or
			   work:getType() == WorkComponent.MINER then
				for _,worker in ipairs(workers) do
					worker:remove("WorkingComponent")
					worker:get("AdultComponent"):setWorkPlace(nil)
					worker:get("VillagerComponent"):setGoal(VillagerComponent.GOALS.NONE)
				end

				local resource = workPlace:get("ResourceComponent")
				assert(numWorkers == 1, "Too many or too few workers on a resource.")
				workers[1]:add(CarryingComponent(resource:getResource(), resource:getResourceAmount()))

				soundManager:playEffect(ResourceComponent.RESOURCE_NAME[resource:getResource()].."Gathered")

				self.engine:removeEntity(workPlace, true)
			else
				error("Unknown work complete.")
			end
		else
			soundManager:playEffect(WorkComponent.WORK_NAME[work:getType()].."Working")
		end
	end
end

return WorkSystem
