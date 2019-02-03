local astar = require "lib.ai.astar"
local lovetoys = require "lib.lovetoys.lovetoys"
local vector = require "lib.hump.vector"

local state = require "src.game.state"

local Map = require "src.game.map"
local TargetReachedEvent = require "src.game.targetreachedevent"
local WalkingComponent = require "src.game.walkingcomponent"

local WalkingSystem = lovetoys.System:subclass("WalkingSystem")

WalkingSystem.static.BASE_SPEED = 15
WalkingSystem.static.MIN_DISTANCE_SQUARED = 0.15

function WalkingSystem.requires()
	return {"WalkingComponent"}
end

function WalkingSystem:initialize(engine, eventManager, map)
	lovetoys.System.initialize(self)
	self.engine = engine
	self.eventManager = eventManager
	self.map = map
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
		local target, rotation, nextStop
		path, target, rotation, nextStop = self:_createPath(entity)
		assert(path, "TODO: No path") -- TODO
		walking:setPath(path)
		walking:setTargetEntity(target)
		walking:setTargetRotation(rotation)
		walking:setNextStop(nextStop)
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
			error("TODO: Something in the way")
		end

		self.map:reserve(entity, nextGrid)
		walking:setNextGrid(nextGrid)
	end

	-- Current ground position
	local cgx, cgy = entity:get("GroundComponent"):getPosition()
	-- Target ground position
	local tgx, tgy = self.map:gridToGroundCoords(nextGrid.gi + 0.5, nextGrid.gj + 0.5)

	local diff = vector(tgx - cgx, tgy - cgy)
	local delta = diff:normalized() * WalkingSystem.BASE_SPEED * villager:getSpeedModifier() * dt

	entity:get("GroundComponent"):setPosition(cgx + delta.x, cgy + delta.y)

	if nextGrid ~= oldGrid then
		-- New direction!
		villager:setDirection(self:_getRotation(entity:get("PositionComponent"):getPosition(), nextGrid))
	end

	if diff:len2() <= WalkingSystem.MIN_DISTANCE_SQUARED then
		self.map:unreserve(entity, entity:get("PositionComponent"):getPosition())
		entity:get("PositionComponent"):setPosition(nextGrid)
		walking:setNextGrid(nil)
	end
end

function WalkingSystem:_createPath(entity)
	local walking = entity:get("WalkingComponent")
	local villager = entity:get("VillagerComponent")

	local start = entity:get("PositionComponent"):getPosition()
	local path, targetEntity, targetRotation, nextStop

	if walking:getInstructions() == WalkingComponent.INSTRUCTIONS.DROPOFF then
		assert(entity:has("CarryingComponent"), "Can't drop off nothing.")

		local ti, tj = walking:getTargetTile()
		local gi, gj = self.map:getFreeGrid(ti, tj, entity:get("CarryingComponent"):getResource())
		assert(gi and gj, "TODO: No free grid to drop off.") -- TODO

		local target = self.map:getGrid(gi, gj)

		local nodes = astar.search(self.map, start, target)
		path = astar.reconstructReversedPath(start, target, nodes)
		assert(path and #path > 0, "TODO: No path to free resource.") -- TODO

		-- Last grid is the destination.
		local grid = table.remove(path, 1)

		targetEntity = grid
		targetRotation = self:_getRotation(path[1] or start, grid)
	elseif walking:getInstructions() == WalkingComponent.INSTRUCTIONS.WORK then
		local workGrid
		workGrid, path = self:_createClosestPath(function(item) return item[1] end, walking:getTargetGrids(), start)
		assert(path, "TODO: No path :(") -- TODO
		targetEntity = workGrid[1]
		targetRotation = workGrid[2]
	elseif walking:getInstructions() == WalkingComponent.INSTRUCTIONS.BUILD then
		--
		-- When building, we want to pick up a resource and walk it to the construction site.
		-- This part takes care of finding the shortest Manhattan distance to a resource and then to the construction
		-- site, and creating a path to the resource.
		--
		local workPlace = villager:getWorkPlace()
		assert(workPlace, "Can't build nothing.")

		local construction = workPlace:get("ConstructionComponent")
		local blacklist = {}

		local resource, count
		repeat
			resource, count = construction:getRemainingResources(blacklist)
			if not resource then
				assert(false, "TODO: No work can be carried out. Do something else.") -- TODO
				return nil
			end

			-- Don't count that resource again, in case we go round again.
			blacklist[resource] = true
		until state:getNumResources(resource) - state:getNumReservedResources(resource) > 0
		assert(count > 0, "No "..tostring(resource).." resource needed?!")

		local resourceNearest, resourcePath = self:_createClosestPath(
			"entity",
			self.engine:getEntitiesWithComponent("ResourceComponent"),
			start,
			workPlace:get("PositionComponent"):getPosition(),
			function(resourceEntity)
				local resourceComponent = resourceEntity:get("ResourceComponent")
				return resourceComponent:getResource() == resource and not resourceComponent:isUsable()
			end)

		assert(resourceNearest, "Available resource not reachable") -- FIXME: Do something smart.

		-- Remove the last grid, which is the location of the resource.
		table.remove(resourcePath, 1)

		-- Get a work space closest to the resource.
		local workNearest = self:_createClosestPath(
			function(item) return item[1] end,
			construction:getFreeWorkGrids(),
			resourceNearest:get("PositionComponent"):getPosition())

		assert(workNearest, "No path from resource to work grid.") -- FIXME: Do something smart.

		-- Reserve the resources.
		-- TODO: Track/cache which resource we have reserved, to
		-- make it easier to unreserve it once the villager does
		-- something else or dies?
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
		targetRotation = self:_getRotation(resourcePath[1] or start, resourceNearest:get("PositionComponent"):getPosition())
		nextStop = workNearest
	else
		error("Don't know how to walk.")
	end

	if path then
		-- Get rid of the starting (current) grid.
		table.remove(path)
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
					grid = entity:get("PositionComponent"):getPosition()
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
		local nodes = astar.search(self.map, start, target)
		path = astar.reconstructReversedPath(start, target, nodes)

		target.collision = oldCollision

		if #path > 0 then
			-- Get rid of the starting (current) grid.
			table.remove(path)
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

return WalkingSystem
