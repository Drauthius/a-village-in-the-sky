local lovetoys = require "lib.lovetoys.lovetoys"
local table = require "lib.table"

local CarryingComponent = require "src.game.carryingcomponent"
local PositionComponent = require "src.game.positioncomponent"
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
	IDLE_ROTATE_MAX = 4,
	PATH_FAILED_DELAY = 3,
	PATH_WAIT_DELAY = 2,
	NO_RESOURCE_DELAY = 5,
	FARM_WAIT = 5
}

VillagerSystem.static.RAND = {
	WANDER_FORWARD_CHANCE = 0.2,
	CHILD_DOUBLE_FORWARD_CHANCE = 0.5,
	MOVE_DOUBLE_FORWARD_CHANCE = 0.8
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
	local adult = entity:has("AdultComponent") and entity:get("AdultComponent")
	local goal = villager:getGoal()

	if goal == VillagerComponent.GOALS.NONE then
		if entity:has("CarryingComponent") then
			local home = villager:getHome()
			local ti, tj

			self:_prepare(entity)

			if home then
				-- Drop off at home.
				ti, tj = home:get("PositionComponent"):getTile()
			else
				-- Drop off somewhere around here.
				local grid = entity:get("PositionComponent"):getGrid()
				ti, tj = self.map:gridToTileCoords(grid.gi, grid.gj)
			end

			entity:add(WalkingComponent(ti, tj, nil, WalkingComponent.INSTRUCTIONS.DROPOFF))
			villager:setGoal(VillagerComponent.GOALS.DROPOFF)
		elseif adult and adult:getWorkPlace() then
			local workPlace = adult:getWorkPlace()
			local ti, tj = workPlace:get("PositionComponent"):getTile()

			self:_prepare(entity)

			if workPlace:has("ConstructionComponent") then
				local construction = workPlace:get("ConstructionComponent")

				-- Make a first pass to determine if any work can be carried out.
				-- TODO: Builders should work on buildings that can be completed.
				local blacklist, resource = {}
				repeat
					resource = construction:getRemainingResources(blacklist)
					if not resource then
						adult:setWorkPlace(nil)
						return
					end

					-- Don't count that resource again, in case we go round again.
					blacklist[resource] = true
				until state:getNumResources(resource) - state:getNumReservedResources(resource) > 0

				-- For things being built, update the places where builders can stand, so that rubbish can
				-- be cleared around the build site after placing the building.
				construction:updateWorkGrids(self.map:getAdjacentGrids(workPlace))

				entity:add(WalkingComponent(ti, tj, construction:getFreeWorkGrids(), WalkingComponent.INSTRUCTIONS.BUILD))
				villager:setGoal(VillagerComponent.GOALS.WORK_PICKUP)
			elseif workPlace:has("ProductionComponent") then
				local production = workPlace:get("ProductionComponent")

				-- Make a first pass to determine if any work can be carried out.
				local blacklist, resource = {}
				repeat
					resource = production:getNeededResources(entity, blacklist)
					if not resource then
						villager:setGoal(VillagerComponent.GOALS.WAIT)
						print(entity, "Timer: NO RESOURCE")
						entity:add(TimerComponent(VillagerSystem.TIMERS.NO_RESOURCE_DELAY, function()
							villager:setGoal(VillagerComponent.GOALS.NONE)
							entity:remove("TimerComponent")
						end))
						return
					end

					-- Don't count that resource again, in case we go round again.
					blacklist[resource] = true
				until state:getNumResources(resource) - state:getNumReservedResources(resource) > 0

				-- The entrance is an offset, so translate it to a real grid coordinate.
				local entrance = production:getEntrance()
				local grid = workPlace:get("PositionComponent"):getGrid()
				local entranceGrid = self.map:getGrid(grid.gi + entrance.ogi, grid.gj + entrance.ogj)

				entity:add(WalkingComponent(ti, tj, { entranceGrid }, WalkingComponent.INSTRUCTIONS.PRODUCE))
				villager:setGoal(VillagerComponent.GOALS.WORK_PICKUP)
			else
				local workGrids
				if workPlace:has("FieldComponent") then
					workGrids = workPlace:get("FieldComponent"):getWorkGrids(entity)
					if not workGrids then
						-- Nothing to do at the moment, try again later.
						villager:setGoal(VillagerComponent.GOALS.WAIT)
						print(entity, "Timer: FARM WAIT")
						entity:add(TimerComponent(VillagerSystem.TIMERS.FARM_WAIT, function()
							villager:setGoal(VillagerComponent.GOALS.NONE)
							entity:remove("TimerComponent")
						end))
						return
					end
				else
					workGrids = workPlace:get("WorkComponent"):getWorkGrids()
					assert(workGrids, "No grid information for workplace "..workPlace:get("WorkComponent"):getTypeName())
				end

				-- The work grids are an offset, so translate them to real grid coordinates.
				local grid = workPlace:get("PositionComponent"):getGrid()
				local grids = {}
				for _,workGrid in ipairs(workGrids) do
					table.insert(grids, { self.map:getGrid(grid.gi + workGrid.ogi, grid.gj + workGrid.ogj), workGrid.rotation })
				end

				entity:add(WalkingComponent(ti, tj, grids, WalkingComponent.INSTRUCTIONS.WORK))
				villager:setGoal(VillagerComponent.GOALS.WORK)
			end

			entity:add(WorkingComponent())
		elseif adult and adult:getWorkArea() and
		       (adult:getOccupation() == WorkComponent.WOODCUTTER or
		        adult:getOccupation() == WorkComponent.MINER) then
			-- This could be optimized through the map or something, but eh.
			local ti, tj = adult:getWorkArea()
			for _,workEntity in pairs(self.engine:getEntitiesWithComponent("WorkComponent")) do
				local assignment = workEntity:get("AssignmentComponent")
				local eti, etj = workEntity:get("PositionComponent"):getTile()
				if ti == eti and tj == etj and workEntity:get("WorkComponent"):getType() == adult:getOccupation() and
				   assignment:getNumAssignees() < assignment:getMaxAssignees() then
					assignment:assign(entity)
					adult:setWorkPlace(workEntity)
					return -- Start working the next round.
				end
			end

			-- No such entity found. No work able to be carried out.
			adult:setWorkArea(nil)
		else
			if not entity:has("TimerComponent") and not entity:has("WalkingComponent") then
				-- Fidget a little by rotating the villager.
				entity:add(TimerComponent(
					love.math.random() *
					(VillagerSystem.TIMERS.IDLE_ROTATE_MAX - VillagerSystem.TIMERS.IDLE_ROTATE_MIN) +
					VillagerSystem.TIMERS.IDLE_ROTATE_MIN, function()
						local dir = villager:getDirection()
						villager:setDirection((dir + 45 * love.math.random(-1, 1)) % 360)
						entity:remove("TimerComponent")

						if love.math.random() < VillagerSystem.RAND.WANDER_FORWARD_CHANCE then
							-- XXX:
							local WorkSystem = require "src.game.worksystem"
							local dirConv = WorkSystem.DIR_CONV[villager:getCardinalDirection()]
							local grid = entity:get("PositionComponent"):getGrid()
							local target = self.map:getGrid(grid.gi + dirConv[1], grid.gj + dirConv[2])
							if target then
								if not adult and love.math.random() < VillagerSystem.RAND.CHILD_DOUBLE_FORWARD_CHANCE then
									target = self.map:getGrid(target.gi + dirConv[1], target.gj + dirConv[2]) or target
								end
								entity:add(WalkingComponent(nil, nil, { target }, WalkingComponent.INSTRUCTIONS.WANDER))
							end
						end
					end)
				)
			end
		end
	end
end

function VillagerSystem:_prepare(entity)
	-- Remove any lingering timer.
	if entity:has("TimerComponent") then
		entity:remove("TimerComponent")
	end

	-- Unreserve any reserved grids.
	if entity:has("WalkingComponent") then
		if entity:get("WalkingComponent"):getNextGrid() then
			self.map:unreserve(entity, entity:get("WalkingComponent"):getNextGrid())
		end
		entity:remove("WalkingComponent")
	end
end

function VillagerSystem:_unreserveAll(entity)
	local workPlace = entity:get("AdultComponent"):getWorkPlace()

	local type, amount
	for _,resourceEntity in pairs(self.engine:getEntitiesWithComponent("ResourceComponent")) do
		local resource = resourceEntity:get("ResourceComponent")
		if resource:getReservedBy() == entity then
			type, amount = resource:getResource(), resource:getReservedAmount()
			state:removeReservedResource(type, amount)
			resource:setReserved(nil)
			break -- Should only have one
		end
	end

	-- TODO: Maybe send it off as an event?
	if workPlace then
		workPlace:get("AssignmentComponent"):unassign(entity)

		if workPlace:has("ConstructionComponent") then
			workPlace:get("ConstructionComponent"):unreserveGrid(entity)

			if not type and entity:has("CarryingComponent") then
				type, amount = entity:get("CarryingComponent"):getResource(), entity:get("CarryingComponent"):getAmount()
			end

			if type and amount then
				workPlace:get("ConstructionComponent"):unreserveResource(type, amount)
			end
		elseif workPlace:has("FieldComponent") then
			workPlace:get("FieldComponent"):unreserve(entity)
		elseif not workPlace:has("WorkComponent") then
			error("Unknown work place")
		end
	end

	if entity:has("WorkingComponent") then
		entity:remove("WorkingComponent")
	end
end

--
-- Events
--

function VillagerSystem:assignedEvent(event)
	local entity = event:getAssignee()
	local site = event:getAssigner()
	local adult = entity:get("AdultComponent")
	local villager = entity:get("VillagerComponent")

	if site:has("DwellingComponent") then
		villager:setHome(site)
	else
		local workPlace = adult:getWorkPlace()

		if workPlace == site then
			-- If already working there, then nothing needs to be done.
			return
		end

		self:_unreserveAll(entity)
		self:_prepare(entity)
		villager:setGoal(VillagerComponent.GOALS.NONE)

		adult:setWorkArea(site:get("PositionComponent"):getTile())

		-- The villager might be assigned to the same work area, but not the same work site.
		if site:get("AssignmentComponent"):isAssigned(entity) then
			adult:setWorkPlace(site)
		end

		-- Guess the occupation!
		if site:has("ConstructionComponent") then
			adult:setOccupation(WorkComponent.BUILDER)
		elseif site:has("WorkComponent") then
			adult:setOccupation(site:get("WorkComponent"):getType())
		elseif site:has("ProductionComponent") then
			adult:setOccupation(WorkComponent.BLACKSMITH) -- TODO!
		elseif site:has("FieldComponent") then
			adult:setOccupation(WorkComponent.FARMER)
		else
			error("I give up :(")
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

	if entity:has("TimerComponent") then
		entity:remove("TimerComponent")
	end

	if goal == VillagerComponent.GOALS.DROPOFF then
		local grid = event:getTarget()
		assert(grid, "Nowhere to put the resource.")

		-- Check if someone beat us to the grid.
		if not self.map:isGridEmpty(grid) then
			-- The default action will make sure we drop it somewhere else.
			villager:setGoal(VillagerComponent.GOALS.NONE)
			return
		end

		local timer = TimerComponent()
		print(entity, "Timer: DROPOFF")
		timer:getTimer():after(VillagerSystem.TIMERS.DROPOFF_BEFORE, function()
			-- Stop carrying the stuff.
			local resource = entity:get("CarryingComponent"):getResource()
			local amount = entity:get("CarryingComponent"):getAmount()
			entity:remove("CarryingComponent")

			local resourceEntity = blueprint:createResourcePile(resource, amount)
			self.map:addResource(resourceEntity, grid)

			-- TODO: Set up the resource somewhere else.
			local gi, gj = grid.gi, grid.gj
			local ox, oy = self.map:gridToWorldCoords(gi, gj)
			ox = ox - self.map.halfGridWidth
			oy = oy - resourceEntity:get("SpriteComponent"):getSprite():getHeight() + self.map.gridHeight

			resourceEntity:get("SpriteComponent"):setDrawPosition(ox, oy)
			resourceEntity:add(PositionComponent(self.map:getGrid(gi, gj), nil, self.map:gridToTileCoords(gi, gj)))

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
		print(entity, "Timer: PICKUP")
		timer:getTimer():after(VillagerSystem.TIMERS.PICKUP_BEFORE, function()
			assert(event:getNextStop(), "Nowhere to put the resource.")

			-- Start carrying the stuff.
			local resourceEntity = event:getTarget()
			local resource = resourceEntity:get("ResourceComponent")
			local type, amount = resource:getResource(), resource:getReservedAmount()
			entity:add(CarryingComponent(type, amount))
			resource:decreaseAmount(amount)

			if resource:getResourceAmount() < 1 then
				-- Remove it from the engine.
				self.engine:removeEntity(resourceEntity, true)
			else
				-- Sprite component needs to be updated.
				resourceEntity:get("SpriteComponent"):setNeedsRefresh(true)
				resource:setReserved(nil)
			end

			-- Update the state here, since dropping it off anywhere will increase the counter again.
			state:removeReservedResource(type, amount)
			state:decreaseResource(type, amount)

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
			local workPlace = entity:get("AdultComponent"):getWorkPlace()

			if workPlace:has("ConstructionComponent") then
				workPlace:get("ConstructionComponent"):addResources(resource, amount)
			elseif workPlace:has("ProductionComponent") then
				local production = workPlace:get("ProductionComponent")
				production:addResource(resource, amount)
				production:reserveResource(entity, resource, amount)

				if production:getNeededResources(entity) then
					-- There still are resources needed. Might as well circle back.
					entity:remove("WorkingComponent")
					villager:setGoal(VillagerComponent.GOALS.NONE)
				else
					-- Enter the building!
					self.map:unreserve(entity, entity:get("PositionComponent"):getGrid())
					entity:remove("SpriteComponent")
					entity:remove("PositionComponent")
					entity:remove("InteractiveComponent")
				end
			else
				error("Carried resources to unknown workplace.")
			end

			entity:remove("CarryingComponent")
		end
	elseif goal == VillagerComponent.GOALS.MOVING then
		villager:setGoal(VillagerComponent.GOALS.WAIT)
		entity:add(TimerComponent(VillagerSystem.TIMERS.PATH_WAIT_DELAY, function()
			villager:setGoal(VillagerComponent.GOALS.NONE)
			entity:remove("TimerComponent")
		end))
	end
end

function VillagerSystem:targetUnreachableEvent(event)
	local entity = event:getVillager()

	-- If wandering about, don't do anything.
	if event:getInstructions() == WalkingComponent.INSTRUCTIONS.WANDER then
		event:setRetry(false)
		return
	end

	local blocking = event:getBlocking()
	local villager = entity:get("VillagerComponent")

	if blocking and blocking:has("VillagerComponent") then
		local blockingVillager = blocking:get("VillagerComponent")
		local goal = blockingVillager:getGoal()
		local isBusy = goal ~= VillagerComponent.GOALS.NONE and goal ~= VillagerComponent.GOALS.WAIT
		local isTemporary = goal == VillagerComponent.GOALS.DROPOFF or goal == VillagerComponent.GOALS.WORK_PICKUP or
		                    goal == VillagerComponent.GOALS.MOVING or blocking:has("WalkingComponent")
		-- TODO: Look for deadlock amongst villagers (two villagers heading in the opposite directions).
		--       This could be resolved by temporarily allowing collision.

		-- If the blocking villager is not busy, then send them away.
		if not isBusy and not isTemporary then
			-- Remove any current path or timer.
			self:_prepare(blocking)
			print(blocking, "Blocking villager goal: ", goal, "->", VillagerComponent.GOALS.MOVING)
			blockingVillager:setGoal(VillagerComponent.GOALS.MOVING)

			local walkable = {}
			local here, there = entity:get("PositionComponent"):getGrid(), blocking:get("PositionComponent"):getGrid()
			-- Go to a random walkable direction that is not here.
			-- Not sure this randomness does anything...
			for _,gi in ipairs(table.shuffle({ -1, 0, 1 })) do
				for _,gj in ipairs(table.shuffle({ -1, 0, 1 })) do
					local grid = self.map:getGrid(there.gi + gi, there.gj + gj)
					if grid and grid ~= here and grid ~= there then
						-- Prioritise empty grids.
						if self.map:isGridEmpty(grid) then
							-- Maybe take two steps.
							if love.math.random() < VillagerSystem.RAND.MOVE_DOUBLE_FORWARD_CHANCE then
								local newGrid = self.map:getGrid(grid.gi + gi, grid.gj + gj)
								grid = (newGrid and self.map:isGridEmpty(newGrid)) and newGrid or grid
							end
							table.insert(walkable, 1, grid)
						elseif self.map:isGridWalkable(grid) then
							table.insert(walkable, grid)
						end
					end
				end
			end

			if next(walkable) then
				local grid
				-- Try to pick a grid that isn't directly in the way.
				local path = entity:get("WalkingComponent"):getPath()
				local pathLen = #path
				for _,g in ipairs(walkable) do
					if g ~= path[pathLen] then
						grid = g
						break
					end
				end
				blocking:add(WalkingComponent(nil, nil, { grid or walkable[1] }, WalkingComponent.INSTRUCTIONS.GET_OUT_THE_WAY))
				print(entity, "Blocking villager sent away")
				isTemporary = true
			else
				print(entity, "Blocking villager is blocked.")
			end
		end

		if isTemporary then
			-- Make sure the walking component is removed.
			event:setRetry(false)

			-- Since the walking component will be removed, we save it away and re-add it later.
			local walking = table.clone(entity:get("WalkingComponent"))
			-- Wait a second and try the exact same thing again.
			print(entity, "Timer: PATH WAIT")
			entity:set(TimerComponent(VillagerSystem.TIMERS.PATH_WAIT_DELAY, function()
				--self:_prepare(entity)
				local newWalking = WalkingComponent()
				for k,v in pairs(walking) do
					newWalking[k] = v
				end
				entity:add(newWalking)
				entity:remove("TimerComponent")
			end))

			print(entity, "Blocked but waiting")
			return
		end

		if not isBusy then
			print(entity, "Blocked by a blocked villager")
		elseif isBusy then
			print(entity, "Blocked by a busy villager")
		end
	else
		print(entity, "Blocked by a non-villager")
	end

	if event:shouldRetry() then
		-- Let the walking system try to find a new path.
		return
	end

	print(entity, "Unreachable!")

	-- Start by unreserving everything
	self:_unreserveAll(entity)

	villager:setGoal(VillagerComponent.GOALS.WAIT)
	print(entity, "Timer: PATH FAILED")
	entity:set(TimerComponent(VillagerSystem.TIMERS.PATH_FAILED_DELAY, function()
		villager:setGoal(VillagerComponent.GOALS.NONE)
		entity:remove("TimerComponent")
	end))
end

return VillagerSystem
