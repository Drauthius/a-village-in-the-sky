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

local lovetoys = require "lib.lovetoys.lovetoys"
local math = require "lib.math"
local table = require "lib.table"

local AssignedEvent = require "src.game.assignedevent"
local BuildingEnteredEvent = require "src.game.buildingenteredevent"
local BuildingLeftEvent = require "src.game.buildingleftevent"
local ChildbirthStartedEvent = require "src.game.childbirthstartedevent"
local ResourceDepletedEvent = require "src.game.resourcedepletedevent"
local UnassignedEvent = require "src.game.unassignedevent"
local VillagerAgedEvent = require "src.game.villageragedevent"
local VillagerDeathEvent = require "src.game.villagerdeathevent"
local VillagerMaturedEvent = require "src.game.villagermaturedevent"

local AdultComponent = require "src.game.adultcomponent"
local BuildingComponent = require "src.game.buildingcomponent"
local CarryingComponent = require "src.game.carryingcomponent"
local FertilityComponent = require "src.game.fertilitycomponent"
local GroundComponent = require "src.game.groundcomponent"
local PositionComponent = require "src.game.positioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local SeniorComponent = require "src.game.seniorcomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TimerComponent = require "src.game.timercomponent"
local VillagerComponent = require "src.game.villagercomponent"
local WalkingComponent = require "src.game.walkingcomponent"
local WorkComponent = require "src.game.workcomponent"
local WorkingComponent = require "src.game.workingcomponent"

local blueprint = require "src.game.blueprint"
local soundManager = require "src.soundmanager"
local state = require "src.game.state"

local VillagerSystem = lovetoys.System:subclass("VillagerSystem")

VillagerSystem.static.TIMERS = {
	MIN_DELAY = 0.25,
	PICKUP_BEFORE = 0.25,
	PICKUP_AFTER = 0.35,
	DROPOFF_BEFORE = 0.25,
	DROPOFF_AFTER = 0.35,
	IDLE_FIDGET_MIN = 1,
	IDLE_FIDGET_MAX = 4,
	PATH_FAILED_DELAY = 3,
	PATH_WAIT_DELAY = 2,
	NO_RESOURCE_DELAY = 5,
	CHILDBIRTH_NO_HOME_DELAY = 3,
	FARM_WAIT = 5,
	ASSIGNED_DELAY = 0.4,
	BUILDING_LEFT_DELAY = 0.25,
	BUILDING_TEMP_ENTER = 0.25,
	WORK_COMPLETED_DELAY = 1.0,
	CHILDBIRTH_RECOVERY_DELAY = (1/12) * TimerComponent.YEARS_TO_SECONDS
}

VillagerSystem.static.RAND = {
	WANDER_FORWARD_CHANCE = 0.2,
	CHILD_DOUBLE_FORWARD_CHANCE = 0.5,
	MOVE_DOUBLE_FORWARD_CHANCE = 0.8
}

VillagerSystem.static.FOOD = {
	-- Get food when the dwelling has less bread than this amount.
	GATHER_WHEN_BELOW = 0.5,
	-- 10 minutes to gain 100% hunger.
	HUNGER_PER_SECOND = 1 / 600,
	-- 2 minutes to gain 100% starvation (once hunger has reached its limit).
	STARVATION_PER_SECOND = 1 / 120,
	-- Eat breakfast (after sleeping) when hunger is above this amount.
	BREAKFAST_WHEN_ABOVE = 0.55,
	-- Tries to get some food if not doing anything else when hunger is above this amount.
	EAT_WHEN_ABOVE = 0.80,
	-- When eating: 20 seconds to get rid of 100% hunger
	LOSS_PER_SECOND = 1 / 20
}

VillagerSystem.static.SLEEP = {
	-- When idle: 120 seconds to gain 100% sleepiness.
	IDLE_GAIN_PER_SECOND = 1 / 120,
	-- When sleeping: 45 seconds to get rid of 100% sleepiness.
	LOSS_PER_SECOND = 1 / 45,
	-- When the villager should try and get some shut-eye.
	SLEEPINESS_THRESHOLD = 0.80
}

-- When the babies reach childhood, and can start going out.
VillagerSystem.static.CHILDHOOD = 5
-- When the children reach adulthood, and can start working.
VillagerSystem.static.ADULTHOOD = 14
-- When the adults reach seniorhood, and work/walk slower.
VillagerSystem.static.SENIORHOOD = 55
-- The chance to die of old age, accumulated per year after reaching seniorhood.
VillagerSystem.static.DEATH_CHANCE = 0.005

-- How far away, in grids, to try and move when standing on a reserved grid.
VillagerSystem.static.RESERVE_GRID_DISTANCE = 3

function VillagerSystem.requires()
	return {"VillagerComponent"}
end

function VillagerSystem:initialize(engine, eventManager, map)
	lovetoys.System.initialize(self)
	self.engine = engine
	self.eventManager = eventManager
	self.map = map
end

function VillagerSystem:update(dt)
	for _,entity in pairs(self.targets) do
		self:_update(entity, dt)
	end
end

function VillagerSystem:_update(entity, dt)
	local villager = entity:get("VillagerComponent")
	local age = villager:getAge()
	local goal = villager:getGoal()

	if villager:getDelay() > 0.0 then
		villager:decreaseDelay(dt)
	end

	if not state:isTimeStopped() then
		-- Increase age.
		villager:increaseAge(TimerComponent.YEARS_PER_SECOND * dt)
		if math.floor(age) ~= math.floor(villager:getAge()) then
			-- Happy birthday!
			self.eventManager:fireEvent(VillagerAgedEvent(entity))
			age = villager:getAge()
		end

		-- Increase hunger if not eating (and not an infant).
		if goal ~= VillagerComponent.GOALS.EATING and age >= VillagerSystem.CHILDHOOD then
			local hunger = math.min(1.0, villager:getHunger() + VillagerSystem.FOOD.HUNGER_PER_SECOND * dt)
			villager:setHunger(hunger)
			-- Don't starve a mother giving birth, for nicety reasons.
			if hunger >= 1.0 and goal ~= VillagerComponent.GOALS.CHILDBIRTH then
				local starvation = math.min(1.0, villager:getStarvation() + VillagerSystem.FOOD.STARVATION_PER_SECOND * dt)
				villager:setStarvation(starvation)
				if starvation >= 1.0 then
					self.eventManager:fireEvent(VillagerDeathEvent(entity, VillagerDeathEvent.REASONS.STARVATION))
					self.engine:removeEntity(entity, true)
					return
				end

				if villager:getHome() and
				   goal ~= VillagerComponent.GOALS.NONE and
				   goal ~= VillagerComponent.GOALS.FOOD_PICKUP and
				   goal ~= VillagerComponent.GOALS.FOOD_PICKING_UP and
				   goal ~= VillagerComponent.GOALS.FOOD_DROPOFF and
				   goal ~= VillagerComponent.GOALS.SLEEP and
				   goal ~= VillagerComponent.GOALS.SLEEPING and
				   goal ~= VillagerComponent.GOALS.EAT and
				   goal ~= VillagerComponent.GOALS.EATING then
					-- Villager needs to eat. Drop what yer doing.
					self:_stopAll(entity)
					self:_prepare(entity, true)
				end
			end
		end

		-- Increase sleepiness if not sleeping.
		if goal ~= VillagerComponent.GOALS.SLEEPING then
			local sleepiness = math.min(1.0, villager:getSleepiness() + VillagerSystem.SLEEP.IDLE_GAIN_PER_SECOND * dt)
			villager:setSleepiness(sleepiness)
		end
	end

	if goal == VillagerComponent.GOALS.EATING then
		if villager:isHome() then -- Home might have been destroyed.
			if villager:getDelay() > 0.0 then
				-- Decrease the hunger.
				villager:setHunger(math.max(0.0, villager:getHunger() - VillagerSystem.FOOD.LOSS_PER_SECOND * dt))
				return
			end
		end

		villager:setGoal(VillagerComponent.GOALS.NONE)
		villager:setDelay(0.0)
	elseif goal == VillagerComponent.GOALS.SLEEPING then
		if villager:isHome() then -- Home might have been destroyed.
			if villager:getDelay() > 0.0 then
				-- Decrease the sleepiness.
				villager:setSleepiness(math.max(0.0, villager:getSleepiness() - VillagerSystem.SLEEP.LOSS_PER_SECOND * dt))
				return
			end
		end

		villager:setGoal(VillagerComponent.GOALS.NONE)
		villager:setDelay(0.0)
	elseif goal == VillagerComponent.GOALS.DROPPING_OFF then
		if villager:getDelay() <= 0.0 then
			local grid = villager:getTargetGrid()
			-- Second take that the grid is still empty...
			if self.map:isGridEmpty(grid) then
				-- Stop carrying the stuff.
				self:_dropCarrying(entity, grid)
				villager:setDelay(VillagerSystem.TIMERS.DROPOFF_AFTER)
			--else
				-- The default action will make sure we drop it somewhere else.
			end

			villager:setTargetGrid(nil)
			villager:setGoal(VillagerComponent.GOALS.NONE)
		end
	elseif goal == VillagerComponent.GOALS.FOOD_PICKING_UP or
	       goal == VillagerComponent.GOALS.WORK_PICKING_UP then
		if villager:getDelay() <= 0.0 then
			-- Start carrying the stuff.
			local resourceEntity = villager:getTargetEntity()
			local resource = resourceEntity:get("ResourceComponent")
			local res, amount = resource:getResource(), resource:getReservedAmount()
			entity:add(CarryingComponent(res, amount))
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
			state:removeReservedResource(res, amount)
			state:decreaseResource(res, amount)
			villager:setTargetEntity(nil)
			villager:setDelay(VillagerSystem.TIMERS.PICKUP_AFTER + 1.0) -- Just something

			local grid = villager:getTargetGrid()
			entity:add(TimerComponent(VillagerSystem.TIMERS.PICKUP_AFTER,
				{ entity,
				  goal,
				  self.map:gridToTileCoords(grid.gi, grid.gj) }, function(data)
				local ent = data[1]
				local vill = ent:get("VillagerComponent")
				local targetGrid = vill:getTargetGrid()
				local targetRotation = vill:getTargetRotation()
				local ti, tj = data[3], data[4]

				local VillComp = require "src.game.villagercomponent"
				local WalkComp = require "src.game.walkingcomponent"

				-- Go next.
				if data[2] == VillComp.GOALS.WORK_PICKING_UP then
					ent:add(WalkComp(ti, tj, { { targetGrid, targetRotation, ent } }, WalkComp.INSTRUCTIONS.WORK))
					vill:setGoal(VillComp.GOALS.WORK)
				else
					ent:add(WalkComp(ti, tj, { targetGrid }, WalkComp.INSTRUCTIONS.GO_HOME))
					vill:setGoal(VillComp.GOALS.FOOD_DROPOFF)
				end

				vill:setTargetGrid(nil)
				vill:setTargetRotation(nil)
				vill:setDelay(0.0)
				ent:remove("TimerComponent")
			end))
		end
	elseif goal == VillagerComponent.GOALS.NONE then
		if villager:getDelay() > 0.0 then
			if not villager:isHome() and
			   villager:getDelay() > VillagerSystem.TIMERS.IDLE_FIDGET_MIN and
			   not entity:has("TimerComponent") and
			   not entity:has("WalkingComponent") then
				self:_fidget(entity)
			end
		else
			self:_takeAction(entity, dt)
		end
	end
end

function VillagerSystem:_takeAction(entity)
	local villager = entity:get("VillagerComponent")
	local adult = entity:has("AdultComponent") and entity:get("AdultComponent")
	local starving = villager:getStarvation() > 0.0
	local canWork = adult and ((adult:getOccupation() == WorkComponent.BUILDER and not villager:getHome()) or
	                           (not starving and villager:getHome()))

	-- Babies don't consume food or go outside.
	if villager:getAge() < VillagerSystem.CHILDHOOD then
		return
	end

	-- Unlikely to happen, but a mother in labour should probably go home.
	-- (Can theoretically occur if the mother is temporarily blocked by something.)
	if entity:has("PregnancyComponent") and entity:get("PregnancyComponent"):isInLabour() then
		-- Fake the event.
		self:childbirthStartedEvent(ChildbirthStartedEvent(entity))
		return
	end

	-- Check for breakfast.
	if villager:isHome() and villager:getHunger() >= VillagerSystem.FOOD.BREAKFAST_WHEN_ABOVE then
		if self:_eat(entity) then
			print(entity, "is getting breakfast")
			return
		end
	end

	-- If carrying something, drop it off first.
	if entity:has("CarryingComponent") then
		local carrying = entity:get("CarryingComponent")
		-- If starving and carrying some food, gulp it down greedily.
		if starving and carrying:getResource() == ResourceComponent.BREAD then
			print(entity, "gulping down the carried bread")
			-- TODO: Shouldn't go all the way down?
			villager:setHunger(0.0)
			villager:setStarvation(0.0)

			if carrying:getAmount() > 1 then
				-- Just the one is enough.
				carrying:setAmount(carrying:getAmount() - 1)
			else
				entity:remove("CarryingComponent")
			end
			return
		end

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

		return
	end

	if villager:getHome() then
		local home = villager:getHome()
		local dwelling = home:get("DwellingComponent")

		-- Check if the villager is sleepy.
		if not starving and villager:getSleepiness() >= VillagerSystem.SLEEP.SLEEPINESS_THRESHOLD then
			self:_prepare(entity, true)

			if villager:isHome() then
				self:_sleep(entity)
			else
				self:_goToBuilding(entity, home, WalkingComponent.INSTRUCTIONS.GO_HOME)
				villager:setGoal(VillagerComponent.GOALS.SLEEP)
			end
			return
		end

		-- Get some food if necessary and available.
		if not dwelling:isGettingFood() and
		   dwelling:getFood() <= VillagerSystem.FOOD.GATHER_WHEN_BELOW and
		   state:getNumAvailableResources(ResourceComponent.BREAD) >= 1 and
		   (starving or self:_isGettingFood(home, entity)) then
			dwelling:setGettingFood(true)

			self:_prepare(entity)
			self:_goToBuilding(entity, home, WalkingComponent.INSTRUCTIONS.GET_FOOD)
			villager:setGoal(VillagerComponent.GOALS.FOOD_PICKUP)
			return
		end

		-- Eat if necessary and possible.
		if villager:getHunger() >= VillagerSystem.FOOD.EAT_WHEN_ABOVE and
		   dwelling:getFood() >= 0.5 then -- TODO: Move the check?
			print(entity, "is hungry")
			self:_prepare(entity, true)

			if villager:isHome() then
				self:_eat(entity)
			else
				self:_goToBuilding(entity, home, WalkingComponent.INSTRUCTIONS.GO_HOME)
				villager:setGoal(VillagerComponent.GOALS.EAT)
			end
			return
		end
	end

	-- If adult with a work place, start working.
	if canWork and adult:getWorkPlace() then
		local workPlace = adult:getWorkPlace()
		local ti, tj = workPlace:get("PositionComponent"):getTile()

		self:_prepare(entity)

		if workPlace:has("ConstructionComponent") then
			local construction = workPlace:get("ConstructionComponent")

			-- Make a first pass to determine if any work can be carried out.
			local getMaterials, blacklist, resource = true, {}
			repeat
				resource = construction:getRandomUnreservedResource(blacklist)
				if not resource then
					-- Determine whether the construction needs any materials.
					if not construction:getRandomUnreservedResource() and construction:canBuild() then
						-- No additional materials needed, but might as well go there and help build it.
						getMaterials = false
					else
						-- Needs materials, but either blacklisted (not available) or in transit to the work site.
						villager:setDelay(VillagerSystem.TIMERS.NO_RESOURCE_DELAY)
						return
					end
				end

				-- Don't count that resource again, in case we go round again.
				if resource then
					blacklist[resource] = true
				end
			until not resource or state:getNumAvailableResources(resource) > 0

			-- For things being built, update the places where builders can stand, so that rubbish can
			-- be cleared around the build site after placing the building.
			construction:updateWorkGrids(self.map:getAdjacentGrids(workPlace))

			if getMaterials then
				entity:add(WalkingComponent(ti, tj, construction:getFreeWorkGrids(), WalkingComponent.INSTRUCTIONS.BUILD))
				villager:setGoal(VillagerComponent.GOALS.WORK_PICKUP)
			else
				entity:add(WalkingComponent(ti, tj, construction:getFreeWorkGrids(), WalkingComponent.INSTRUCTIONS.WORK))
				villager:setGoal(VillagerComponent.GOALS.WORK)
			end
		elseif workPlace:has("ProductionComponent") then
			local production = workPlace:get("ProductionComponent")

			-- First check if any resources are needed.
			if production:getNeededResources(entity) then
				-- Make a first pass to determine if any work can be carried out.
				local blacklist, resource = {}
				repeat
					resource = production:getNeededResources(entity, blacklist)
					if not resource then
						villager:setDelay(VillagerSystem.TIMERS.NO_RESOURCE_DELAY)
						return
					end

					-- Don't count that resource again, in case we go round again.
					blacklist[resource] = true
				until state:getNumAvailableResources(resource) > 0

				self:_goToBuilding(entity, workPlace, WalkingComponent.INSTRUCTIONS.PRODUCE)
				villager:setGoal(VillagerComponent.GOALS.WORK_PICKUP)
			else
				-- All resources accounted for. Get straight to work.
				self:_goToBuilding(entity, workPlace, WalkingComponent.INSTRUCTIONS.WORK)
				villager:setGoal(VillagerComponent.GOALS.WORK)
			end
		else
			local workGrids = workPlace:get("WorkComponent"):getWorkGrids()
			assert(workGrids, "No grid information for workplace "..workPlace:get("WorkComponent"):getTypeName())

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

		return
	end

	-- If adult with a special work area, get a place to work there.
	if canWork and adult:getWorkArea() and
	       (adult:getOccupation() == WorkComponent.WOODCUTTER or
	        adult:getOccupation() == WorkComponent.MINER or
	        adult:getOccupation() == WorkComponent.FARMER) then
		-- This could be optimized through the map or something, but eh.
		local cgrid = entity:has("PositionComponent") and
		              entity:get("PositionComponent"):getGrid() or
		              villager:getHome():get("PositionComponent"):getGrid()
		local ti, tj = adult:getWorkArea()
		local minDistance, closest = math.huge
		for _,workEntity in pairs(self.engine:getEntitiesWithComponent("WorkComponent")) do
			local assignment = workEntity:get("AssignmentComponent")
			local tgrid = workEntity:get("PositionComponent"):getGrid()
			local eti, etj = workEntity:get("PositionComponent"):getTile()
			local distance = math.distancesquared(cgrid.gi, cgrid.gj, tgrid.gi, tgrid.gj)
			if ti == eti and tj == etj and workEntity:get("WorkComponent"):getType() == adult:getOccupation() and
			   not workEntity:get("WorkComponent"):isComplete() and
			   assignment:getNumAssignees() < assignment:getMaxAssignees() and
			   distance < minDistance then
				minDistance = distance
				closest = workEntity
			end
		end

		if closest then
			closest:get("AssignmentComponent"):assign(entity)
			adult:setWorkPlace(closest)
			-- Start working the next round.
		else
			-- No such entity found. No work able to be carried out.
			if adult:getOccupation() == WorkComponent.FARMER then
				-- For farms, try again later.
				villager:setDelay(VillagerSystem.TIMERS.FARM_WAIT)
			else
				self.eventManager:fireEvent(ResourceDepletedEvent(
					adult:getOccupation() == WorkComponent.WOODCUTTER and ResourceComponent.WOOD or ResourceComponent.IRON,
					adult:getWorkArea()))
				adult:setWorkArea(nil)
			end
		end

		return
	end

	-- If a builder, then look for other places to help out.
	if canWork and adult:getOccupation() == WorkComponent.BUILDER then
		local minDistance, closest = math.huge
		local cgrid = entity:has("PositionComponent") and
		              entity:get("PositionComponent"):getGrid() or
		              villager:getHome():get("PositionComponent"):getGrid()

		for _,buildingEntity in pairs(self.engine:getEntitiesWithComponent("ConstructionComponent")) do
			local assignment = buildingEntity:get("AssignmentComponent")
			local tgrid = buildingEntity:get("PositionComponent"):getGrid()
			local distance = math.distancesquared(cgrid.gi, cgrid.gj, tgrid.gi, tgrid.gj)

			if assignment:getNumAssignees() < assignment:getMaxAssignees() and
			   distance < minDistance then
				minDistance = distance
				closest = buildingEntity
			end
		end

		if closest then
			closest:get("AssignmentComponent"):assign(entity)
			adult:setWorkPlace(closest)
			adult:setWorkArea(closest:get("PositionComponent"):getTile())
			return -- Start working the next round.
		end
	end

	-- If the entity is waiting or walking around, let them do that.
	if entity:has("TimerComponent") or entity:has("WalkingComponent") then
		-- Add some kind of delay, so that we don't thrash around too much.
		villager:setDelay(VillagerSystem.TIMERS.MIN_DELAY)
		return
	end

	-- Leave the house, if inside.
	self:_prepare(entity, false)
	-- Move away from any reserved grid, or fidget a bit.
	self:_fidget(entity)
end

function VillagerSystem:_fidget(entity)
	local villager = entity:get("VillagerComponent")

	local dirConv = require("src.game.worksystem").DIR_CONV[villager:getCardinalDirection()] -- XXX
	local grid = entity:get("PositionComponent"):getGrid()

	if self.map:isGridReserved(entity:get("PositionComponent"):getGrid()) then
		-- The villager is standing on a reserved grid, and probably needs to move to avoid further collisions and
		-- slowdowns.
		local freeGrid = self:_getNearbyFreeGrid(grid, dirConv)

		if freeGrid then
			entity:add(WalkingComponent(nil, nil, { freeGrid }, WalkingComponent.INSTRUCTIONS.GET_OUT_THE_WAY))
			villager:setDelay(VillagerSystem.TIMERS.MIN_DELAY)
			return
		else
			print(entity, "Failed to find a free grid in the vicinity.")
		end
	end

	local min, max = VillagerSystem.TIMERS.IDLE_FIDGET_MIN, VillagerSystem.TIMERS.IDLE_FIDGET_MAX
	local delay = love.math.random() * (max - min) + min
	villager:setDelay(delay)
	-- XXX: Dummy timer component to avoid doing anything until the delay is up...
	entity:add(TimerComponent(delay, { entity }, function(data)
		data[1]:remove("TimerComponent")
	end))

	-- 2/3 chance to rotate/fidget in place.
	local dir = villager:getDirection()
	villager:setDirection(((dir + 45 * love.math.random(-1, 1)) + 360) % 360)

	if love.math.random() < VillagerSystem.RAND.WANDER_FORWARD_CHANCE then
		local target = self.map:getGrid(grid.gi + dirConv[1], grid.gj + dirConv[2])

		-- Don't bring the villager to an occupied or reserved grid.
		if target and self.map:isGridEmpty(target) and not self.map:isGridReserved(target) then
			if not entity:has("AdultComponent") and love.math.random() < VillagerSystem.RAND.CHILD_DOUBLE_FORWARD_CHANCE then
				local other = self.map:getGrid(target.gi + dirConv[1], target.gj + dirConv[2])
				if other and self.map:isGridEmpty(other) and not self.map:isGridReserved(other) then
					target = other
				end
			end

			entity:add(WalkingComponent(nil, nil, { target }, WalkingComponent.INSTRUCTIONS.WANDER))
		end
	end
end

function VillagerSystem:_getNearbyFreeGrid(grid, dirConv)
	local sign = love.math.random(0, 1)
	if sign == 0 then
		sign = -1
	end

	if math.abs(dirConv[1] + dirConv[2]) == 1 then
		-- Split into four quadrants, prioritizing forward, then either of the sides, and then backwards.
		local dirs = {
			dirConv,
			{ dirConv[2] * sign, dirConv[1] * sign },
			{ dirConv[2] * -sign, dirConv[1] * -sign },
			{ -dirConv[1], -dirConv[2] }
		}
		for _,dir in ipairs(dirs) do
			for i=1,VillagerSystem.RESERVE_GRID_DISTANCE do
				local gi, gj = grid.gi + (dir[1] * i), grid.gj + (dir[2] * i)

				local available = {}
				for w=-i,i do
					local target
					if dir[1] == 0 then
						-- Expanding up or down. v
						--                       ^
						target = self.map:getGrid(grid.gi + w, gj)
					elseif dir[2] == 0 then
						-- Expanding sideways. ><
						target = self.map:getGrid(gi, grid.gj + w)
					end
					if target and self.map:isGridEmpty(target) and not self.map:isGridReserved(target) then
						table.insert(available, target)
					end
				end

				local _,target = next(table.shuffle(available))
				if target then
					return target
				end
			end
		end
	else
		-- Split into four quadrants, prioritizing forward, then either of the sides, and then backwards.
		local dirs = {
			dirConv,
			{ dirConv[1] * -sign, dirConv[2] * sign },
			{ dirConv[1] * sign, dirConv[2] * -sign },
			{ -dirConv[1], -dirConv[2] }
		}
		for _,dir in ipairs(dirs) do
			for i=1,VillagerSystem.RESERVE_GRID_DISTANCE do
				local gi, gj = grid.gi + (dir[1] * i), grid.gj + (dir[2] * i)

				local available = {}
				for w=0,i*-dir[1],-dir[1] do
					local target = self.map:getGrid(gi + w, gj)
					if target and self.map:isGridEmpty(target) and not self.map:isGridReserved(target) then
						table.insert(available, target)
					end
				end

				-- Note: 0,0 (gi,gj) is added twice to available if it is free. Feature?
				for h=0,i*-dir[2],-dir[2] do
					local target = self.map:getGrid(gi, gj + h)
					if target and self.map:isGridEmpty(target) and not self.map:isGridReserved(target) then
						table.insert(available, target)
					end
				end

				local _,target = next(table.shuffle(available))
				if target then
					return target
				end
			end
		end
	end

	return nil
end

function VillagerSystem:_goToBuilding(entity, building, instructions)
	-- Assumes that _prepare() and everything else has been called.

	local entranceGrid = self.map:getGrid(building:get("EntranceComponent"):getAbsoluteGridCoordinate(building))
	local ti, tj = building:get("PositionComponent"):getTile()

	-- XXX: That double array inconsistency...
	if instructions == WalkingComponent.INSTRUCTIONS.WORK then
		entranceGrid = { entranceGrid }
	end

	entity:add(WalkingComponent(ti, tj, { entranceGrid }, instructions))
end

function VillagerSystem:_eat(entity)
	local villager = entity:get("VillagerComponent")
	local home = villager:getHome()
	local dwelling = home:get("DwellingComponent")

	-- TODO: Check if other family members need the food more.
	-- TODO: Partial digestion.
	-- TODO: Children gain more.
	if dwelling:getFood() < 0.5 then
		return false
	end

	assert(villager:isHome(), "Uh-oh")
	villager:setGoal(VillagerComponent.GOALS.EATING)

	local eating = 0.5
	dwelling:setFood(dwelling:getFood() - eating)
	local targetHunger = math.max(0.0, villager:getHunger() - eating)
	villager:setDelay((villager:getHunger() - targetHunger) / VillagerSystem.FOOD.LOSS_PER_SECOND)
	-- Clear the starvation.
	villager:setStarvation(0.0)

	return true
end

function VillagerSystem:_sleep(entity)
	local villager = entity:get("VillagerComponent")

	assert(villager:isHome(), "Uh-oh")
	villager:setGoal(VillagerComponent.GOALS.SLEEPING)
	villager:setDelay(villager:getSleepiness() / VillagerSystem.SLEEP.LOSS_PER_SECOND)
end

function VillagerSystem:_dropCarrying(entity, grid)
	if not entity:has("CarryingComponent") then
		return
	end

	if not grid then
		-- Just drop it at her feet.
		-- TODO: Maybe do something smarter here?
		grid = entity:get("PositionComponent"):getGrid()
	end

	local resource = entity:get("CarryingComponent"):getResource()
	local amount = entity:get("CarryingComponent"):getAmount()
	entity:remove("CarryingComponent")

	local resourceEntity = blueprint:createResourcePile(resource, amount)
	self.map:addResource(resourceEntity, grid, true)
	resourceEntity:add(PositionComponent(grid, nil, self.map:gridToTileCoords(grid.gi, grid.gj)))
	self.engine:addEntity(resourceEntity)
end

function VillagerSystem:_prepare(entity, okInside)
	local villager = entity:get("VillagerComponent")

	-- Remove any lingering timer.
	if entity:has("TimerComponent") then
		entity:remove("TimerComponent")
	end

	-- Remove any walking instruction.
	if entity:has("WalkingComponent") then
		entity:remove("WalkingComponent")
	end

	-- Ensure that the villager is outside.
	if not okInside and villager:getInside() then
		-- Leave the building.
		self.eventManager:fireEvent(BuildingLeftEvent(villager:getInside(), entity))
	end
end

function VillagerSystem:_stopAll(entity)
	local villager = entity:get("VillagerComponent")
	local adult = entity:has("AdultComponent") and entity:get("AdultComponent")
	local workPlace = adult and adult:getWorkPlace()

	-- Unreserve any reserved resource.
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

	-- Unassign any resources that might have been reserved.
	-- TODO: Maybe send it off as an event?
	if workPlace then
		if workPlace:has("ConstructionComponent") then
			workPlace:get("ConstructionComponent"):unreserveGrid(entity)

			if not type and entity:has("CarryingComponent") then
				type, amount = entity:get("CarryingComponent"):getResource(), entity:get("CarryingComponent"):getAmount()
			end

			if type and amount then
				workPlace:get("ConstructionComponent"):unreserveResource(type, amount)
			end
		elseif workPlace:has("ProductionComponent") then
			workPlace:get("ProductionComponent"):releaseResources(entity)
		elseif workPlace:has("WorkComponent") then
			-- The workplace is a resource extraction, so release that particular resource for now, so that someone
			-- else can work on it if they so choose.
			workPlace:get("AssignmentComponent"):unassign(entity)
			adult:setWorkPlace(nil)
		end

		if entity:has("WorkingComponent") then
			entity:remove("WorkingComponent")
		end
	end

	-- Clear the getting-food flag.
	if villager:getGoal() == VillagerComponent.GOALS.FOOD_DROPOFF then
		villager:getHome():get("DwellingComponent"):setGettingFood(false)
	end

	-- Clear any delay.
	villager:setDelay(0)
	-- Clear any targets.
	villager:setTargetEntity(nil)
	villager:setTargetGrid(nil)
	villager:setTargetRotation(nil)
	-- Reset the goal.
	villager:setGoal(VillagerComponent.GOALS.NONE)
end

-- Assumes that _stopAll() has been called before, if necessary.
function VillagerSystem:_unassignWork(entity)
	local adult = entity:get("AdultComponent")
	local workPlace = adult:getWorkPlace()

	if workPlace then
		workPlace:get("AssignmentComponent"):unassign(entity)
		adult:setWorkPlace(nil)
	end
	adult:setWorkArea(nil)

	if adult:getOccupation() == WorkComponent.FARMER then
		local enclosure
		if workPlace then
			enclosure = workPlace:get("FieldComponent"):getEnclosure()
		else
			for _,v in pairs(self.engine:getEntitiesWithComponent("FieldEnclosureComponent")) do
				if v:get("AssignmentComponent"):isAssigned(entity) then
					enclosure = v
					break
				end
			end
		end
		if enclosure then
			enclosure:get("AssignmentComponent"):unassign(entity)
		end
	end

	if entity:has("WorkComponent") then
		entity:remove("WorkComponent")
	end
end

-- Determine whether the specified entity should get food for the dwelling.
-- It prioritizes children that have reached childhood, and then unemployed adults.
function VillagerSystem:_isGettingFood(dwelling, entity)
	local hasUnoccupied = false
	for _,child in ipairs(dwelling:get("DwellingComponent"):getChildren()) do
		if child:get("VillagerComponent"):getAge() >= VillagerSystem.CHILDHOOD and
		   (not child:has("AdultComponent") or not child:get("AdultComponent"):getWorkArea()) then
			if child == entity then
				return true
			else
				hasUnoccupied = true
			end
		end
	end

	if not hasUnoccupied then
		for _,villager in ipairs(dwelling:get("AssignmentComponent"):getAssignees()) do
			if not villager:get("AdultComponent"):getWorkArea() then
				if villager == entity then
					return true
				else
					hasUnoccupied = true
				end
			end
		end
	end

	return not hasUnoccupied
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
		local oldHome = villager:getHome()

		if oldHome then
			-- Check whether the villager is living with their parents.
			-- (This event is only sent if the villager was not previously assigned.)
			if oldHome == site then
				site:get("DwellingComponent"):removeChild(entity)
			else
				self:unassignedEvent(UnassignedEvent(oldHome, entity))
			end
		end

		villager:setHome(site)

		-- Check if we there are any kids we need to bring with us.
		-- Divide up the children randomly (cause why not).
		for _,child in ipairs(villager:getChildren()) do
			-- Don't move children that don't live with this parent.
			if child:get("VillagerComponent"):getHome() == oldHome then
				local moveIn = false
				if oldHome then
					-- First, check to see if there is a parent left in the old home.
					if site:get("AssignmentComponent"):getNumAssignees() == 0 then
						moveIn = true
					else
						local villagerLeft = site:get("AssignmentComponent"):getAssignees()[1]
						if child:get("VillagerComponent"):getMother() == villagerLeft or
						   child:get("VillagerComponent"):getFather() == villagerLeft then
							-- Then, check if the new house is crowded (5+ children)
							if site:get("DwellingComponent"):getNumBoys() + site:get("DwellingComponent"):getNumGirls() >= 5 then
								moveIn = false
							else
								-- 50/50
								moveIn = love.math.random() < 0.5
							end
						end
					end

					if moveIn then
						oldHome:get("DwellingComponent"):removeChild(child)
					end
				else
					-- Take the chance to actually LIVE.
					moveIn = true
				end

				if moveIn then
					child:get("VillagerComponent"):setHome(site)
					site:get("DwellingComponent"):addChild(child)
				end
			end
		end

		local assignees = site:get("AssignmentComponent"):getAssignees()
		local other = assignees[1] ~= entity and assignees[1] or assignees[2]
		if other then
			other = other:get("VillagerComponent")
			local isRelated, _
			-- Set the related flag.
			-- This is done by checking the parent uniques.
			-- TODO: This means that grandparents, cousins, and uncles/aunts aren't considered related,
			--       but the alternative is to save some kind of family tree for everyone.
			local myUnique, myMotherUnique, myFatherUnique
			local otherUnique, otherMotherUnique, otherFatherUnique
			myUnique, otherUnique = villager:getUnique(), other:getUnique()
			_, myMotherUnique = villager:getMother()
			_, myFatherUnique = villager:getFather()
			_, otherMotherUnique = other:getMother()
			_, otherFatherUnique = other:getFather()

			isRelated = myUnique == otherMotherUnique or
			            myUnique == otherFatherUnique or
			            otherUnique == myMotherUnique or
			            otherUnique == myFatherUnique or
			            myFatherUnique == otherFatherUnique or
			            myMotherUnique == otherMotherUnique

			site:get("DwellingComponent"):setRelated(isRelated)
		end
	else
		local workPlace = adult:getWorkPlace()

		if workPlace == site then
			-- If already working there, then nothing needs to be done.
			return
		elseif workPlace then
			self:unassignedEvent(UnassignedEvent(workPlace, entity))
		else
			-- Most likely a farmer not currently working a field.
			self:_unassignWork(entity)
		end

		adult:setWorkArea(site:get("PositionComponent"):getTile())

		-- The villager might be assigned to the same work area, but not the same work site.
		-- Fields are special little snowflakes, and should not be assigned as a work place.
		if not site:has("FieldEnclosureComponent") and site:get("AssignmentComponent"):isAssigned(entity) then
			adult:setWorkPlace(site)
		end

		-- Guess the occupation!
		if site:has("ConstructionComponent") then
			adult:setOccupation(WorkComponent.BUILDER)
		elseif site:has("WorkComponent") then
			adult:setOccupation(site:get("WorkComponent"):getType())
		elseif site:has("BuildingComponent") then
			local type = site:get("BuildingComponent"):getType()
			if type == BuildingComponent.BLACKSMITH then
				adult:setOccupation(WorkComponent.BLACKSMITH)
			elseif type == BuildingComponent.FIELD then
				adult:setOccupation(WorkComponent.FARMER)
			elseif type == BuildingComponent.BAKERY then
				adult:setOccupation(WorkComponent.BAKER)
			else
				error("What kind of building is this?")
			end
		else
			error("I give up :(")
		end
	end

	villager:setDelay(VillagerSystem.TIMERS.ASSIGNED_DELAY)
end

function VillagerSystem:unassignedEvent(event)
	local entity = event:getAssignee()
	local site = event:getAssigner()
	local villager = entity:get("VillagerComponent")

	self.homeRelatedGoals = self.homeRelatedGoals or {
		VillagerComponent.GOALS.FOOD_PICKUP,
		VillagerComponent.GOALS.FOOD_PICKING_UP,
		VillagerComponent.GOALS.FOOD_DROPOFF,
		VillagerComponent.GOALS.SLEEP,
		VillagerComponent.GOALS.SLEEPING,
		VillagerComponent.GOALS.EAT,
		VillagerComponent.GOALS.EATING,
		VillagerComponent.GOALS.CHILDBIRTH
	}
	self.workRelatedGoals = self.workRelatedGoals or {
		VillagerComponent.GOALS.WORK_PICKUP,
		VillagerComponent.GOALS.WORK_PICKING_UP,
		VillagerComponent.GOALS.WORK
	}

	if site:has("DwellingComponent") then
		for _,goal in ipairs(self.homeRelatedGoals) do
			if villager:getGoal() == goal then
				self:_stopAll(entity)
				self:_prepare(entity)
				break
			end
		end

		if entity:has("AdultComponent") and site:get("AssignmentComponent"):isAssigned(entity) then
			site:get("AssignmentComponent"):unassign(entity)
			site:get("DwellingComponent"):setRelated(false) -- Can't be related to yourself!
		else
			site:get("DwellingComponent"):removeChild(entity)
		end

		villager:setHome(nil)
	else
		for _,goal in ipairs(self.workRelatedGoals) do
			if villager:getGoal() == goal then
				self:_stopAll(entity)
				self:_prepare(entity)
				break
			end
		end

		self:_unassignWork(entity)
	end
end

function VillagerSystem:buildingEnteredEvent(event)
	local entity = event:getVillager()
	local villager = entity:get("VillagerComponent")

	if event:isTemporary() then
		entity:remove("SpriteComponent")
		entity:remove("InteractiveComponent")

		entity:add(TimerComponent(VillagerSystem.TIMERS.BUILDING_TEMP_ENTER,
		                          { entity, VillagerComponent.GOALS.NONE }, function(data)
			local ent = data[1]
			local vill = ent:get("VillagerComponent")

			ent:add(require("src.game.spritecomponent")())

			if ent:has("WorkingComponent") then
				ent:remove("WorkingComponent")
			end
			ent:remove("TimerComponent")

			vill:setGoal(data[2])
			vill:setDelay(0.5)
			-- The villager's direction should be the opposite.
			-- TODO: The villager can temporarily enter a building from a variety of angles.
			vill:setDirection((((vill:getDirection() + 180) + love.math.random(-2, 2) * 45) + 360) % 360)
		end))
	else
		entity:remove("SpriteComponent")
		entity:remove("PositionComponent")
		entity:remove("InteractiveComponent")

		villager:setInside(event:getBuilding())
	end
end

function VillagerSystem:buildingLeftEvent(event)
	local entity = event:getVillager()
	local building = event:getBuilding()

	if not entity.alive then
		-- This event is triggered when a dead villager physically leaves the building as well,
		-- but in that case we shouldn't do anything else.
		return
	end

	local entrance = building:get("EntranceComponent")
	local entranceGrid = self.map:getGrid(entrance:getAbsoluteGridCoordinate(building))
	local villager = entity:get("VillagerComponent")

	if villager:getAge() >= VillagerSystem.ADULTHOOD and not entity:has("AdultComponent") then
		entity:add(AdultComponent()) -- TODO: Send user event
		entity:add(FertilityComponent())

		state:decreaseNumVillagers(villager:getGender(), false)
		state:increaseNumVillagers(villager:getGender(), true)

		self.eventManager:fireEvent(VillagerMaturedEvent(entity))
	elseif villager:getAge() >= VillagerSystem.SENIORHOOD and not entity:has("SeniorComponent") then
		entity:add(SeniorComponent())
		-- Change the hair.
		entity:get("ColorSwapComponent"):replace("hair",
			{ { 0.45, 0.45, 0.45, 1.0 },
			  { 0.55, 0.55, 0.55, 1.0 } })
	end

	-- The villager's direction should be away from the door.
	villager:setDirection(((entrance:getEntranceGrid().rotation + love.math.random(-2, 2) * 45) + 360) % 360)

	villager:setInside(nil)
	villager:setGoal(VillagerComponent.GOALS.NONE)
	entity:add(PositionComponent(entranceGrid, nil, building:get("PositionComponent"):getTile()))
	entity:add(SpriteComponent()) -- XXX: Must be added after the position component.

	villager:setDelay(VillagerSystem.TIMERS.BUILDING_LEFT_DELAY)
end

function VillagerSystem:childbirthStartedEvent(event)
	local entity = event:getVillager()
	local villager = entity:get("VillagerComponent")

	self:_stopAll(entity)
	self:_prepare(entity, true)

	self:_dropCarrying(entity)

	-- The mother will need to make her way home, to prepare.
	if villager:getHome() then
		if not villager:isHome() then
			self:_goToBuilding(entity, villager:getHome(), WalkingComponent.INSTRUCTIONS.GO_HOME)
		end
		villager:setGoal(VillagerComponent.GOALS.CHILDBIRTH)
	else
		-- If she has no home, she will just stand about.
		villager:setDelay(VillagerSystem.TIMERS.CHILDBIRTH_NO_HOME_DELAY)
		-- Stop what you're doing anyway.
		villager:setGoal(VillagerComponent.GOALS.NONE)
	end
end

function VillagerSystem:childbirthEndedEvent(event)
	local entity = event:getMother()
	local villager = entity:get("VillagerComponent")

	-- Make sure the mother isn't sleeping or doing anything else.
	self:_stopAll(entity)
	self:_prepare(entity, true)

	local father, fatherUnique = event:getFather()
	-- The child is created even if she didn't make it, so that the death animation can be played correctly.
	local child = blueprint:createVillager(entity, father)

	-- Father might have died already.
	child:get("VillagerComponent").fatherUnique = fatherUnique
	if father and not father.alive then
		child:get("VillagerComponent"):clearFather()
	end

	if event:wasIndoors() then
		local home = villager:getHome()

		child:remove("SpriteComponent") -- Don't need that.
		child:get("VillagerComponent"):setHome(home)
		child:get("VillagerComponent"):setInside(home)

		home:get("DwellingComponent"):addChild(child)
		home:get("BuildingComponent"):addInside(child)

		local entranceGrid = self.map:getGrid(home:get("EntranceComponent"):getAbsoluteGridCoordinate(home))
		child:set(GroundComponent(self.map:gridToGroundCoords(entranceGrid.gi + 0.5, entranceGrid.gj + 0.5)))
	else
		assert(not event:didChildSurvive(), "Don't know where to place the child.")
		local position = entity:get("PositionComponent")
		child:add(PositionComponent(position:getGrid(), nil, position:getTile()))
	end
	self.engine:addEntity(child)

	if not event:didChildSurvive() then
		-- No need to fire a death event here, since the child never technically became a villager.
		self.engine:removeEntity(child, true)
	end

	if event:didMotherSurvive() then
		villager:setDelay(VillagerSystem.TIMERS.CHILDBIRTH_RECOVERY_DELAY)
		villager:setGoal(VillagerComponent.GOALS.NONE)
	else
		self.eventManager:fireEvent(VillagerDeathEvent(entity, VillagerDeathEvent.REASONS.CHILDBIRTH))
		self.engine:removeEntity(entity, true)
	end
end

function VillagerSystem:onAddEntity(entity)
	state:increaseNumVillagers(entity:get("VillagerComponent"):getGender(), entity:has("AdultComponent"))
end

-- Called when a villager dies.
function VillagerSystem:onRemoveEntity(entity)
	local villager = entity:get("VillagerComponent")

	entity.alive = false -- Set by the engine, but too late for our needs.

	self:_stopAll(entity)
	self:_prepare(entity)
	self:_dropCarrying(entity)

	state:decreaseNumVillagers(villager:getGender(), entity:has("AdultComponent"))

	-- Create a particle showing that a villager died.
	local grid, ti, tj
	if villager:getInside() then
		-- Create a sprite emanating from the building.
		local site = villager:getInside()
		local from, to = site:get("PositionComponent"):getFromGrid(), site:get("PositionComponent"):getToGrid()
		grid = self.map:getGrid(from.gi + math.floor((to.gi - from.gi) / 2),
		                        from.gj + math.floor((to.gj - from.gj) / 2))
		ti, tj = site:get("PositionComponent"):getTile()
	else
		-- Villager is outside.
		grid = entity:get("PositionComponent"):getGrid()
		ti, tj = entity:get("PositionComponent"):getTile()
	end
	local particle = blueprint:createDeathParticle(entity)
	particle:set(PositionComponent(grid, nil, ti, tj))
	particle:get("SpriteComponent"):setDrawPosition(self.map:gridToWorldCoords(grid.gi, grid.gj))
	self.engine:addEntity(particle)

	soundManager:playEffect("villager_death", grid)

	-- Free home assignments.
	if villager:getHome() then
		local assignment = villager:getHome():get("AssignmentComponent")
		if assignment:isAssigned(entity) then
			assignment:unassign(entity)
			if assignment:getNumAssignees() < 1 and #villager:getChildren() > 0 then
				-- Assign the oldest child as the one responsible for the household.
				-- TODO: We should check that this doesn't cause any weird behaviour.
				-- TODO: Probably a bit weird if there is one adult living with the children that isn't related to them.
				-- TODO: Probably a bit weird when moving the child that was made responsible, since they won't bring
				--       their brothers and sisters with them.
				local child = villager:getChildren()[1]
				assignment:assign(child)
				-- Fake an event, since everything should be handled there.
				self:assignedEvent(AssignedEvent(villager:getHome(), child))
			end
		else
			-- Probably a child.
			local dwelling = villager:getHome():get("DwellingComponent")
			dwelling:removeChild(entity)
		end
	end

	-- Free work assignment.
	if entity:has("AdultComponent") then
		self:_unassignWork(entity)
	end

	-- Drop what's being carried.
	if entity:has("CarryigComponent") then
		self:_dropCarrying(entity)
	end

	-- Free up resources so as not to save them.
	local parents = {}
	table.insert(parents, (villager:getMother()))
	table.insert(parents, (villager:getFather()))
	for _,parent in ipairs(parents) do
		parent:get("VillagerComponent"):removeChild(entity)
	end

	for _,child in ipairs(villager:getChildren()) do
		if villager:getGender() == "male" then
			child:get("VillagerComponent"):clearFather()
		else
			child:get("VillagerComponent"):clearMother()
		end
	end
end

function VillagerSystem:targetReachedEvent(event)
	local entity = event:getVillager()
	local villager = entity:get("VillagerComponent")
	local goal = villager:getGoal()

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

		villager:setGoal(VillagerComponent.GOALS.DROPPING_OFF)
		villager:setTargetGrid(grid)
		villager:setDelay(VillagerSystem.TIMERS.DROPOFF_BEFORE)
	elseif goal == VillagerComponent.GOALS.FOOD_PICKUP or
	       goal == VillagerComponent.GOALS.WORK_PICKUP then
		assert(event:getNextStop(), "Nowhere to put the resource.")

		villager:setTargetEntity(event:getTarget())
		villager:setDelay(VillagerSystem.TIMERS.PICKUP_BEFORE)

		if goal == VillagerComponent.GOALS.FOOD_PICKUP then
			villager:setGoal(VillagerComponent.GOALS.FOOD_PICKING_UP)
			villager:setTargetGrid(event:getNextStop())
			villager:setTargetRotation(nil)
		else
			villager:setGoal(VillagerComponent.GOALS.WORK_PICKING_UP)
			villager:setTargetGrid(event:getNextStop()[1])
			villager:setTargetRotation(event:getNextStop()[2])
		end
	elseif goal == VillagerComponent.GOALS.FOOD_DROPOFF then
		local resource = entity:get("CarryingComponent"):getResource()
		local amount = entity:get("CarryingComponent"):getAmount()
		local home = villager:getHome()
		local dwelling = home:get("DwellingComponent")

		assert(resource == ResourceComponent.BREAD, "Is this even edible?")
		dwelling:setFood(dwelling:getFood() + amount)
		dwelling:setGettingFood(false)

		entity:remove("CarryingComponent")

		-- XXX: If the event is temporary, the villager might pop out and then back in, if e.g. tired or hungry.
		--      If not temporary, the villager might pop in, start the chimney, and then back out.
		self.eventManager:fireEvent(BuildingEnteredEvent(home, entity, true))
		--villager:setDelay(VillagerSystem.TIMERS.BUILDING_TEMP_ENTER)
		--villager:setGoal(VillagerComponent.GOALS.NONE)
	elseif goal == VillagerComponent.GOALS.WORK then
		local workPlace = entity:get("AdultComponent"):getWorkPlace()

		-- Start working
		entity:get("WorkingComponent"):setWorking(true)

		if entity:has("CarryingComponent") then
			local resource = entity:get("CarryingComponent"):getResource()
			local amount = entity:get("CarryingComponent"):getAmount()

			if workPlace:has("ConstructionComponent") then
				workPlace:get("ConstructionComponent"):addResources(resource, amount)
			elseif workPlace:has("ProductionComponent") then
				local production = workPlace:get("ProductionComponent")
				production:addResource(resource, amount)
				production:reserveResource(entity, resource, amount)

				local temporary = production:getNeededResources(entity) ~= nil
				self.eventManager:fireEvent(BuildingEnteredEvent(workPlace, entity, temporary))
			else
				error("Carried resources to unknown workplace.")
			end

			entity:remove("CarryingComponent")
		elseif workPlace:has("ProductionComponent") then
			-- This should be for finishing a produce.
			self.eventManager:fireEvent(BuildingEnteredEvent(workPlace, entity))
		end
	elseif goal == VillagerComponent.GOALS.SLEEP then
		self.eventManager:fireEvent(BuildingEnteredEvent(villager:getHome(), entity))
		self:_sleep(entity)
	elseif goal == VillagerComponent.GOALS.EAT then
		self.eventManager:fireEvent(BuildingEnteredEvent(villager:getHome(), entity))
		self:_eat(entity)
	elseif goal == VillagerComponent.GOALS.CHILDBIRTH then
		self.eventManager:fireEvent(BuildingEnteredEvent(villager:getHome(), entity))
		-- A new event will be fired when the childbirth has ended.
	elseif goal == VillagerComponent.GOALS.MOVING then
		villager:setDelay(VillagerSystem.TIMERS.PATH_WAIT_DELAY)
		villager:setGoal(VillagerComponent.GOALS.NONE)
	end
end

function VillagerSystem:targetUnreachableEvent(event)
	local entity = event:getVillager()
	local villager = entity:get("VillagerComponent")

	if villager:getGoal() == VillagerComponent.GOALS.NONE then
		-- Probably wandering about, so nothing more needs to be done.
		return
	end

	print(entity, "Unreachable!")

	-- Start by stopping everything
	self:_stopAll(entity)

	villager:setDelay(VillagerSystem.TIMERS.PATH_FAILED_DELAY)
	villager:setGoal(VillagerComponent.GOALS.NONE)
end

function VillagerSystem:villagerAgedEvent(event)
	local entity = event:getVillager()
	local villager = entity:get("VillagerComponent")
	local ageDiff = villager:getAge() - VillagerSystem.SENIORHOOD

	--print(villager:getAge(), ageDiff * VillagerSystem.DEATH_CHANCE)
	if ageDiff > 0 and
	   love.math.random() < ageDiff * VillagerSystem.DEATH_CHANCE then
		self.eventManager:fireEvent(VillagerDeathEvent(entity, VillagerDeathEvent.REASONS.AGE))
		self.engine:removeEntity(entity, true)
	end
end

function VillagerSystem:workCompletedEvent(event)
	local entity = event:getVillager()
	local villager = entity:get("VillagerComponent")
	local adult = entity:get("AdultComponent")

	local builder = adult:getOccupation() == WorkComponent.BUILDER
	local farmer = adult:getOccupation() == WorkComponent.FARMER

	if farmer then
		-- Only increase the sleepiness of farmers if there aren't any fields left on the same stage.
		local fieldEnclosure = adult:getWorkPlace():get("FieldComponent"):getEnclosure()
		local fields = fieldEnclosure:get("FieldEnclosureComponent"):getFields()
		local completed = true
		for _,field in ipairs(fields) do
			if not field:get("WorkComponent"):isComplete() then
				completed = false
				break
			end
		end
		if completed then
			-- Find all villagers and increase their sleepiness.
			for _,assignee in ipairs(fieldEnclosure:get("AssignmentComponent"):getAssignees()) do
				assignee:get("VillagerComponent"):setSleepiness(1.0)
			end
		end
		adult:setWorkPlace(nil)
	elseif not event:isTemporary() then
		villager:setSleepiness(1.0)
		adult:setWorkPlace(nil)

		-- Clear the work area for the builder, since there isn't anything else to do there.
		if builder then
			adult:setWorkArea(nil)
		end
	elseif event:getWorkSite():has("ProductionComponent") then
		villager:setSleepiness(1.0)
	end

	if entity:has("WorkingComponent") then -- Might not be actively working on the site (e.g. resource already covered)
		entity:remove("WorkingComponent")
	end
	villager:setDelay(VillagerSystem.TIMERS.WORK_COMPLETED_DELAY)
	villager:setGoal(VillagerComponent.GOALS.NONE)
end

return VillagerSystem
