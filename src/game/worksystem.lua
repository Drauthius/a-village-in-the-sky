local Timer = require "lib.hump.timer"
local lovetoys = require "lib.lovetoys.lovetoys"

local BuildingComponent = require "src.game.buildingcomponent"
local CarryingComponent = require "src.game.carryingcomponent"
local DwellingComponent = require "src.game.dwellingcomponent"
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

-- TODO: Currently handles both Work and Construction
function WorkSystem.requires()
	return {"WorkComponent"}
end

function WorkSystem:initialize(engine)
	lovetoys.System.initialize(self)

	self.engine = engine
end

function WorkSystem:update(dt)
	--[[
	for _,entity in pairs(self.targets) do
		local work = entity:get("WorkComponent")
		if entity:has("ConstructionComponent") then
		elseif work:isComplete() then
		end
	end
	--]]
end

function WorkSystem:workEvent(event)
	local entity = event:getVillager()
	local workPlace = event:getWorkPlace()
	local cardinalDir = entity:get("VillagerComponent"):getCardinalDirection()

	local shake = 2
	local workSprite = workPlace:get("SpriteComponent")
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
			local workers = construction:getAssignedVillagers()

			for _,worker in ipairs(workers) do
				local adult = worker:get("AdultComponent")
				if construction:isComplete() then
					adult:setWorkPlace(nil)
					worker:remove("WorkingComponent")
					entity:get("VillagerComponent"):setGoal(VillagerComponent.GOALS.NONE)
				else
					if worker:has("WorkingComponent") and worker:get("WorkingComponent"):getWorking() then
						construction:unreserveGrid(worker)
						worker:remove("WorkingComponent")
						entity:get("VillagerComponent"):setGoal(VillagerComponent.GOALS.NONE)
					end
				end
			end

			if construction:isComplete() then
				workPlace:remove("ConstructionComponent")
				soundManager:playEffect("buildingComplete")

				-- TODO: Maybe send this off in an event.
				if construction:getType() == BuildingComponent.DWELLING then
					workPlace:add(DwellingComponent())
				end
			end
		end
	else
		local work = workPlace:get("WorkComponent")
		work:increaseCompletion(10.0) -- TODO: Value!

		local workers = work:getAssignedVillagers()
		local numWorkers = #workers

		-- TODO: Maybe send this off in an event.
		if work:isComplete() then
			if work:getType() == WorkComponent.WOODCUTTER or
			   work:getType() == WorkComponent.MINER then
				for _,worker in ipairs(workers) do
					local adult = worker:get("AdultComponent")
					worker:remove("WorkingComponent")
					adult:setWorkPlace(nil)
					adult:setGoal(VillagerComponent.GOALS.NONE)
				end

				local resource = workPlace:get("ResourceComponent")
				if numWorkers == 0 then
					-- TODO: Place on ground!
					print("Unimplemented drop")
				elseif numWorkers == 1 then
					workers[1]:add(CarryingComponent(resource:getResource(), resource:getResourceAmount()))
				else
					error("Too many workers for resource type")
				end

				soundManager:playEffect(ResourceComponent.RESOURCE_NAME[resource:getResource()].."Gathered")

				self.engine:removeEntity(workPlace, true)
			else
				error("TODO: Non-gathering work complete.")
			end
		else
			soundManager:playEffect(WorkComponent.WORK_NAME[work:getType()].."Working")
		end
	end
end

return WorkSystem
