local astar = require "lib.ai.astar"
local lovetoys = require "lib.lovetoys.lovetoys"
local vector = require "lib.hump.vector"

local EntityMovedEvent = require "src.game.entitymovedevent"
local TargetReachedEvent = require "src.game.targetreachedevent"
local TargetUnreachableEvent = require "src.game.targetunreachableevent"

local Map = require "src.game.map"
local ResourceComponent = require "src.game.resourcecomponent"
local TileComponent = require "src.game.tilecomponent"
local TimerComponent = require "src.game.timercomponent"
local WalkingComponent = require "src.game.walkingcomponent"

local state = require "src.game.state"

local WalkingSystem = lovetoys.System:subclass("WalkingSystem")

-- Distance squared before the grid is changed to the next one.
WalkingSystem.static.DISTANCE_CHANGE_GRID = 10
-- Distance squared before a new next grid is retrieved.
WalkingSystem.static.DISTANCE_NEXT_GRID = 0.05
-- How often to recalculate the path.
WalkingSystem.static.RECALC_DELAY = 5

-- Unmodified walking speed.
WalkingSystem.static.BASE_SPEED = 20
-- Multiplicative speed modifiers.
WalkingSystem.static.SPEED_MODIFIER = {
	-- Walking on grass.
	[TileComponent.GRASS] = 1.0,
	-- Walking in the forest.
	[TileComponent.FOREST] = 0.8,
	-- Walking in the mountains.
	[TileComponent.MOUNTAIN] = 0.9,
	-- Carrying 1, 2, or 3 things.
	CARRYING = {
		[1] = 0.95,
		[2] = 0.9,
		[3] = 0.85
	},
	-- Being a child.
	CHILD = 1.2,
	-- Being an adult.
	ADULT = 1.0,
	-- Being a senior.
	SENIOR = 0.8
}

function WalkingSystem.requires()
	return {"WalkingComponent"}
end

function WalkingSystem:initialize(engine, eventManager, map)
	lovetoys.System.initialize(self)
	self.engine = engine
	self.eventManager = eventManager
	self.map = map
end

function WalkingSystem:onRemoveEntity(entity)
	-- Unoccupy any reserved grids.
	local nextGrid = entity:get("WalkingComponent"):getNextGrid()
	if nextGrid and entity:get("PositionComponent"):getGrid() ~= nextGrid then
		self.map:unoccupy(entity, entity:get("WalkingComponent"):getNextGrid())
	end
end

function WalkingSystem:update(dt)
	for _,entity in pairs(self.targets) do
		self:_walkTheWalk(entity, dt)
	end
end

function WalkingSystem:_walkTheWalk(entity, dt)
	local walking = entity:get("WalkingComponent")
	local villager = entity:get("VillagerComponent")

	local path = walking:getPath()

	if not path then
		-- Initialise the path
		if not self:_initiatePath(entity) then
			--print("No path to thing")
			self.eventManager:fireEvent(TargetUnreachableEvent(entity, nil, false, walking:getInstructions()))
			entity:remove("WalkingComponent")
			return
		end

		path = walking:getPath()

		-- Add a timer to recalculate the path regularly, to be more up to date with ones surroundings.
		--[[ TODO: Reimplement
		if walking:getInstructions() ~= WalkingComponent.INSTRUCTIONS.WANDER and
		   walking:getInstructions() ~= WalkingComponent.INSTRUCTIONS.GET_OUT_THE_WAY then
			if not entity:has("TimerComponent") then
				local timer = TimerComponent()
				timer:getTimer():every(WalkingSystem.RECALC_DELAY, function()
					local oldPath = walking:getPath()
					if oldPath and oldPath[1] then
						local start = walking:getNextGrid() or entity:get("PositionComponent"):getGrid()
						local newPath = self:_calculatePath(start, path[1])
						if newPath then
							walking:setPath(newPath)
						end
					end
				end)
				entity:add(timer)
			else
				print("Timer for instruction "..walking:getInstructions())
			end
		end
		--]]
	end

	local nextGrid = walking:getNextGrid()
	local oldGrid = nextGrid

	if not nextGrid then
		nextGrid = table.remove(path)
		if not nextGrid then
			self.eventManager:fireEvent(
				TargetReachedEvent(entity, walking:getTargetEntity(), walking:getTargetRotation(), walking:getNextStop()))
			entity:remove("WalkingComponent")
			return
		elseif not self.map:isGridEmpty(nextGrid) then
			-- Put back the next grid into the path, so that the things listening to the event can get the whole picture.
			table.insert(path, nextGrid)
			-- Do two takes, sending two events if necessary.
			for i=1,2 do
				local newPath
				local retry = i == 1 and path[1] ~= nextGrid
				local event = TargetUnreachableEvent(entity,
				                                     self.map:getOccupyingVillager(nextGrid),
				                                     retry,
				                                     walking:getInstructions())
				self.eventManager:fireEvent(event)
				if path[1] == nextGrid then
					print(entity, "Next is the destination :(")
				end

				if event:shouldRetry() then
					print(entity, "Trying new path")
					-- XXX: The next grid might be walkable, but blocked by a villager. Change that temporarily.
					local oldCollision = nextGrid.collision
					nextGrid.collision = Map.COLL_STATIC

					-- Calculate a new path, in case that is enough.
					newPath = self:_calculatePath(entity:get("PositionComponent"):getGrid(), path[1])

					nextGrid.collision = oldCollision
				end

				if newPath and #newPath > 1 then
					print(entity, "New path!")
					-- Set up movement to the next point, without breaking stride.
					table.remove(newPath) -- Current grid
					walking:setPath(newPath)
					nextGrid = table.remove(newPath)
					assert(nextGrid, "Recalculated path should not be empty.")
					break
				elseif not event:shouldRetry() then
					entity:remove("WalkingComponent")
					return
				end
			end
		end

		self.map:occupy(entity, nextGrid)
		walking:setNextGrid(nextGrid)
	end

	-- Current ground position
	local cgx, cgy = entity:get("GroundComponent"):getPosition()
	-- Target ground position
	local tgx, tgy = self.map:gridToGroundCoords(nextGrid.gi + 0.5, nextGrid.gj + 0.5)

	local diff = vector(tgx - cgx, tgy - cgy)
	local delta = diff:normalized() * WalkingSystem.BASE_SPEED * walking:getSpeedModifier() * dt

	entity:get("GroundComponent"):setPosition(cgx + delta.x, cgy + delta.y)

	if nextGrid ~= oldGrid then
		-- New direction!
		villager:setDirection(self:_getRotation(entity:get("PositionComponent"):getGrid(), nextGrid))
	end

	local len = diff:len2()
	if len <= WalkingSystem.DISTANCE_CHANGE_GRID then
		if entity:get("PositionComponent"):getGrid() ~= nextGrid then
			self.map:unoccupy(entity, entity:get("PositionComponent"):getGrid())
			entity:get("PositionComponent"):setGrid(nextGrid)
			entity:get("PositionComponent"):setTile(self.map:gridToTileCoords(nextGrid.gi, nextGrid.gj))

			self.eventManager:fireEvent(EntityMovedEvent(entity, nextGrid))

			-- New terrain?
			self:_updateWalkingSpeed(entity)
		end

		if len <= WalkingSystem.DISTANCE_NEXT_GRID then
			walking:setNextGrid(nil)
		end
	end
end

--
-- Internal functions
--

function WalkingSystem:_initiatePath(entity)
	local path, target, rotation, nextStop = self:_createPath(entity)
	if path then
		local walking = entity:get("WalkingComponent")
		walking:setPath(path)
		walking:setTargetEntity(target)
		walking:setTargetRotation(rotation)
		walking:setNextStop(nextStop)
		self:_updateWalkingSpeed(entity)

		return true
	end

	return false
end

function WalkingSystem:_calculatePath(start, target)
	-- Make an initial check that we're actually going somewhere.
	if start == target then
		return {}
	end

	local nodes = astar.search(self.map, start, target)
	local path = astar.reconstructReversedPath(start, target, nodes)

	if path and #path > 1 then
		table.remove(path) -- Current grid
		return path
	end

	return nil
end

function WalkingSystem:_createPath(entity)
	local walking = entity:get("WalkingComponent")

	local start = entity:get("PositionComponent"):getGrid()
	local path, targetEntity, targetRotation, nextStop
	local instruction = walking:getInstructions()

	if instruction == WalkingComponent.INSTRUCTIONS.DROPOFF then
		assert(entity:has("CarryingComponent"), "Can't drop off nothing.")

		local ti, tj = walking:getTargetTile()
		local target = self.map:getFreeGrid(ti, tj, entity:get("CarryingComponent"):getResource())
		if not target then
			return nil
		end

		path = self:_calculatePath(start, target)
		if not path then
			return nil
		end

		-- Last grid is the destination.
		local grid = table.remove(path, 1)

		targetEntity = grid
		targetRotation = self:_getRotation(path[1] or start, grid)
	elseif instruction == WalkingComponent.INSTRUCTIONS.WORK then
		local workGrid
		workGrid, path = self:_createClosestPath(function(item) return item[1] end, walking:getTargetGrids(), start)
		if not path then
			return nil
		end
		targetEntity = workGrid[1]
		targetRotation = workGrid[2]
	elseif instruction == WalkingComponent.INSTRUCTIONS.BUILD then
		--
		-- When building, we want to pick up a resource and walk it to the construction site.
		-- This part takes care of finding the shortest Manhattan distance to a resource and then to the construction
		-- site, and creating a path to the resource.
		--
		local workPlace = entity:get("AdultComponent"):getWorkPlace()
		assert(workPlace, "Can't build nothing.")

		local construction = workPlace:get("ConstructionComponent")
		local blacklist, resource, count = {}
		repeat
			resource, count = construction:getRandomUnreservedResource(blacklist)
			if not resource then
				-- No work can be carried out. Do something else.
				return nil
			end

			-- Don't count that resource again, in case we go round again.
			blacklist[resource] = true
		until state:getNumAvailableResources(resource) > 0
		assert(count > 0, "No "..tostring(resource).." resource needed?!")

		local resourceNearest, resourcePath = self:_createClosestPath(
			"entity",
			self.engine:getEntitiesWithComponent("ResourceComponent"),
			start,
			workPlace:get("PositionComponent"):getGrid(),
			function(resourceEntity)
				local resourceComponent = resourceEntity:get("ResourceComponent")
				return resourceComponent:getResource() == resource and resourceComponent:isUsable()
			end)

		if not resourceNearest then
			return nil -- FIXME: Do something smart.
		end

		-- Remove the last grid, which is the location of the resource.
		table.remove(resourcePath, 1)

		-- Get a work space closest to the resource.
		local workNearest = self:_createClosestPath(
			function(item) return item[1] end,
			construction:getFreeWorkGrids(),
			resourceNearest:get("PositionComponent"):getGrid())

		if not workNearest then
			return nil -- FIXME: Do something smart.
		end

		-- Reserve the resources.
		local pickupAmount = math.min(count, resourceNearest:get("ResourceComponent"):getResourceAmount())
		resourceNearest:get("ResourceComponent"):setReserved(entity, pickupAmount)
		construction:reserveResource(resource, pickupAmount)
		state:reserveResource(resource, pickupAmount)

		-- TODO: If less than 3 resources, look for more resources
		-- (from the last resource). (ALT: Do this when picking up
		-- the resource instead, since things might change (more
		-- resource available nearby, etc.).)

		-- Reserve the work grid.
		construction:reserveGrid(entity, workNearest)

		path = resourcePath
		targetEntity = resourceNearest
		targetRotation = self:_getRotation(resourcePath[1] or start, resourceNearest:get("PositionComponent"):getGrid())
		nextStop = workNearest
	elseif instruction == WalkingComponent.INSTRUCTIONS.PRODUCE then
		--
		-- When producing, we want to pick up a resource and walk it to the work site.
		-- This part takes care of finding the shortest Manhattan distance to a resource and then to the work
		-- site, and creating a path to the resource.
		--
		local workPlace = entity:get("AdultComponent"):getWorkPlace()
		assert(workPlace, "Can't produce nothing.")

		local production = workPlace:get("ProductionComponent")
		local blacklist, resource, count = {}
		repeat
			resource, count = production:getNeededResources(entity, blacklist)
			if not resource then
				-- No work can be carried out. Do something else.
				return nil
			end

			-- Don't count that resource again, in case we go round again.
			blacklist[resource] = true
		until state:getNumAvailableResources(resource) > 0
		assert(count > 0, "No "..tostring(resource).." resource needed?!")

		local resourceNearest, resourcePath = self:_createClosestPath(
			"entity",
			self.engine:getEntitiesWithComponent("ResourceComponent"),
			start,
			workPlace:get("PositionComponent"):getGrid(),
			function(resourceEntity)
				local resourceComponent = resourceEntity:get("ResourceComponent")
				return resourceComponent:getResource() == resource and resourceComponent:isUsable()
			end)

		if not resourceNearest then
			return nil -- FIXME: Do something smart.
		end

		-- Remove the last grid, which is the location of the resource.
		table.remove(resourcePath, 1)

		-- Reserve the resources.
		local pickupAmount = math.min(count, resourceNearest:get("ResourceComponent"):getResourceAmount())
		resourceNearest:get("ResourceComponent"):setReserved(entity, pickupAmount)
		state:reserveResource(resource, pickupAmount)

		-- TODO: If less than 3 resources, look for more resources
		-- (from the last resource). (ALT: Do this when picking up
		-- the resource instead, since things might change (more
		-- resource available nearby, etc.).)

		path = resourcePath
		targetEntity = resourceNearest
		targetRotation = self:_getRotation(resourcePath[1] or start, resourceNearest:get("PositionComponent"):getGrid())
		nextStop = walking:getTargetGrids()
	elseif instruction == WalkingComponent.INSTRUCTIONS.GET_FOOD then
		--
		-- When getting food, we want to pick up a piece of bread and walk it to our home.
		-- This part takes care of finding the shortest Manhattan distance to a resource and then to the work
		-- site, and creating a path to the resource.
		--
		local home = assert(entity:get("VillagerComponent"):getHome(), "No home to bring the food back to.")
		local resource = ResourceComponent.BREAD

		local resourceNearest, resourcePath = self:_createClosestPath(
			"entity",
			self.engine:getEntitiesWithComponent("ResourceComponent"),
			start,
			home:get("PositionComponent"):getGrid(),
			function(resourceEntity)
				local resourceComponent = resourceEntity:get("ResourceComponent")
				return resourceComponent:getResource() == resource and resourceComponent:isUsable()
			end)

		if not resourceNearest then
			return nil
		end

		-- Remove the last grid, which is the location of the resource.
		table.remove(resourcePath, 1)

		-- Reserve the resources.
		local pickupAmount = 1
		resourceNearest:get("ResourceComponent"):setReserved(entity, pickupAmount)
		state:reserveResource(resource, pickupAmount)

		path = resourcePath
		targetEntity = resourceNearest
		targetRotation = self:_getRotation(resourcePath[1] or start, resourceNearest:get("PositionComponent"):getGrid())
		nextStop = walking:getTargetGrids()[1]
	elseif instruction == WalkingComponent.INSTRUCTIONS.WANDER or
	       instruction == WalkingComponent.INSTRUCTIONS.GO_HOME or
	       instruction == WalkingComponent.INSTRUCTIONS.GET_OUT_THE_WAY then
		local target = walking:getTargetGrids()[1]
		path = self:_calculatePath(start, target)
	else
		error("Don't know how to walk: "..tostring(instruction))
	end

	return path, targetEntity, targetRotation, nextStop
end

function WalkingSystem:_createClosestPath(extract, entities, start, goal, check)
	local nearest, target, path
	local blacklist = {}

	while true do
		local minCost = math.huge
		nearest, path = nil, nil

		for _,entity in pairs(entities) do
			if not blacklist[entity] and (not check or check(entity)) then
				local grid
				if extract == "entity" then
					grid = entity:get("PositionComponent"):getGrid()
				elseif extract == "grid" then
					grid = entity
				else
					grid = extract(entity)
				end

				local cost = self.map:heuristic(start, grid)
				if goal then
					cost = cost + self.map:heuristic(grid, goal)
				end

				if cost < minCost then
					nearest = entity
					minCost = cost
					target = grid
				end
			end
		end
		-- No entity matching the criteria.
		if nearest == nil then
			break
		end

		blacklist[nearest] = true

		-- XXX: The target might not be walkable (a resource), so temporarily change that...
		local oldCollision = target.collision
		target.collision = Map.COLL_NONE

		-- Create a path to the target, to ensure it can be reached.
		path = self:_calculatePath(start, target)

		target.collision = oldCollision

		if path then
			break
		end
	end

	return nearest, path
end

function WalkingSystem:_getRotation(last, target)
	local diff = vector(target.gi - last.gi, target.gj - last.gj)

	-- Note! Y is negative up.
	local r = math.atan2(diff.x, -diff.y)
	-- Note! The ground coordinates are not isometric, so to
	-- convert the direction from orthogonal to isometric, we
	-- simply add 45 degrees to the angle (and make sure it is
	-- between 0-359).
	return (math.deg(r) + 360 + 45) % 360
end

function WalkingSystem:_updateWalkingSpeed(entity)
	local grid = entity:get("PositionComponent"):getGrid()

	-- Modify walking speed based on terrain.
	local ti, tj = self.map:gridToTileCoords(grid.gi, grid.gj)
	local speedModifier = WalkingSystem.SPEED_MODIFIER[self.map:getTile(ti, tj).type]

	-- Modify walking speed based on carried stuff.
	if entity:has("CarryingComponent") then
		speedModifier = speedModifier * WalkingSystem.SPEED_MODIFIER.CARRYING[entity:get("CarryingComponent"):getAmount()]
	end

	-- Modify walking speed based on age.
	if entity:has("SeniorComponent") then
		speedModifier = speedModifier * WalkingSystem.SPEED_MODIFIER.SENIOR
	elseif entity:has("AdultComponent") then
		speedModifier = speedModifier * WalkingSystem.SPEED_MODIFIER.ADULT
	else
		speedModifier = speedModifier * WalkingSystem.SPEED_MODIFIER.CHILD
	end

	entity:get("WalkingComponent"):setSpeedModifier(speedModifier)
end

return WalkingSystem
