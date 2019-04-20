local Timer = require "lib.hump.timer"
local lovetoys = require "lib.lovetoys.lovetoys"

local BuildingCompletedEvent = require "src.game.buildingcompletedevent"
local WorkCompletedEvent = require "src.game.workcompletedevent"
local BuildingLeftEvent = require "src.game.buildingleftevent"
local BuildingComponent = require "src.game.buildingcomponent"
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
	-- Applies to both trees and rocks, at the moment.
	-- (45 seconds for 4 animations (1 cycle) with default 0.2 seconds for each animation)
	RESOURCE = 100 / (45 / (0.2 * 4)),
	BUILDING = {
		-- (2 minutes for 4 animations (1 cycle) with default 0.2 seconds for each animation)
		[BuildingComponent.DWELLING] = 100 / (120 / (0.2 * 4)),
		[BuildingComponent.BLACKSMITH] = 100 / (120 / (0.2 * 4)),
		-- (1 minute)
		[BuildingComponent.FIELD] = 100 / (60 / (0.2 * 4)),
		-- (4 minutes)
		[BuildingComponent.BAKERY] = 100 / (240 / (0.2 * 4))
	},
	PRODUCING = {
		-- Numbers are completion per second.
		-- (2 minutes)
		[BuildingComponent.BLACKSMITH] = 120 / 100,
		[BuildingComponent.BAKERY] = 120 / 100
	}
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
				local craftsmanship = villagerEntity:get("VillagerComponent"):getCraftsmanship()
				local durationModifier = 2^(2 - craftsmanship) / 2 -- TODO: Is this really what I want?
				local workType = entity:get("BuildingComponent"):getType()
				local increase = WorkSystem.COMPLETION.PRODUCING[workType] * durationModifier * dt

				production:increaseCompletion(villagerEntity, increase)

				local complete = production:isComplete(villagerEntity)
				if not complete and workType == BuildingComponent.BAKERY then
					-- Add a break in the middle of baking, for the yeast to take effect, no?
					local completion = production:getCompletion(villagerEntity)
					if completion >= 50.0 - increase/2 and completion < 50.0 + increase/2 then
						self.eventManager:fireEvent(BuildingLeftEvent(entity, villagerEntity))
						self.eventManager:fireEvent(WorkCompletedEvent(entity, villagerEntity, true))
					end
				elseif complete then
					production:reset(villagerEntity)
					villagerEntity:add(CarryingComponent(next(production:getOutput())))

					self.eventManager:fireEvent(BuildingLeftEvent(entity, villagerEntity))
					self.eventManager:fireEvent(WorkCompletedEvent(entity, villagerEntity, true))
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
		local construction = workPlace:get("ConstructionComponent")
		construction:commitResources(WorkSystem.COMPLETION.BUILDING[construction:getType()])

		soundManager:playEffect("building")

		if not construction:canBuild() then
			for _,worker in ipairs(workPlace:get("AssignmentComponent"):getAssignees()) do
				if construction:isComplete() then
					self.eventManager:fireEvent(WorkCompletedEvent(workPlace, worker))
				else
					if worker:has("WorkingComponent") and worker:get("WorkingComponent"):getWorking() then
						construction:unreserveGrid(worker)
						self.eventManager:fireEvent(WorkCompletedEvent(workPlace, worker, true))
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

		local particle
		local position = workPlace:get("PositionComponent")
		if work:getType() == WorkComponent.WOODCUTTER then
			particle = blueprint:createWoodSparksParticle()
			particle:get("SpriteComponent"):setDrawPosition(dx + 14, dy + 55) -- XXX
		elseif work:getType() == WorkComponent.MINER then
			particle = blueprint:createIronSparksParticle()
			particle:get("SpriteComponent"):setDrawPosition(dx + 12, dy + 5) -- XXX
		end
		particle:add(PositionComponent(position:getGrid(), nil, position:getTile()))
		self.engine:addEntity(particle)

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
