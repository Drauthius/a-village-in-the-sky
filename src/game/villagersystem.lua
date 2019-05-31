local lovetoys = require "lib.lovetoys.lovetoys"
local table = require "lib.table"

local AssignedEvent = require "src.game.assignedevent"
local BuildingEnteredEvent = require "src.game.buildingenteredevent"
local BuildingLeftEvent = require "src.game.buildingleftevent"
local ChildbirthStartedEvent = require "src.game.childbirthstartedevent"
local UnassignedEvent = require "src.game.unassignedevent"
local VillagerAgedEvent = require "src.game.villageragedevent"

local AdultComponent = require "src.game.adultcomponent"
local BuildingComponent = require "src.game.buildingcomponent"
local CarryingComponent = require "src.game.carryingcomponent"
local FertilityComponent = require "src.game.fertilitycomponent"
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
local state = require "src.game.state"

local VillagerSystem = lovetoys.System:subclass("VillagerSystem")

VillagerSystem.static.TIMERS = {
	PICKUP_BEFORE = 0.25,
	PICKUP_AFTER = 0.5,
	DROPOFF_BEFORE = 0.25,
	DROPOFF_AFTER = 0.5,
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
	-- When eating: 20 seconds to get rid of 100% sleepiness
	LOSS_PER_SECOND = 1 / 20
}

VillagerSystem.static.SLEEP = {
	-- When idle: 90 seconds to gain 100% sleepiness.
	IDLE_GAIN_PER_SECOND = 1 / 90,
	-- When sleeping: 45 seconds to get rid of 100% sleepiness.
	LOSS_PER_SECOND = 1 / 45,
	-- When the villager should try and get some shut-eye.
	SLEEPINESS_THRESHOLD = 0.65
}

-- When the babies reach childhood, and can start going out.
VillagerSystem.static.CHILDHOOD = 5
-- When the children reach adulthood, and can start working.
VillagerSystem.static.ADULTHOOD = 14
-- When the adults reach seniorhood, and work/walk slower.
VillagerSystem.static.SENIORHOOD = 55
-- The chance to die of old age, accumulated per year after reaching seniorhood.
VillagerSystem.static.DEATH_CHANCE = 0.005

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
		local villager = entity:get("VillagerComponent")
		local age = villager:getAge()
		local goal = villager:getGoal()

		villager:increaseAge(TimerComponent.YEARS_PER_SECOND * dt)
		if math.floor(age) ~= math.floor(villager:getAge()) then
			-- Happy birthday!
			self.eventManager:fireEvent(VillagerAgedEvent(entity))
			age = villager:getAge()
		end

		if (not villager:isHome() or goal ~= VillagerComponent.GOALS.EAT) and age >= VillagerSystem.CHILDHOOD then
			local hunger = math.min(1.0, villager:getHunger() + VillagerSystem.FOOD.HUNGER_PER_SECOND * dt)
			villager:setHunger(hunger)
			-- Don't starve a mother giving birth, for nicety reasons.
			if hunger >= 1.0 and goal ~= VillagerComponent.GOALS.CHILDBIRTH then
				local starvation = math.min(1.0, villager:getStarvation() + VillagerSystem.FOOD.STARVATION_PER_SECOND * dt)
				villager:setStarvation(starvation)
				if starvation >= 1.0 then
					print(entity, "died of hunger")
					self.engine:removeEntity(entity)
					return
				end

				if goal ~= VillagerComponent.GOALS.FOOD_PICKUP and
				   goal ~= VillagerComponent.GOALS.FOOD_DROPOFF and
				   goal ~= VillagerComponent.GOALS.SLEEP and
				   goal ~= VillagerComponent.GOALS.EAT then
					-- Villager needs to eat. Drop what yer doing.
					self:_stopAll(entity)
					self:_prepare(entity, true)
				end
			end
		end

		if not villager:isHome() or goal ~= VillagerComponent.GOALS.SLEEP then
			local sleepiness = math.min(1.0, villager:getSleepiness() + VillagerSystem.SLEEP.IDLE_GAIN_PER_SECOND * dt)
			villager:setSleepiness(sleepiness)
		end

		if goal == VillagerComponent.GOALS.NONE then
			if villager:getDelay() > 0.0 then
				villager:decreaseDelay(dt)

				if(villager:getDelay() > VillagerSystem.TIMERS.IDLE_FIDGET_MIN) then
					self:_fidget(entity)
				end
			else
				self:_takeAction(entity, dt)
			end
		end
	end
end

function VillagerSystem:_takeAction(entity)
	local villager = entity:get("VillagerComponent")
	local adult = entity:has("AdultComponent") and entity:get("AdultComponent")
	local starving = villager:getStarvation() > 0.0

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
			print(entity, "is sleepy")
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
		   state:getNumAvailableResources(ResourceComponent.BREAD) >= 1 then
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
	if not starving and adult and adult:getWorkPlace() then
		local workPlace = adult:getWorkPlace()
		local ti, tj = workPlace:get("PositionComponent"):getTile()

		self:_prepare(entity)

		if workPlace:has("ConstructionComponent") then
			local construction = workPlace:get("ConstructionComponent")

			-- Make a first pass to determine if any work can be carried out.
			local getMaterials, blacklist, resource = true, {}
			repeat
				resource = construction:getRemainingResources(blacklist)
				if not resource then
					-- Determine whether the construction needs any materials.
					if not construction:getRemainingResources() and construction:canBuild() then
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
			until resource and state:getNumAvailableResources(resource) > 0

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
	if not starving and adult and adult:getWorkArea() and
	       (adult:getOccupation() == WorkComponent.WOODCUTTER or
	        adult:getOccupation() == WorkComponent.MINER or
	        adult:getOccupation() == WorkComponent.FARMER) then
		-- This could be optimized through the map or something, but eh.
		local ti, tj = adult:getWorkArea()
		-- TODO: The order is somewhat random, but static. Do we want to randomise further, or calculate the
		-- closest one? (Mostly relevant for fields.)
		for _,workEntity in pairs(self.engine:getEntitiesWithComponent("WorkComponent")) do
			local assignment = workEntity:get("AssignmentComponent")
			local eti, etj = workEntity:get("PositionComponent"):getTile()
			if ti == eti and tj == etj and workEntity:get("WorkComponent"):getType() == adult:getOccupation() and
			   not workEntity:get("WorkComponent"):isComplete() and
			   assignment:getNumAssignees() < assignment:getMaxAssignees() then
				assignment:assign(entity)
				adult:setWorkPlace(workEntity)
				return -- Start working the next round.
			end
		end

		-- No such entity found. No work able to be carried out.
		if adult:getOccupation() == WorkComponent.FARMER then
			-- For farms, try again later.
			villager:setDelay(VillagerSystem.TIMERS.FARM_WAIT)
		else
			adult:setWorkArea(nil)
		end

		return
	end

	-- If the entity is waiting or walking around, let them do that.
	if entity:has("TimerComponent") or entity:has("WalkingComponent") then
		return
	end

	if villager:isHome() then
		-- Leave the house.
		self.eventManager:fireEvent(BuildingLeftEvent(villager:getHome(), entity))
		-- Move away from the door.
		self:_fidget(entity, true)
	else
		-- TODO: Walk closer to home, if wandered too far.
		self:_fidget(entity)
	end
end

function VillagerSystem:_fidget(entity, force)
	if force then
		self:_prepare(entity)
	end

	-- Wander around and fidget a little by rotating the villager.
	if not entity:has("TimerComponent") and not entity:has("WalkingComponent") then
		local villager = entity:get("VillagerComponent")
		local isAdult = entity:has("AdultComponent")

		local timer = love.math.random() *
		              (VillagerSystem.TIMERS.IDLE_FIDGET_MAX - VillagerSystem.TIMERS.IDLE_FIDGET_MIN) +
		              VillagerSystem.TIMERS.IDLE_FIDGET_MIN
		-- Make sure that the villager doesn't loiter on a reserved grid.
		if force or self.map:isGridReserved(entity:get("PositionComponent"):getGrid()) then
			force = true
			timer = 0
		end

		entity:add(TimerComponent(timer, function()
				local dir = villager:getDirection()
				villager:setDirection((dir + 45 * love.math.random(-1, 1)) % 360)
				entity:remove("TimerComponent")

				if force or love.math.random() < VillagerSystem.RAND.WANDER_FORWARD_CHANCE then
					-- XXX:
					local dirConv = require("src.game.worksystem").DIR_CONV[villager:getCardinalDirection()]

					local grid = entity:get("PositionComponent"):getGrid()
					local target = self.map:getGrid(grid.gi + dirConv[1], grid.gj + dirConv[2])
					if target then
						if self.map:isGridReserved(target) or
						   (not isAdult and love.math.random() < VillagerSystem.RAND.CHILD_DOUBLE_FORWARD_CHANCE) then
							target = self.map:getGrid(target.gi + dirConv[1], target.gj + dirConv[2]) or target
						end

						-- Don't bring the villager to an occupied or reserved grid.
						if self.map:isGridEmpty(target) and not self.map:isGridReserved(target) then
							entity:add(WalkingComponent(nil, nil, { target }, WalkingComponent.INSTRUCTIONS.WANDER))
						end
					end
				end
			end)
		)
	end
end

function VillagerSystem:_goToBuilding(entity, building, instructions)
	-- Assumes that _prepare() and everything else has been called.

	-- The entrance is an offset, so translate it to a real grid coordinate.
	local entrance = building:get("EntranceComponent"):getEntranceGrid()
	local grid = building:get("PositionComponent"):getGrid()
	local entranceGrid = self.map:getGrid(grid.gi + entrance.ogi, grid.gj + entrance.ogj)
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
	villager:setGoal(VillagerComponent.GOALS.EAT)

	local eating = 0.5
	dwelling:setFood(dwelling:getFood() - eating)
	local targetHunger = math.max(0.0, villager:getHunger() - eating)

	local timer = TimerComponent()
	timer:getTimer():during((villager:getHunger() - targetHunger) / VillagerSystem.FOOD.LOSS_PER_SECOND, function(dt)
		-- Decrease the hunger.
		villager:setHunger(math.max(0.0, villager:getHunger() - VillagerSystem.FOOD.LOSS_PER_SECOND * dt))
		-- Decrease the starvation.
		villager:setStarvation(math.max(0.0, villager:getStarvation() - VillagerSystem.FOOD.LOSS_PER_SECOND * dt))
	end, function()
		entity:remove("TimerComponent")
		entity:get("VillagerComponent"):setGoal(VillagerComponent.GOALS.NONE)
	end)
	entity:add(timer)

	return
end

function VillagerSystem:_sleep(entity)
	local villager = entity:get("VillagerComponent")

	assert(villager:isHome(), "Uh-oh")
	villager:setGoal(VillagerComponent.GOALS.SLEEP)

	local timer = TimerComponent()
	timer:getTimer():during(villager:getSleepiness() / VillagerSystem.SLEEP.LOSS_PER_SECOND, function(dt)
		-- Decrease the sleepiness.
		villager:setSleepiness(math.max(0.0, villager:getSleepiness() - VillagerSystem.SLEEP.LOSS_PER_SECOND * dt))
	end, function()
		entity:remove("TimerComponent")
		entity:get("VillagerComponent"):setGoal(VillagerComponent.GOALS.NONE)
	end)
	entity:add(timer)
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

	-- TODO: Set up the resource somewhere else.
	--       Preferably in ResourceSystem:onAddEntity()
	local gi, gj = grid.gi, grid.gj
	local ox, oy = self.map:gridToWorldCoords(gi, gj)
	ox = ox - self.map.halfGridWidth
	oy = oy - resourceEntity:get("SpriteComponent"):getSprite():getHeight() + self.map.gridHeight

	resourceEntity:get("SpriteComponent"):setDrawPosition(ox, oy)
	resourceEntity:add(PositionComponent(self.map:getGrid(gi, gj), nil, self.map:gridToTileCoords(gi, gj)))

	self.engine:addEntity(resourceEntity)
	state:increaseResource(resource, amount)
end

function VillagerSystem:_prepare(entity, okInside)
	-- Remove any lingering timer.
	if entity:has("TimerComponent") then
		entity:remove("TimerComponent")
	end

	-- Remove any walking instruction.
	if entity:has("WalkingComponent") then
		entity:remove("WalkingComponent")
	end

	-- Ensure that the villager is outside.
	if not okInside and entity:get("VillagerComponent"):isHome() then
		-- Leave the house.
		self.eventManager:fireEvent(BuildingLeftEvent(entity:get("VillagerComponent"):getHome(), entity))
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
				site:get("DwellingComponent"):removeChild(villager)
				if villager:getGender() == "male" then
					site:get("DwellingComponent"):setNumBoys(site:get("DwellingComponent"):getNumBoys() - 1)
				else
					site:get("DwellingComponent"):setNumGirls(site:get("DwellingComponent"):getNumGirls() - 1)
				end
			else
				self:unassignedEvent(UnassignedEvent(oldHome, entity))
			end
		end

		villager:setHome(site)

		-- Check if we there are any kids we need to bring with us.
		-- Divide up the children randomly (cause why not).
		for _,child in ipairs(villager:getChildren()) do
			local moveIn = false
			if oldHome then
				-- First, check to see if there is a parent left in the old home.
				if site:get("AssignmentComponent"):getNumAssignees() == 0 then
					moveIn = true
				else
					local villagerLeft = site:get("AssignmentComponent"):getAssignee()[1]
					if child:getMother() == villagerLeft or child:getFather() == villagerLeft then
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
					if child:get("VillagerComponent"):getGender() == "male" then
						oldHome:get("DwellingComponent"):setNumBoys(oldHome:get("DwellingComponent"):getNumBoys() - 1)
					else
						oldHome:get("DwellingComponent"):setNumGirls(oldHome:get("DwellingComponent"):getNumGirls() - 1)
					end
				end
			else
				-- Take the chance to actually LIVE.
				moveIn = true
			end

			if moveIn then
				child:get("VillagerComponent"):setHome(site)
				site:get("DwellingComponent"):addChild(child)
				if child:get("VillagerComponent"):getGender() == "male" then
					site:get("DwellingComponent"):setNumBoys(site:get("DwellingComponent"):getNumBoys() + 1)
				else
					site:get("DwellingComponent"):setNumGirls(site:get("DwellingComponent"):getNumGirls() + 1)
				end
			end
		end

		local assignees = site:get("AssignmentComponent"):getAssignees()
		local other = assignees[1] ~= entity and assignees[1] or assignees[2]
		if other then
			-- Set the related flag.
			-- This is done by checking for the parents and grandparents.
			-- TODO: This means that great-grandparents and great-uncles/aunts aren't considered related,
			--       but first cousins are.
			local related = { villager }
			local mother = villager:getMother()
			if mother then
				table.insert(related, mother)
				table.insert(related, mother:get("VillagerComponent"):getMother())
				table.insert(related, mother:get("VillagerComponent"):getFather())
			end
			local father = villager:getFather()
			if father then
				table.insert(related, father)
				table.insert(related, father:get("VillagerComponent"):getMother())
				table.insert(related, father:get("VillagerComponent"):getFather())
			end

			local isRelated = false
			for _,v in ipairs(related) do
				mother = other:get("VillagerComponent"):getMother()
				father = other:get("VillagerComponent"):getFather()

				if other == v then
					isRelated = true
					break
				elseif mother then
					if mother == v or
					   mother:get("VillagerComponent"):getMother() == v or
					   mother:get("VillagerComponent"):getFather() == v then
						isRelated = true
						break
					end
				elseif father then
					if father == v or
					   father:get("VillagerComponent"):getMother() == v or
					   father:get("VillagerComponent"):getFather() == v then
						isRelated = true
						break
					end
				end
			end

			site:get("DwellingComponent"):setRelated(isRelated)
		end
	else
		local workPlace = adult:getWorkPlace()

		if workPlace == site then
			-- If already working there, then nothing needs to be done.
			return
		elseif workPlace then
			self:unassignedEvent(UnassignedEvent(workPlace, entity))
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
		VillagerComponent.GOALS.FOOD_DROPOFF,
		VillagerComponent.GOALS.SLEEP,
		VillagerComponent.GOALS.EAT,
		VillagerComponent.GOALS.CHILDBIRTH
	}
	self.workRelatedGoals = self.workRelatedGoals or {
		VillagerComponent.GOALS.WORK_PICKUP,
		VillagerComponent.GOALS.WORK
	}

	if site:has("DwellingComponent") then
		site:get("AssignmentComponent"):unassign(entity)
		site:get("DwellingComponent"):setRelated(false) -- Can't be related to yourself!

		for _,goal in ipairs(self.homeRelatedGoals) do
			if villager:getGoal() == goal then
				self:_stopAll(entity)
				self:_prepare(entity)
				villager:setGoal(VillagerComponent.GOALS.NONE)
				break
			end
		end
	else
		for _,goal in ipairs(self.workRelatedGoals) do
			if villager:getGoal() == goal then
				self:_stopAll(entity)
				self:_prepare(entity)
				villager:setGoal(VillagerComponent.GOALS.NONE)
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

		entity:add(TimerComponent(VillagerSystem.TIMERS.BUILDING_TEMP_ENTER, function()
			entity:add(SpriteComponent())

			villager:setGoal(VillagerComponent.GOALS.NONE)
			if entity:has("WorkingComponent") then
				entity:remove("WorkingComponent")
			end
			entity:remove("TimerComponent")
		end))
	else
		entity:remove("SpriteComponent")
		entity:remove("PositionComponent")
		entity:remove("InteractiveComponent")

		if event:getBuilding():has("DwellingComponent") then
			villager:setIsHome(true)
		end
	end
end

function VillagerSystem:buildingLeftEvent(event)
	local entity = event:getVillager()
	local building = event:getBuilding()

	-- The entrance is an offset, so translate it to a real grid coordinate.
	-- TODO: DRY?
	local entrance = building:get("EntranceComponent"):getEntranceGrid()
	local grid = building:get("PositionComponent"):getGrid()
	local entranceGrid = self.map:getGrid(grid.gi + entrance.ogi, grid.gj + entrance.ogj)

	local villager = entity:get("VillagerComponent")

	if villager:getAge() >= VillagerSystem.ADULTHOOD and not entity:has("AdultComponent") then
		entity:add(AdultComponent()) -- TODO: Send user event
		entity:add(FertilityComponent())

		state:decreaseNumVillagers(villager:getGender(), false)
		state:increaseNumVillagers(villager:getGender(), true)
	elseif villager:getAge() >= VillagerSystem.SENIORHOOD and not entity:has("SeniorComponent") then
		entity:add(SeniorComponent())
		-- Change the hair.
		entity:get("ColorSwapComponent"):replace("hair",
			{ { 0.45, 0.45, 0.45, 1.0 },
			  { 0.55, 0.55, 0.55, 1.0 } })
	end

	villager:setIsHome(false)
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

	-- The child is created even if she didn't make it, so that the death animation can be played correctly.
	local child = blueprint:createVillager(entity, event:getFather())
	if event:wasIndoors() then
		child:remove("SpriteComponent") -- Don't need that.
		child:get("VillagerComponent"):setHome(villager:getHome())
		child:get("VillagerComponent"):setIsHome(true)

		local dwelling = villager:getHome():get("DwellingComponent")
		dwelling:addChild(child)
		if child:getGender() == "male" then
			dwelling:setNumBoys(dwelling:getNumBoys() + 1)
		else
			dwelling:setNumGirls(dwelling:getNumGirls() + 1)
		end
	else
		assert(not event:didChildSurvive(), "Don't know where to place the child.")
		local position = entity:get("PositionComponent")
		child:add(PositionComponent(position:getGrid(), nil, position:getTile()))
	end
	self.engine:addEntity(child)

	if not event:didChildSurvive() then
		self.engine:removeEntity(child, true)
	end

	if event:didMotherSurvive() then
		entity:add(TimerComponent(VillagerSystem.TIMERS.CHILDBIRTH_RECOVERY_DELAY, function()
			entity:remove("TimerComponent")
			entity:get("VillagerComponent"):setGoal(VillagerComponent.GOALS.NONE)
		end))
	else
		self.engine:removeEntity(entity, true)
	end
end

function VillagerSystem:onAddEntity(entity)
	state:increaseNumVillagers(entity:get("VillagerComponent"):getGender(), entity:has("AdultComponent"))
end

-- Called when a villager dies.
function VillagerSystem:onRemoveEntity(entity)
	local villager = entity:get("VillagerComponent")

	self:_stopAll(entity)
	self:_prepare(entity, true)

	state:decreaseNumVillagers(villager:getGender(), entity:has("AdultComponent"))

	-- Create a particle showing that a villager died.
	local grid, ti, tj
	if entity:has("PositionComponent") then
		-- Villager is outside.
		grid = entity:get("PositionComponent"):getGrid()
		ti, tj = entity:get("PositionComponent"):getTile()
	else
		-- XXX: Here comes the guessing game.
		local site
		if villager:isHome() then
			site = villager:getHome()
		else
			site = villager:getWorkPlace()
		end

		local from, to = site:get("PositionComponent"):getFromGrid(), site:get("PositionComponent"):getToGrid()
		grid = self.map:getGrid(from.gi + math.floor((to.gi - from.gi) / 2),
		                        from.gj + math.floor((to.gj - from.gj) / 2))
		ti, tj = site:get("PositionComponent"):getTile()
	end
	local particle = blueprint:createDeathParticle(entity)
	particle:set(PositionComponent(grid, nil, ti, tj))
	particle:get("SpriteComponent"):setDrawPosition(self.map:gridToWorldCoords(grid.gi, grid.gj))
	self.engine:addEntity(particle)

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
			dwelling:removeChild(villager)
			if villager:getGender() == "male" then
				dwelling:setNumBoys(dwelling:getNumBoys() - 1)
			else
				dwelling:setNumGirls(dwelling:getNumGirls() - 1)
			end
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

	-- The component isn't removed immediately, because it is used to determine ancestry to a certain degree.
	villager:setDead()

	-- Free the great-grandparents, if everyone is dead.
	-- TODO: Inefficient and incorrect. Can leave behind childless villagers,
	--       and cause other problems.
	local parents = {}
	table.insert(parents, villager:getMother())
	table.insert(parents, villager:getFather())
	local grandParents = {}
	for _,v in ipairs(parents) do
		v = v:get("VillagerComponent")
		if v:isDead() then
			table.insert(grandParents, v:getMother())
			table.insert(grandParents, v:getFather())
		end
	end
	for _,v in ipairs(grandParents) do
		v = v:get("VillagerComponent")
		if v:isDead() then
			-- TODO: A fair bit hacky, no?
			assert(not v:getMother() or v:getMother():get("VillagerComponent"):isDead(), "Great-grandmother not dead. :(")
			assert(not v:getFather() or v:getFather():get("VillagerComponent"):isDead(), "Great-grandfather not dead. :(")
			v:clear()
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
		timer:getTimer():after(VillagerSystem.TIMERS.DROPOFF_BEFORE, function()
			-- Second take that the grid is still empty...
			if not self.map:isGridEmpty(grid) then
				-- The default action will make sure we drop it somewhere else.
				villager:setGoal(VillagerComponent.GOALS.NONE)
				entity:remove("TimerComponent")
				return
			end

			-- Stop carrying the stuff.
			self:_dropCarrying(entity, grid)

			timer:getTimer():after(VillagerSystem.TIMERS.DROPOFF_AFTER, function()
				villager:setGoal(VillagerComponent.GOALS.NONE)
				entity:remove("TimerComponent")
			end)
		end)
		entity:add(timer)
	elseif goal == VillagerComponent.GOALS.WORK_PICKUP or
	       goal == VillagerComponent.GOALS.FOOD_PICKUP then
		local timer = TimerComponent()
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
				if goal == VillagerComponent.GOALS.WORK_PICKUP then
					entity:add(WalkingComponent(ti, tj, { event:getNextStop() }, WalkingComponent.INSTRUCTIONS.WORK))
					villager:setGoal(VillagerComponent.GOALS.WORK)
				else
					entity:add(WalkingComponent(ti, tj, { event:getNextStop() }, WalkingComponent.INSTRUCTIONS.GO_HOME))
					villager:setGoal(VillagerComponent.GOALS.FOOD_DROPOFF)
				end

				entity:remove("TimerComponent")
			end)
		end)
		entity:add(timer)
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
		local isBusy = goal ~= VillagerComponent.GOALS.NONE
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

			-- Three levels of priority for which grids to go to.
			local walkable = {
				{}, -- Free and unreserved.
				{}, -- Free but reserved.
				{}  -- Occupied
			}
			local here, there = entity:get("PositionComponent"):getGrid(), blocking:get("PositionComponent"):getGrid()
			-- Go to a random walkable direction that is not here.
			-- Not sure this randomness does anything...
			for _,gi in ipairs(table.shuffle({ -1, 0, 1 })) do
				for _,gj in ipairs(table.shuffle({ -1, 0, 1 })) do
					local grid = self.map:getGrid(there.gi + gi, there.gj + gj)
					if grid and grid ~= here and grid ~= there then
						if self.map:isGridEmpty(grid) then
							-- Maybe take two steps.
							if self.map:isGridReserved(grid) or love.math.random() < VillagerSystem.RAND.MOVE_DOUBLE_FORWARD_CHANCE then
								local newGrid = self.map:getGrid(grid.gi + gi, grid.gj + gj)
								grid = (newGrid and self.map:isGridEmpty(newGrid) and not self.map:isGridReserved(newGrid)) and newGrid or grid
							end

							if not self.map:isGridReserved(grid) then
								-- Free and unreserved.
								table.insert(walkable[1], grid)
							else
								-- Free but reserved.
								table.insert(walkable[2], grid)
							end
						elseif self.map:isGridWalkable(grid) then
							table.insert(walkable[3], grid)
						end
					end
				end
			end

			walkable = table.flatten(walkable)
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
			goal = villager:getGoal()
			villager:setGoal(VillagerComponent.GOALS.WAIT)
			-- Wait a second and try the exact same thing again.
			entity:set(TimerComponent(VillagerSystem.TIMERS.PATH_WAIT_DELAY, function()
				--self:_prepare(entity)
				local newWalking = WalkingComponent()
				for k,v in pairs(walking) do
					newWalking[k] = v
				end
				entity:add(newWalking)
				entity:remove("TimerComponent")
				entity:get("VillagerComponent"):setGoal(goal)
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
		print(entity, "has died of old age, at the age of "..villager:getAge()) -- TODO: Send event

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
		-- Don't increase the sleepiness of farmers (handled by the natural sleepiness).
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
