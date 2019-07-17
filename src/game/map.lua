local class = require "lib.middleclass"

local bit = require "bit"

local BuildingComponent = require "src.game.buildingcomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local TileComponent = require "src.game.tilecomponent"

-- Throughout this class, "grid" refers to the collision isometric squares, and "tile"
-- refers to the bigger isometric squares (sprites). That being said, "gi" and "gj"
-- refers to the former, while "ti" and "tj" refers to the latter. There are other
-- coordinate systems in use here as well, for example "ground" coordinates, which is the
-- orthogonal coordinates used by villagers. They use "gx" and "gy" for those
-- coordinates.
local Map = class("Map")

-- Bitmask
Map.static.COLL_NONE = 0 -- No collision
Map.static.COLL_STATIC = 1 -- Building/resource
Map.static.COLL_DYNAMIC = 2 -- Villager
Map.static.COLL_RESERVED = 4 -- OK to walk, but please don't loiter.

-- How much more work it is to push a villager than go around them.
Map.static.OCCUPIED_MULTIPLIER = 10

function Map:initialize()
	self.tile = {}
	self.grid = {}

	self.firstTile = { 0, 0 }
	self.lastTile = { -1, -1 }

	-- Tile width in pixels
	self.tileWidth = 128
	self.halfTileWidth = self.tileWidth / 2
	-- Tile height in pixels
	self.tileHeight = self.tileWidth / 2
	self.halfTileHeight = self.tileHeight / 2

	-- Number of grids per tile (width * height)
	self.gridsPerTile = 16
	-- Grid width in pixels
	self.gridWidth = 8
	self.halfGridWidth = self.gridWidth / 2
	-- Grid height in pixels
	self.gridHeight = 4
	self.halfGridHeight = self.gridHeight / 2
end

function Map:addTile(type, ti, tj)
	if not self.tile[ti] then
		self.tile[ti] = {}
	end

	assert(not self.tile[ti][tj], "Tile already existed")
	self.tile[ti][tj] = { type = type }

	if self.firstTile[1] > ti then
		self.firstTile[1] = ti
	end
	if self.lastTile[1] < ti then
		self.lastTile[1] = ti
	end
	if self.firstTile[2] > tj then
		self.firstTile[2] = tj
	end
	if self.lastTile[2] < tj then
		self.lastTile[2] = tj
	end

	-- Add the walkable grids
	local sgi, sgj = self:tileToGridCoords(ti, tj)
	for gi=sgi,sgi + self.gridsPerTile - 1 do
		self.grid[gi] = self.grid[gi] or {}

		for gj=sgj,sgj + self.gridsPerTile - 1 do
			self.grid[gi][gj] = {
				gi = gi,
				gj = gj,
				tile = self.tile[ti][tj],
				collision = Map.COLL_NONE
			}
			-- Mark the edge as reserved.
			if gi == sgi or gi == sgi + self.gridsPerTile - 1 or gj == sgj or gj == sgj + self.gridsPerTile - 1 then
				self.grid[gi][gj].collision = Map.COLL_RESERVED
			end
		end
	end
end

function Map:addObject(entity, i, j)
	local collision = entity:get("CollisionComponent"):getCollisionSprite()

	if collision:getWidth() == self.tileWidth then
		local ti, tj = i, j

		if not self:_placeFullWidthObject(entity, ti, tj, true) then
			return nil
		end

		return self:_placeFullWidthObject(entity, ti, tj)
	else
		local gi, gj = i, j
		if not self:_placeObject(entity, gi, gj, true) then
			return nil
		end

		return self:_placeObject(entity, gi, gj)
	end
end

function Map:occupy(villager, grid)
	-- TODO: Villagers can walk over other villagers in certain circumstances.
	if not grid.occupied then
		grid.collision = bit.bor(grid.collision, Map.COLL_DYNAMIC)
		grid.occupied = villager
	end
end

function Map:unoccupy(villager, grid)
	if grid.occupied == villager then
		grid.collision = bit.band(grid.collision, bit.bnot(Map.COLL_DYNAMIC))
		grid.occupied = nil
	end
end

function Map:getOccupyingVillager(grid)
	return grid.occupied
end

function Map:addResource(resource, grid, force)
	grid.collision = Map.COLL_STATIC
	assert(force or (not grid.owner and not grid.occupied), "Overlap")
	grid.owner = resource
end

-- Remove a resource or building from the map.
function Map:remove(entity)
	for _,grid in ipairs(self:getOwnedGrids(entity, true)) do
		grid.collision = bit.band(grid.collision, bit.bnot(Map.COLL_STATIC))
		grid.collision = bit.band(grid.collision, bit.bnot(Map.COLL_RESERVED))
		grid.owner = nil
	end
end

function Map:getOwnedGrids(entity, includeReserved)
	local grids = {}

	if includeReserved then
		-- NOTE: Static collisions are guaranteed to be square, but reserved parts fall outside of that.
		for grid in self:_eachGrid(entity:get("PositionComponent"):getTile()) do
			if grid.owner == entity then
				table.insert(grids, grid)
			end
		end
	else
		-- NOTE: Assumes that all collisions are square.
		local from, to = entity:get("PositionComponent"):getFromGrid(), entity:get("PositionComponent"):getToGrid()

		for gi=from.gi,to.gi do
			for gj=from.gj,to.gj do
				local grid = self:getGrid(gi, gj)
				if grid.owner == entity then
					table.insert(grids, grid)
				end
			end
		end
	end

	return grids
end

function Map:getAdjacentGrids(entity, includeObstructed)
	local adjacent = {}
	for _,grid in ipairs(self:getOwnedGrids(entity)) do
		if grid.collision == Map.COLL_STATIC then
			local sw, se = self:getGrid(grid.gi + 1, grid.gj), self:getGrid(grid.gi, grid.gj + 1)
			if sw.collision == Map.COLL_NONE then
				table.insert(adjacent, { sw, 315 })
			end
			if se.collision == Map.COLL_NONE then
				table.insert(adjacent, { se, 45 })
			end

			if includeObstructed then
				local ne, nw = self:getGrid(grid.gi - 1, grid.gj), self:getGrid(grid.gi, grid.gj - 1)
				if ne.collision == Map.COLL_NONE then
					table.insert(adjacent, { ne, 225 })
				end
				if nw.collision == Map.COLL_NONE then
					table.insert(adjacent, { nw, 135 })
				end
			end
		end
	end

	return adjacent
end

--
-- Conversion functions
--

function Map:tileToWorldCoords(ti, tj)
	return (ti - tj) * self.halfTileWidth,
	       (ti + tj) * self.halfTileHeight
end

function Map:worldToTileCoords(x, y)
	local rx, ry = x / self.halfTileWidth, y / self.halfTileHeight
	return (ry + rx) / 2,
	       (ry - rx) / 2
end

function Map:worldToGridCoords(x, y)
	local rx, ry = x / self.halfGridWidth, y / self.halfGridHeight
	return (ry + rx) / 2,
	       (ry - rx) / 2
end

function Map:gridToWorldCoords(gi, gj)
	return (gi - gj) * self.halfGridWidth,
	       (gi + gj) * self.halfGridHeight
end

function Map:gridToGroundCoords(gi, gj)
	return gi * self.gridWidth,
	       gj * self.gridWidth
end

function Map:gridToTileCoords(gi, gj)
	return math.floor(gi / self.gridsPerTile),
	       math.floor(gj / self.gridsPerTile)
end

function Map:tileToGridCoords(ti, tj)
	return ti * self.gridsPerTile,
	       tj * self.gridsPerTile
end

function Map:isValidPosition(entity, ti, tj)
	local placing = entity:get("PlacingComponent")
	if placing:isTile() then
		if self.tile[ti] and self.tile[ti][tj] then
			return false
		end

		if self.tile[ti-1] and self.tile[ti-1][tj] then
			return true
		elseif self.tile[ti] and self.tile[ti][tj-1] then
			return true
		elseif self.tile[ti] and self.tile[ti][tj+1] then
			return true
		elseif self.tile[ti+1] and self.tile[ti+1][tj] then
			return true
		end

		return false
	else
		if self.tile[ti] and self.tile[ti][tj] then
			-- Special rules.
			if placing:getType() == BuildingComponent.FIELD and
			   self.tile[ti][tj].type ~= TileComponent.GRASS then
				return false
			end

			return self:_placeFullWidthObject(entity, ti, tj, true) ~= nil
		end

		return false
	end
end

function Map:getFreeGrid(ti, tj, resource)
	local sgi, sgj = self:tileToGridCoords(ti, tj)
	local egi, egj = sgi + self.gridsPerTile - 1, sgj + self.gridsPerTile - 1
	local gi, gj
	if resource == ResourceComponent.WOOD then
		gi, gj = sgi + self.gridsPerTile, sgj + self.gridsPerTile
	elseif resource == ResourceComponent.IRON then
		gi, gj = sgi + self.gridsPerTile, sgj
	elseif resource == ResourceComponent.TOOL then
		gi, gj = sgi, sgj + self.gridsPerTile
	elseif resource == ResourceComponent.GRAIN then
		gi, gj = sgi + self.gridsPerTile, sgj + math.floor(self.gridsPerTile / 2)
	elseif resource == ResourceComponent.BREAD then
		gi, gj = sgi + math.floor(self.gridsPerTile / 2), sgj + self.gridsPerTile
	end

	-- Look for a good place in a spiral pattern.
	if gi and gj then
		local x, y = 0, 0
		local d = 1
		local m = 1
		for _=1,self.gridsPerTile^2 do -- Upper bound
			local cgi, cgj = gi + x, gj +y
			while 2 * x * d < m do
				if cgi >= sgi and cgi <= egi and cgj >= sgj and cgj <= egj and
				   self.grid[cgi] and self.grid[cgi][cgj] and self.grid[cgi][cgj].collision == Map.COLL_NONE then
					return self.grid[cgi][cgj]
				end
				x = x + d
				cgi = gi + x
			end
			while 2 * y * d < m do
				if cgi >= sgi and cgi <= egi and cgj >= sgj and cgj <= egj and
				   self.grid[cgi] and self.grid[cgi][cgj] and self.grid[cgi][cgj].collision == Map.COLL_NONE then
					return self.grid[cgi][cgj]
				end
				y = y + d
				cgj = gj + y
			end

			d = d * -1
			m = m + 1
		end
	end

	print("No spot found for "..tostring(resource)..". Brute forcing")

	for cgi=sgi,sgi + self.gridsPerTile - 1 do
		for cgj=sgj,sgj + self.gridsPerTile - 1 do
			local grid = self.grid[cgi][cgj]
			if grid.collision == Map.COLL_NONE then
				return grid
			end
		end
	end

	error("No free grid")
end

function Map:getTile(ti, tj)
	if self.tile[ti] then
		return self.tile[ti][tj]
	end

	return nil
end

function Map:getGrid(gi, gj)
	if self.grid[gi] then
		return self.grid[gi][gj]
	end

	return nil
end

--
-- Path-finding functions.
--

function Map:isGridWalkable(grid)
	return bit.band(grid.collision, Map.COLL_STATIC) == 0
end

function Map:isGridEmpty(grid)
	return grid.collision == Map.COLL_NONE or grid.collision == Map.COLL_RESERVED
end

function Map:isGridReserved(grid)
	return bit.band(grid.collision, Map.COLL_RESERVED) ~= 0
end

function Map:_isGridWalkable(gi, gj)
	return self.grid[gi] and self.grid[gi][gj] and self:isGridWalkable(self.grid[gi][gj])
end

function Map:neighbours(grid)
	local neighbours = {}

	for gi=grid.gi - 1, grid.gi + 1 do
		for gj=grid.gj - 1, grid.gj + 1 do
			if self:_isGridWalkable(gi, gj) then
				-- Don't cut corners.
				if math.abs(gi - grid.gi) ~= 1 or math.abs(gj - grid.gj) ~= 1 or
				   (self:_isGridWalkable(gi, grid.gj) and self:_isGridWalkable(grid.gi, gj)) then
					table.insert(neighbours, self.grid[gi][gj])
				end
			end
		end
	end

	return neighbours
end

function Map:cost(thisGrid, nextGrid)
	local cost = 10
	-- Check if diagonal
	if math.abs(thisGrid.gi - nextGrid.gi) == 1 and math.abs(thisGrid.gj, nextGrid.gj) == 1 then
		cost = 14
	end
	if bit.band(nextGrid.collision, Map.COLL_DYNAMIC) ~= 0 then
		-- Increase the cost for grids currently occupied by villagers.
		cost = cost * Map.OCCUPIED_MULTIPLIER
	end
	return cost
end

function Map:heuristic(source, target)
	return 10 * math.abs(target.gi - source.gi) + math.abs(target.gj - source.gj)
end

--
-- Internal stuff
--

function Map:_placeObject(entity, gi, gj, dryrun)
	local collision = entity:get("CollisionComponent"):getCollisionSprite()
	local data = collision:getData()
	--print("pivot", data.pivot.x, data.pivot.y)

	--local gi, gj = -5, 5
	-- Translate the grid we want to place the object to world coordinates.
	local px, py = self:gridToWorldCoords(gi, gj)
	-- Offset the world coordinates to the start of the sprite (top-left corner).
	local x, y = px - data.pivot.x, py - data.pivot.y
	local w, h = data.bounds.w, data.bounds.h

	local ti, tj = math.floor(gi / self.gridsPerTile), math.floor(gj / self.gridsPerTile)

	-- Translate the four corners of the sprites (in world coordinates) to grids in the game.
	local sgi, _ = self:worldToGridCoords(x, y)
	local _, sgj = self:worldToGridCoords(x + w, y)
	local _, egj = self:worldToGridCoords(x, y + h)
	local egi, _ = self:worldToGridCoords(x + w, y + h)
	sgi, sgj, egi, egj = math.floor(sgi), math.floor(sgj), math.floor(egi), math.floor(egj)

	--print(("(%d, %d) -> (%d, %d)"):format(sgi, sgj, egi, egj))
	local mingi, mingj, maxgi, maxgj

	-- Loop over all the grids the sprite can potentially affect.
	for cgi=sgi,egi do
		for cgj=sgj,egj do
			-- Translate grid back world coordinates.
			local cx, cy = self:gridToWorldCoords(cgi, cgj)
			-- Translate from world coordinates to local (sprite) coordinates.
			cx, cy = cx - x, cy - y
			-- Make sure the local coordinate is within the bounds of the sprite.
			if cx >= 0 and cy >= 0 and cx <= w and cy <= h then
				local r, g, b, a = collision:getPixel(cx, cy + 1)

				if a > 0.5 then
					if dryrun then
						-- Make sure it is within the tile.
						local ssgi, ssgj = self:tileToGridCoords(ti, tj)
						--print("Check", ssgi, ssgj, cgi, cgj)
						if cgi >= ssgi and cgj >= ssgj and cgi < ssgi + self.gridsPerTile and cgj < ssgj + self.gridsPerTile then
							if self.grid[cgi][cgj].collision ~= Map.COLL_NONE then
								--print("Something in the way")
								return nil
							end
						else
							print("Out of bounds")
							return nil
						end
					else
						local grid = self.grid[cgi][cgj]
						grid.owner = entity
						if r == 1 and g == 0 and b == 0 then
							grid.collision = Map.COLL_STATIC
							mingi = mingi and math.min(mingi, cgi) or cgi
							mingj = mingj and math.min(mingj, cgj) or cgj
							maxgi = maxgi and math.max(maxgi, cgi) or cgi
							maxgj = maxgj and math.max(maxgj, cgj) or cgj
						elseif r == 0 and g == 0 and b == 1 then
							grid.collision = Map.COLL_RESERVED
						else
							error(("Don't know what to do with RGB %d,%d,%d"):format(r,g,b))
						end
					end
				end
			end
		end
	end

	return x, y, self.grid[mingi] and self.grid[mingi][mingj], self.grid[maxgi] and self.grid[maxgi][maxgj]
end

-- For objects that cover a whole tile.
function Map:_placeFullWidthObject(entity, ti, tj, dryrun)
	if not self.tile[ti] or not self.tile[ti][tj] then
		return nil
	end

	local collision = entity:get("CollisionComponent"):getCollisionSprite()

	-- Translate the tile we want to place the building on to world coordinates.
	local px, py = self:tileToWorldCoords(ti, tj)
	-- Get the top-left corner of the sprite in world coordinates.
	local x, y = px - self.halfTileWidth, py - collision:getHeight() + self.tileHeight

	-- Get the starting grid for that tile
	local sgi, sgj = self:tileToGridCoords(ti, tj)

	local mingi, mingj, maxgi, maxgj

	for cgi=sgi,sgi + self.gridsPerTile do
		for cgj=sgj,sgj + self.gridsPerTile do
			-- Translate grid back world coordinates.
			local cx, cy = self:gridToWorldCoords(cgi, cgj)
			-- Translate from world coordinates to local (sprite) coordinates.
			cx, cy = cx - x, cy - y
			-- Get the colour for the collision sprite on that grid position (1 pixel
			-- down to resolve conflicts).
			local r, g, b, a = collision:getPixel(cx, cy + 1)

			if a > 0.5 then
				if dryrun then
					if self.grid[cgi][cgj].collision ~= Map.COLL_NONE then
						--print("Something in the way")
						return nil
					end
				else
					local grid = self.grid[cgi][cgj]
					grid.owner = entity
					if r == 1 and g == 0 and b == 0 then
						grid.collision = Map.COLL_STATIC
						mingi = mingi and math.min(mingi, cgi) or cgi
						mingj = mingj and math.min(mingj, cgj) or cgj
						maxgi = maxgi and math.max(maxgi, cgi) or cgi
						maxgj = maxgj and math.max(maxgj, cgj) or cgj
					elseif r == 0 and g == 0 and b == 1 then
						grid.collision = Map.COLL_RESERVED
					else
						error(("Don't know what to do with %d,%d,%d"):format(r,g,b))
					end
				end
			end
		end
	end

	return x, y, self.grid[mingi] and self.grid[mingi][mingj], self.grid[maxgi] and self.grid[maxgi][maxgj]
end

function Map:eachTile()
	local sti, stj = self.firstTile[1], self.firstTile[2]
	local eti, etj = self.lastTile[1], self.lastTile[2]
	local ti, tj = sti - 1, stj
	return function()
		repeat
			ti = ti + 1
			if ti > eti then
				ti = sti
				tj = tj + 1
				if tj > etj then
					return nil
				end
			end
		until self.tile[ti] and self.tile[ti][tj]

		return ti, tj, self.tile[ti][tj].type
	end
end

function Map:_eachGrid(ti, tj)
	local sgi, sgj = self:tileToGridCoords(ti, tj)
	local egi, egj = sgi + self.gridsPerTile - 1, sgj + self.gridsPerTile - 1
	local gi, gj = sgi - 1, sgj
	return function()
		gi = gi + 1
		if gi > egi then
			gi = sgi
			gj = gj + 1
			if gj > egj then
				return nil
			end
		end

		return self.grid[gi][gj]
	end
end

--
-- Debug stuff
--

function Map:drawDebug()
	love.graphics.setLineWidth(0.5)
	love.graphics.setLineStyle("rough")

	for ti, tj in self:eachTile() do
		for grid in self:_eachGrid(ti, tj) do
			if bit.band(grid.collision, Map.COLL_STATIC) ~= 0 then
				love.graphics.setColor(1, 0, 0, 0.5)
			elseif bit.band(grid.collision, Map.COLL_DYNAMIC) ~= 0 then
				love.graphics.setColor(1, 0, 1, 0.5)
			elseif bit.band(grid.collision, Map.COLL_RESERVED) ~= 0 then
				love.graphics.setColor(0, 0, 1, 0.5)
			else
				love.graphics.setColor(0, 1, 0, 0.5)
			end

			local x, y = self:gridToWorldCoords(grid.gi, grid.gj)
			local polygon = {
				x, y,
				x + self.halfGridWidth, y + self.halfGridHeight,
				x, y + self.gridHeight,
				x - self.halfGridWidth, y + self.halfGridHeight
			}
			love.graphics.polygon(
				"fill", --grid.collision == Map.COLL_NONE and "line" or "fill",
				polygon
			)
			love.graphics.setColor(0, 0, 0, 0.5)
			love.graphics.polygon(
				"line", --grid.collision == Map.COLL_NONE and "line" or "fill",
				polygon
			)
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return Map
