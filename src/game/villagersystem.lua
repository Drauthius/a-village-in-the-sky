local lovetoys = require "lib.lovetoys.lovetoys"

local CarryingComponent = require "src.game.carryingcomponent"
local TimerComponent = require "src.game.timercomponent"
local VillagerComponent = require "src.game.villagercomponent"
local WalkingComponent = require "src.game.walkingcomponent"
local WorkComponent = require "src.game.workcomponent"
local WorkingComponent = require "src.game.workingcomponent"

local blueprint = require "src.game.blueprint"
local state = require "src.game.state"

local VillagerSystem = lovetoys.System:subclass("VillagerSystem")

VillagerSystem.static.TIMERS = {
	PICKUP_BEFORE = 0.25,
	PICKUP_AFTER = 0.5,
	DROPOFF_BEFORE = 0.25,
	DROPOFF_AFTER = 0.5,
	IDLE_ROTATE_MIN = 1,
	IDLE_ROTATE_MAX = 4
}

function VillagerSystem.requires()
	return {"VillagerComponent"}
end

function VillagerSystem:initialize(engine, map)
	lovetoys.System.initialize(self)
	self.engine = engine
	self.map = map
end

function VillagerSystem:update(dt)
	for _,entity in pairs(self.targets) do
		self:_updateVillager(entity)
	end
end

function VillagerSystem:_updateVillager(entity)
	local villager = entity:get("VillagerComponent")
	local goal = villager:getGoal()

	if goal == VillagerComponent.GOALS.NONE then
		if entity:has("CarryingComponent") then
			assert(villager:getHome(), "TODO: No home!") -- TODO: Just drop it here

			-- Drop off at home.
			local home = villager:getHome()
			local grid = home:get("PositionComponent"):getPosition()
			local ti, tj = self.map:gridToTileCoords(grid.gi, grid.gj)

			entity:add(WalkingComponent(ti, tj, nil, WalkingComponent.INSTRUCTIONS.DROPOFF))
			villager:setGoal(VillagerComponent.GOALS.DROPOFF)
			-- Remove any lingering timer.
			if entity:has("TimerComponent") then
				entity:remove("TimerComponent")
			end
		elseif villager:getWorkPlace() then
			local workPlace = villager:getWorkPlace()
			local grid = workPlace:get("PositionComponent"):getPosition()
			local ti, tj = self.map:gridToTileCoords(grid.gi, grid.gj)

			entity:add(WorkingComponent())
			-- Remove any lingering timer.
			if entity:has("TimerComponent") then
				entity:remove("TimerComponent")
			end

			if villager:getOccupation() == WorkComponent.BUILDER then
				local construction = workPlace:get("ConstructionComponent")
				entity:add(WalkingComponent(ti, tj, construction:getFreeWorkGrids(), WalkingComponent.INSTRUCTIONS.BUILD))
				villager:setGoal(VillagerComponent.GOALS.WORK_PICKUP)
			else
				local workGrids = workPlace:get("WorkComponent"):getWorkGrids()
				assert(workGrids, "No grid information for workplace "..workPlace:get("WorkComponent"):getTypeName())

				-- The work grids are an offset, so translate them to real grid coordinates.
				local grids = {}
				for _,workGrid in ipairs(workGrids) do
					table.insert(grids, { self.map:getGrid(grid.gi + workGrid.ogi, grid.gj + workGrid.ogj), workGrid.rotation })
				end

				entity:add(WalkingComponent(ti, tj, grids, WalkingComponent.INSTRUCTIONS.WORK))
				villager:setGoal(VillagerComponent.GOALS.WORK)
			end
		else
			if not entity:has("TimerComponent") then
				local timer = TimerComponent()
				-- Fidget a little by rotating the villager.
				timer:getTimer():after(
					love.math.random() *
					(VillagerSystem.TIMERS.IDLE_ROTATE_MAX - VillagerSystem.TIMERS.IDLE_ROTATE_MIN) +
					VillagerSystem.TIMERS.IDLE_ROTATE_MIN, function()
						local dir = villager:getDirection()
						villager:setDirection((dir + 45 * love.math.random(-1, 1)) % 360)
						entity:remove("TimerComponent")
					end)
				entity:add(timer)
			end
		end
	end
end

function VillagerSystem:targetReachedEvent(event)
	local entity = event:getVillager()
	local villager = entity:get("VillagerComponent")
	local goal = villager:getGoal()
	local ti, tj = entity:get("WalkingComponent"):getTargetTile()

	if event:getRotation() then
		villager:setDirection(event:getRotation())
	end

	if goal == VillagerComponent.GOALS.DROPOFF then
		local timer = TimerComponent()
		timer:getTimer():after(VillagerSystem.TIMERS.DROPOFF_BEFORE, function()
			-- Stop carrying the stuff.
			local resource = entity:get("CarryingComponent"):getResource()
			local amount = entity:get("CarryingComponent"):getAmount()
			entity:remove("CarryingComponent")

			assert(event:getTarget(), "Nowhere to put the resource.")

			local resourceEntity = blueprint:createResourcePile(resource, amount)
			self.map:addResource(resourceEntity, event:getTarget())

			-- TODO: Set up the resource somewhere else.
			local gi, gj = event:getTarget().gi, event:getTarget().gj
			local ox, oy = self.map:gridToWorldCoords(gi, gj)
			ox = ox - self.map.halfGridWidth
			oy = oy - resourceEntity:get("SpriteComponent"):getSprite():getHeight() + self.map.gridHeight

			resourceEntity:get("SpriteComponent"):setDrawPosition(ox, oy)
			resourceEntity:get("PositionComponent"):setPosition(self.map:getGrid(gi, gj))

			self.engine:addEntity(resourceEntity)
			state:increaseResource(resource, amount)

			timer:getTimer():after(VillagerSystem.TIMERS.DROPOFF_AFTER, function()
				villager:setGoal(VillagerComponent.GOALS.NONE)
				entity:remove("TimerComponent")
			end)
		end)
		entity:add(timer)
	elseif goal == VillagerComponent.GOALS.WORK_PICKUP then
		local timer = TimerComponent()
		timer:getTimer():after(VillagerSystem.TIMERS.PICKUP_BEFORE, function()
			-- Start carrying the stuff.
			local resourceEntity = event:getTarget()
			local resource = resourceEntity:get("ResourceComponent")
			entity:add(CarryingComponent(resource:getResource(), resource:getReservedAmount()))
			resource:decreaseAmount(resource:getReservedAmount())

			if resource:getResourceAmount() < 1 then
				-- Remove it from the engine.
				self.engine:removeEntity(resourceEntity, true)
			else
				-- Sprite component needs to be updated.
				resourceEntity:get("SpriteComponent"):setNeedsRefresh(true)
				resource:setReserved(nil)
			end

			assert(event:getNextStop(), "Nowhere to put the resource.")

			timer:getTimer():after(VillagerSystem.TIMERS.PICKUP_AFTER, function()
				-- Go next.
				entity:add(WalkingComponent(ti, tj, { event:getNextStop() }, WalkingComponent.INSTRUCTIONS.WORK))
				villager:setGoal(VillagerComponent.GOALS.WORK)

				entity:remove("TimerComponent")
			end)
		end)
		entity:add(timer)
	elseif goal == VillagerComponent.GOALS.WORK then
		-- Start working
		entity:get("WorkingComponent"):setWorking(true)

		if entity:has("CarryingComponent") then
			local resource = entity:get("CarryingComponent"):getResource()
			local amount = entity:get("CarryingComponent"):getAmount()
			state:removeReservedResource(resource, amount)
			state:decreaseResource(resource, amount)
			villager:getWorkPlace():get("ConstructionComponent"):addResources(resource, amount)
			entity:remove("CarryingComponent")
		end
	end
end

return VillagerSystem
