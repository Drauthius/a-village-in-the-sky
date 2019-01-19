local Timer = require "lib.hump.timer"
local lovetoys = require "lib.lovetoys.lovetoys"

local VillagerComponent = require "src.game.villagercomponent"
local WorkComponent = require "src.game.workcomponent"

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

-- TODO: Currently handles both Work and UnderConstruction
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
		if entity:has("UnderConstructionComponent") then
		elseif work:isComplete() then
		end
	end
	--]]
end

function WorkSystem:workEvent(event)
	local villager = event:getVillager()
	local workPlace = event:getWorkPlace()
	local cardinalDir = villager:get("VillagerComponent"):getCardinalDirection()

	local shake = 2
	local workSprite = workPlace:get("SpriteComponent")
	local dx, dy = workSprite.x, workSprite.y
	workSprite.x = workSprite.x + WorkSystem.DIR_CONV[cardinalDir][1] * shake
	workSprite.y = workSprite.y + WorkSystem.DIR_CONV[cardinalDir][2] * shake
	Timer.tween(0.12, workSprite, { x = dx, y = dy }, "in-bounce")

	if workPlace:has("UnderConstructionComponent") then
		local crafts = villager:get("VillagerComponent"):getCraftsmanship()

		local uuc = workPlace:get("UnderConstructionComponent")
		uuc:commitResources(crafts * 1) -- TODO: Value

		if not uuc:canBuild() then
			local workers = uuc:getAssignedVillagers()

			for _,worker in ipairs(workers) do
				villager = worker:get("VillagerComponent")
				if uuc:isComplete() then
					villager:setWorkPlace(nil)
					villager:setState(VillagerComponent.states.IDLE) -- TODO: Should be WORKING
				else
					if villager:getAction() == VillagerComponent.actions.WORKING then
						uuc:unreserveGrid(worker)
						villager:setState(VillagerComponent.states.IDLE) -- TODO: Should be WORKING
					end
				end
			end

			if uuc:isComplete() then
				workPlace:remove("UnderConstructionComponent")
				-- TODO: More?
			end
		end
	else
		local work = workPlace:get("WorkComponent")
		work:get("WorkComponent"):increaseCompletion(10.0) -- TODO: Value!

		local workers = work:getAssignedVillagers()
		local numWorkers = #workers

		if work:getType() == WorkComponent.WOODCUTTER or
		   work:getType() == WorkComponent.MINER then
			for _,worker in ipairs(workers) do
				villager = worker:get("VillagerComponent")
				villager:setWorkPlace(nil)
				villager:setState(VillagerComponent.states.IDLE) -- TODO: Should be WORKING
			end

			if numWorkers == 0 then
				-- TODO: Place on ground!
				print("Unimplemented drop")
			elseif numWorkers == 1 then
				workers[1]:get("VillagerComponent"):carry(
					workPlace:get("ResourceComponent"):getResourceAmount(),
					workPlace:get("ResourceComponent"):getResource())
			else
				error("Too many workers for resource type")
			end

			self.engine:removeEntity(workPlace, true)
		else
			error("TODO: Non-gathering work complete.")
		end
	end
end

return WorkSystem
