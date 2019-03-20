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
Map.static.COLL_NONE = 0
Map.static.COLL_STATIC = 1
Map.static.COLL_DYNAMIC = 2
Map.static.COLL_RESERVED = 4

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
	local sgi, sgj = ti * self.gridsPerTile, tj * self.gridsPerTile
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

function Map:addResource(resource, grid)
	grid.collision = Map.COLL_STATIC
	assert(not grid.owner, "Overlap")
	grid.owner = resource
end

function Map:reserve(villager, grid)
	grid.collision = bit.bor(grid.collision, Map.COLL_DYNAMIC)
	if not grid.owner then -- The villager can "walk over" some reserved grids, but shouldn't take over ownership
		grid.owner = villager
	end
end

function Map:unreserve(villager, grid)
	grid.collision = bit.band(grid.collision, bit.bnot(Map.COLL_DYNAMIC))
	if grid.owner == villager then
		grid.owner = nil
	end
end

function Map:remove(entity)
	local grid = entity:get("PositionComponent"):getGrid()

	-- XXX: It might occupy multiple grids.
	local ti, tj = math.floor(grid.gi / self.gridsPerTile), math.floor(grid.gj / self.gridsPerTile)
	local sgi, sgj = ti * self.gridsPerTile, tj * self.gridsPerTile
	for gi=sgi,sgi + self.gridsPerTile - 1 do
		for gj=sgj,sgj + self.gridsPerTile - 1 do
			grid = self:getGrid(gi, gj)
			if grid.owner == entity then
				grid.collision = bit.band(grid.collision, bit.bnot(Map.COLL_STATIC))
				grid.collision = bit.band(grid.collision, bit.bnot(Map.COLL_RESERVED))
				grid.owner = nil
			end
		end
	end
end

function Map:getAdjacentGrids(entity)
	local grid = entity:get("PositionComponent"):getGrid()

	-- XXX: Get all the adjacent grids that aren't occupied, and that are "visible".
	local adjacent = {}
	local ti, tj = math.floor(grid.gi / self.gridsPerTile), math.floor(grid.gj / self.gridsPerTile)
	local sgi, sgj = ti * self.gridsPerTile, tj * self.gridsPerTile
	for gi=sgi,sgi + self.gridsPerTile - 1 do
		for gj=sgj,sgj + self.gridsPerTile - 1 do
			grid = self:getGrid(gi, gj)
			local nw, ne = self:getGrid(gi - 1, gj), self:getGrid(gi, gj - 1)
			nw = nw and nw.owner == entity and nw.collision == Map.COLL_STATIC
			ne = ne and ne.owner == entity and ne.collision == Map.COLL_STATIC
			if grid.collision == Map.COLL_NONE and (nw or ne) then
				table.insert(adjacent, { grid, nw and 315 or 45 })
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
	local sgi, sgj = ti * self.gridsPerTile, tj * self.gridsPerTile
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
						local ssgi, ssgj = ti * self.gridsPerTile, tj * self.gridsPerTile
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
	local sgi, sgj = ti * self.gridsPerTile, tj * self.gridsPerTile

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

--
-- Debug stuff
--

function Map:drawDebug()
	love.graphics.setLineWidth(0.5)
	love.graphics.setLineStyle("rough")

	local sti, stj = self.firstTile[1], self.firstTile[2]
	local eti, etj = self.lastTile[1], self.lastTile[2]

	for ti=sti,eti do
		for tj=stj,etj do
			if self.tile[ti] and self.tile[ti][tj] then
				local sgi, sgj = ti * self.gridsPerTile, tj * self.gridsPerTile
				for gi=sgi,sgi + self.gridsPerTile - 1 do
					for gj=sgj,sgj + self.gridsPerTile - 1 do
						if self.grid[gi] and self.grid[gi][gj] then
							local grid = self.grid[gi][gj]

							if bit.band(grid.collision, Map.COLL_STATIC) ~= 0 then
								love.graphics.setColor(1, 0, 0, 0.5)
							elseif bit.band(grid.collision, Map.COLL_DYNAMIC) ~= 0 then
								love.graphics.setColor(1, 0, 1, 0.5)
							elseif bit.band(grid.collision, Map.COLL_RESERVED) ~= 0 then
								love.graphics.setColor(0, 0, 1, 0.5)
							else
								love.graphics.setColor(0, 1, 0, 0.5)
							end

							local x, y = self:gridToWorldCoords(gi, gj)
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
				end
			end
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return Map
