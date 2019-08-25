local class = require "lib.middleclass"
local lovetoys = require "lib.lovetoys.lovetoys"
local serpent = require "lib.serpent"

local state = require "src.game.state"

local Cassette = class("Cassette")

function Cassette:initialize(index)
	self.index = index
end

function Cassette:isValid()
	return love.filesystem.getInfo("save"..self.index, "file") ~= nil
end

function Cassette:save(engine, map, level)
	--local start = os.time()

	local data = {
		version = 1,
		year = 0,
		numVillagers = 0,
		numBuildings = 0,
		entities = {},
		map = {},
		state = {}
	}

	-- First pass: Create the entities.
	for _,entity in pairs(engine.entities) do
		table.insert(data.entities, {
			id = entity.id,
			parent = entity.parent.id,
			components = {}
		})
	end

	-- Second pass: Fill in the map.
	data.map.tile = map.tile
	data.map.firstTile = map.firstTile
	data.map.lastTile = map.lastTile
	data.map.grid = {}
	for gi in pairs(map.grid) do
		if not data.map.grid[gi] then
			data.map.grid[gi] = {}
		end

		for gj,grid in pairs(map.grid[gi]) do
			data.map.grid[gi][gj] = {
				gi = grid.gi,
				gj = grid.gj,
				tile = grid.tile,
				collision = grid.collision,
				occupied = grid.occupied and self:saveEntity(grid.occupied) or nil,
				owner = grid.owner and self:saveEntity(grid.owner) or nil
			}
		end
	end

	-- Third pass: Fill in the components.
	for _,entity in ipairs(data.entities) do
		for _,component in pairs(engine.entities[entity.id]:getComponents()) do
			if component.class.save ~= false then
				table.insert(entity.components, {
					name = component.class.name:lower(),
					data = component.class.save(component, self)
				})
			end
		end
	end

	-- Fourth pass: Grab relevant state.
	-- (Note: Some things will be recalculated when loading.)
	data.state.viewport = state.viewport
	data.state.year = state.year
	data.state.yearModifier = state.yearModifier
	data.state.selected = state.selected and self:saveEntity(state.selected) or nil
	data.state.placing = state.placing and self:saveEntity(state.placing) or nil

	-- Fifth pass: Fill in the information used by the profile screen.
	data.year = math.floor(data.state.year)
	for _ in pairs(engine:getEntitiesWithComponent("VillagerComponent")) do
		data.numVillagers = data.numVillagers + 1
	end
	for _,entity in pairs(engine:getEntitiesWithComponent("BuildingComponent")) do
		if not entity:has("RunestoneComponent") then -- Pretend runestones aren't buildings.
			data.numBuildings = data.numBuildings + 1
		end
	end

	-- Sixth pass: Anything the level feels worth saving.
	data.level = level:save(self)

	love.filesystem.write("save"..self.index, serpent.dump(data))
	--print("Saving done. Took "..os.difftime(os.time(), start).." seconds.")
end

function Cassette:load(engine, map, level)
	local data
	local content, err = love.filesystem.read("save"..self.index)
	if not content then
		print(err)
		return false
	else
		local ok
		ok, data = serpent.load(content, { safe = false }) -- Safety has to be turned off to load functions.
		if not ok then
			return false
		end
	end

	-- Caches
	self.entities = engine.entities
	self.map = map

	-- First pass: Create the entities.
	for _,entity in ipairs(data.entities) do
		local ent = lovetoys.Entity()

		ent.eventManager = engine.eventManager
		ent.id = entity.id
		engine.entities[ent.id] = ent
	end

	-- Second pass: Fill in the map.
	map.tile = data.map.tile
	map.firstTile = data.map.firstTile
	map.lastTile = data.map.lastTile
	for gi in pairs(data.map.grid) do
		if not map.grid[gi] then
			map.grid[gi] = {}
		end

		for gj,grid in pairs(data.map.grid[gi]) do
			map.grid[gi][gj] = {
				gi = grid.gi,
				gj = grid.gj,
				tile = grid.tile,
				collision = grid.collision,
				occupied = grid.occupied and self:loadEntity(grid.occupied) or nil,
				owner = grid.owner and self:loadEntity(grid.owner) or nil
			}
		end
	end

	-- Third pass: Assign parent-child relationships and fill in the components.
	for _,entity in ipairs(data.entities) do
		local ent = engine.entities[entity.id]
		ent:setParent(entity.parent and engine.entities[entity.parent] or engine:getRootEntity())
		ent:registerAsChild()

		for _,component in ipairs(entity.components) do
			local comp = require("src.game."..component.name).load(self, component.data)
			assert(comp, component.name.." did not return a valid component.")
			ent.components[comp.class.name] = comp
		end

		-- Third and a half pass: Register all the components.
		-- This is done separately from the loop above, since there are assumptions on which components belong
		-- together.
		for name in pairs(ent.components) do
			ent.eventManager:fireEvent(lovetoys.ComponentAdded(ent, name))
		end
	end

	-- Fourth pass: Restore the state.
	state.viewport = data.state.viewport
	state.year = data.state.year
	state.yearModifier = data.state.yearModifier
	state.selected = data.state.selected and self:loadEntity(data.state.selected) or nil
	state.placing = data.state.placing and self:loadEntity(data.state.placing) or nil

	-- Fifth pass: Anything the level felt worth saving.
	level:load(self, data.level)

	-- Remove the caches
	self.entities = nil
	self.map = nil
end

--
-- Helpers
--

function Cassette:saveEntity(entity)
	return { type = "entity", id = entity.id }
end

function Cassette:loadEntity(entity)
	return self.entities[entity.id]
end

function Cassette:isEntity(entity)
	return type(entity) == "table" and entity.type == "entity"
end

function Cassette:saveEntityList(entities)
	local list = {}

	for _,entity in ipairs(entities) do
		table.insert(list, self:saveEntity(entity))
	end

	return list
end

function Cassette:loadEntityList(entities)
	local list = {}

	for _,entity in ipairs(entities) do
		table.insert(list, self:loadEntity(entity))
	end

	return list
end

function Cassette:saveSprite(sprite)
	return sprite:getName()
end

function Cassette:loadSprite(sprite)
	local spriteSheet = require "src.game.spritesheet"

	local divider = sprite:find("|")
	if divider then
		return spriteSheet:getSprite(sprite:sub(1, divider - 1), sprite:sub(divider + 1, -1))
	else
		return spriteSheet:getSprite(sprite)
	end
end

function Cassette:saveGrid(grid)
	return { grid.gi, grid.gj }
end

function Cassette:loadGrid(grid)
	return self.map:getGrid(grid[1], grid[2])
end

function Cassette:saveGridList(grids)
	local list = {}

	for _,grid in ipairs(grids) do
		table.insert(list, self:saveGrid(grid))
	end

	return list
end

function Cassette:loadGridList(grids)
	local list = {}

	for _,grid in ipairs(grids) do
		table.insert(list, self:loadGrid(grid))
	end

	return list
end

return Cassette
