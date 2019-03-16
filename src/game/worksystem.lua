local Timer = require "lib.hump.timer"
local lovetoys = require "lib.lovetoys.lovetoys"

local BuildingCompletedEvent = require "src.game.buildingcompletedevent"
local WorkCompletedEvent = require "src.game.workcompletedevent"
local BuildingLeftEvent = require "src.game.buildingleftevent"
local CarryingComponent = require "src.game.carryingcomponent"
local PositionComponent = require "src.game.positioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local WorkComponent = require "src.game.workcomponent"

local blueprint = require "src.game.blueprint"
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

WorkSystem.static.COMPLETION = {
	-- How many animation frames to require before the resource is completed.
	RESOURCE = 100 / 55
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

		if not construction:canBuild() then
			for _,worker in ipairs(workPlace:get("AssignmentComponent"):getAssignees()) do
				if construction:isComplete() then
					self.eventManager:fireEvent(WorkCompletedEvent(workPlace, entity))
				else
					if worker:has("WorkingComponent") and worker:get("WorkingComponent"):getWorking() then
						construction:unreserveGrid(worker)
						self.eventManager:fireEvent(WorkCompletedEvent(workPlace, entity, true))
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
		assert(work:getType() == WorkComponent.WOODCUTTER or
		       work:getType() == WorkComponent.MINER,
		       "Unhandled work done.")

		work:increaseCompletion(WorkSystem.COMPLETION.RESOURCE)

		if work:getType() == WorkComponent.WOODCUTTER then
			local spark = blueprint:createWoodSparksParticle()
			spark:add(PositionComponent(workPlace:get("PositionComponent"):getGrid()))
			spark:get("SpriteComponent"):setDrawPosition(dx + 14, dy + 55) -- XXX
			self.engine:addEntity(spark)
		elseif work:getType() == WorkComponent.MINER then
			local spark = blueprint:createIronSparksParticle()
			spark:add(PositionComponent(workPlace:get("PositionComponent"):getGrid()))
			spark:get("SpriteComponent"):setDrawPosition(dx + 12, dy + 5) -- XXX
			self.engine:addEntity(spark)
		end

		if work:isComplete() then
			local workers = workPlace:get("AssignmentComponent"):getAssignees()
			local numWorkers = workPlace:get("AssignmentComponent"):getNumAssignees()
			assert(numWorkers == 1, "Too many or too few workers on a resource.")
			assert(workers[1] == entity, "The villager that did the work was not assigned?")

			local resource = workPlace:get("ResourceComponent")
			entity:add(CarryingComponent(resource:getResource(), resource:getResourceAmount()))

			soundManager:playEffect(ResourceComponent.RESOURCE_NAME[resource:getResource()].."Gathered")

			self.eventManager:fireEvent(WorkCompletedEvent(workPlace, entity))

			self.engine:removeEntity(workPlace, true)
		else
			soundManager:playEffect(WorkComponent.WORK_NAME[work:getType()].."Working")
		end
	end
end

return WorkSystem
