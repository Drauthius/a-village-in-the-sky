local astar = require "lib.ai.astar"
local lovetoys = require "lib.lovetoys.lovetoys"
local vector = require "lib.hump.vector"

local Map = require "src.game.map"
local VillagerComponent = require "src.game.villagercomponent"
local WorkComponent = require "src.game.workcomponent"

local state = require "src.game.state"

local VillagerSystem = lovetoys.System:subclass("VillagerSystem")

VillagerSystem.static.BASE_SPEED = 15
VillagerSystem.static.MIN_DISTANCE = 0.1

VillagerSystem.static.timers = {
	PICKUP_BEFORE = 0.25,
	PICKUP_AFTER = 0.5
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
		local villager = entity:get("VillagerComponent")
		local villagerState = villager:getState()
		local villagerAction = villager:getAction()

		villager:increaseTimer(dt)

		if villagerState == VillagerComponent.states.IDLE then
			if villager:getWorkPlace() then
				assert(not villager:isCarrying(), "Should not carry anything in the idle state")

				villager:setState(VillagerComponent.states.WORKING, VillagerComponent.actions.WALKING)
				local workPlace = villager:getWorkPlace()
				local start = entity:get("PositionComponent"):getPosition()
				local target = workPlace:get("PositionComponent"):getPosition()

				local stops = { {
					action = VillagerComponent.actions.WORKING,
					target = workPlace, -- Entity
					targetGrid = nil, -- Grid
					rotation = nil -- The rotation when reaching the grid
				} }

				if villager:getOccupation() == WorkComponent.BUILDER then
					local construction = workPlace:get("UnderConstructionComponent")
					local blacklist = {}

					local resource, count
					repeat
						resource, count = construction:getRemainingResources(blacklist)
						if not resource then
							villager:setWorkPlace()
							villager:setState(VillagerComponent.states.IDLE, VillagerComponent.actions.IDLE)
							return
						end

						-- Don't count that resource again, in case we go round again.
						blacklist[resource] = true
					until state:getNumResources(resource) - state:getNumReservedResources(resource) > 0
					assert(count > 0, "No "..tostring(resource).." resource needed?!")

					local resourceNearest, resourcePath = self:_createClosestPath(
						"entity",
						self.engine:getEntitiesWithComponent("ResourceComponent"),
						start,
						target,
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

					-- Update the last stop with our reserved grid.
					stops[1].targetGrid = workNearest[1]
					stops[1].rotation = workNearest[2]

					-- Push the pickup to the back of the stops.
					table.insert(stops,
						{
							action = VillagerComponent.actions.PICKUP,
							target = resourceNearest,
							targetGrid = resourceNearest:get("PositionComponent"):getPosition(),
							rotation = self:_getRotation(resourcePath[1] or start, resourceNearest:get("PositionComponent"):getPosition())
						})
					resourcePath.stops = stops
					villager:setPath(resourcePath)
				else
					local workGrids = workPlace:get("WorkComponent"):getWorkGrids()
					assert(workGrids, "No grid information for workplace "..workPlace:get("WorkComponent"):getTypeName())

					local grids = {}
					for _,workGrid in ipairs(workGrids) do
						table.insert(grids, { self.map:getGrid(target.gi + workGrid.ogi, target.gj + workGrid.ogj), workGrid.rotation })
					end

					local workGrid, path = self:_createClosestPath(function(item) return item[1] end, grids, start)

					if not path then
						error("TODO: No path :(") -- TODO
					end

					stops[1].targetGrid = workGrid[1]
					stops[1].rotation = workGrid[2]

					path.stops = stops
					villager:setPath(path)
				end
			else
				local dir = villager:getDirection()
				dir = (dir + 2) % 360
				villager:setDirection(dir)
			end
		elseif villagerState == VillagerComponent.states.WORKING then
			if villagerAction == VillagerComponent.actions.WALKING then
				local path = villager:getPath()
				local nextGrid = path.nextGrid
				local oldGrid = nextGrid

				if not nextGrid then
					-- New grid
					nextGrid = table.remove(path)
					if not nextGrid then
						local stopNum = #path.stops
						villager:setAction(path.stops[stopNum].action)
						villager:resetTimer()
						villager:setDirection(path.stops[stopNum].rotation)
						if stopNum <= 1 then
							villager:setPath(nil)
						end

						if villager:isCarrying() then
							local amount, resource = villager:getCarrying()
							state:removeReservedResource(resource, amount)
							state:decreaseResource(resource, amount)
							villager:getWorkPlace():get("UnderConstructionComponent"):addResources(resource, amount)
							villager:carry(nil)
						end

						return
					elseif not self.map:isGridEmpty(nextGrid) then
						print("Something in the way")

						-- XXX: The next grid might be walkable (but blocked by another villager), so temporarily change that...
						local oldCollision = nextGrid.collision
						nextGrid.collision = Map.COLL_STATIC

						-- Create a path to the target, to ensure it can be reached.
						local start = entity:get("PositionComponent"):getPosition()
						local target = path[1]
						local nodes = astar.search(self.map, start, target)
						local newPath = astar.reconstructReversedPath(start, target, nodes)

						for _,grid in ipairs(newPath) do
							assert(nextGrid ~= grid, "NO WAY!")
						end

						nextGrid.collision = oldCollision

						if #newPath < 1 then
							error("Could not access target :(")
						end

						-- Get rid of the starting (current) grid.
						table.remove(newPath)
						newPath.stops = path.stops
						villager:setPath(newPath)

						return
					end

					self.map:reserve(entity, nextGrid)
					path.nextGrid = nextGrid
				end

				-- Current ground position
				local cgx, cgy = entity:get("GroundComponent"):getPosition()
				-- Target ground position
				local tgx, tgy = self.map:gridToGroundCoords(nextGrid.gi + 0.5, nextGrid.gj + 0.5)

				local diff = vector(tgx - cgx, tgy - cgy)
				local delta = diff:normalized() * VillagerSystem.BASE_SPEED * villager:getSpeedModifier() * dt

				entity:get("GroundComponent"):setPosition(cgx + delta.x, cgy + delta.y)

				if nextGrid ~= oldGrid then
					-- New direction!
					villager:setDirection(self:_getRotation(entity:get("PositionComponent"):getPosition(), nextGrid))
				end

				if diff:len2() <= VillagerSystem.MIN_DISTANCE then
					self.map:unreserve(entity, entity:get("PositionComponent"):getPosition())
					entity:get("PositionComponent"):setPosition(nextGrid)
					path.nextGrid = nil
				end
			elseif villagerAction == VillagerComponent.actions.PICKUP then
				local path = villager:getPath()
				local stop = path.stops[#path.stops]

				if villager:getTimer() < VillagerSystem.timers.PICKUP_AFTER then
					if villager:getTimer() < VillagerSystem.timers.PICKUP_BEFORE then
						villager:setDirection(stop.rotation)
						return
					end

					if stop.action == villagerAction then
						-- Start carrying the stuff.
						local resourceEntity = stop.target
						local resource = resourceEntity:get("ResourceComponent")
						villager:carry(resource:getReservedAmount(), resource:getResource())
						resource:decreaseAmount(resource:getReservedAmount())

						if resource:getResourceAmount() < 1 then
							-- Remove it from the engine.
							self.engine:removeEntity(resourceEntity, true)
						else
							-- Sprite component needs to be updated.
							resourceEntity:get("SpriteComponent"):setNeedsRefresh(true)
							resource:setReserved(nil)
						end

						-- Go next.
						table.remove(path.stops)
						assert(path.stops[1], "Ran out of stops!")
						--local nextPath = self:_getPathToStop(entity:get("PositionComponent"):getPosition(), path.stops)
						local start, target = entity:get("PositionComponent"):getPosition(), path.stops[1].targetGrid
						local nodes = astar.search(self.map, start, target)
						local nextPath = astar.reconstructReversedPath(start, target, nodes)

						if not nextPath then
							error("TODO: No path :(") -- TODO
						end

						table.remove(nextPath)
						nextPath.stops = path.stops
						villager:setPath(nextPath)
					end
				else
					villager:setAction(VillagerComponent.actions.WALKING)
					villager:resetTimer()
				end
			end
		end
	end
end

function VillagerSystem:_createClosestPath(extract, entities, start, goal, check)
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

function VillagerSystem:_getRotation(last, target)
	local diff = vector(target.gi - last.gi, target.gj - last.gj)

	-- Note! Y is negative up.
	local r = math.atan2(diff.x, -diff.y)
	-- Note! The ground coordinates are not isometric, so to
	-- convert the direction from orthogonal to isometric, we
	-- simply add 45 degrees to the angle (and make sure it is
	-- between 0-359).
	return (math.deg(r) + 360 + 45) % 360
end

return VillagerSystem
