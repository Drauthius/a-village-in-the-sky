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

local class = require "lib.middleclass"
local lovetoys = require "lib.lovetoys.lovetoys"
local serpent = require "lib.serpent"
local string = require "lib.string"

local GameEvent = require "src.game.gameevent"
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
		numTiles = 0,
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
	data.state.timeStopped = state.timeStopped
	data.state.selected = state.selected and self:saveEntity(state.selected) or nil
	data.state.placing = state.placing and self:saveEntity(state.placing) or nil
	data.state.available = state.available
	data.state.events = state.events
	data.state.lastPopulationEvent = state.lastPopulationEvent
	data.state.lastEventSeen = state.lastEventSeen

	-- Fifth pass: Fill in the information used by the profile screen.
	data.year = math.floor(data.state.year)
	for _ in pairs(engine:getEntitiesWithComponent("VillagerComponent")) do
		data.numVillagers = data.numVillagers + 1
	end
	for _,ti in pairs(data.map.tile) do
		for _ in pairs(ti) do
			data.numTiles = data.numTiles + 1
		end
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

function Cassette:load(engine, map, gui)
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
		ent.alive = true
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

	-- Fourth pass: The level and anything it felt worth saving.
	local level = require("src.game.level." .. data.level.source)(engine, map, gui)
	level:load(self, data.level)

	-- Last pass: Restore the state.
	state.viewport = data.state.viewport
	state.year = data.state.year
	state.yearModifier = data.state.yearModifier
	state.timeStopped = data.state.timeStopped
	state.selected = data.state.selected and self:loadEntity(data.state.selected) or nil
	state.placing = data.state.placing and self:loadEntity(data.state.placing) or nil
	state.available = data.state.available
	for _,event in ipairs(data.state.events) do
		table.insert(state.events, GameEvent(unpack(event)))
	end
	state.lastPopulationEvent = data.state.lastPopulationEvent
	state.lastEventSeen = data.state.lastEventSeen

	-- Remove the caches
	self.entities = nil
	self.map = nil

	return level
end

--
-- Helpers
--

function Cassette:saveEntity(entity)
	if not entity.alive then
		if entity.id then
			print("Entity id: " .. entity.id, entity)
		else
			print("Entity has not been added to any engine yet. (No entity.id)")
		end
		print("Entity's components:")
		for index, component in pairs(entity.components) do
			print(index, component)
		end
		error("Entity not alive")
	end
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

function Cassette:loadSprite(name)
	local spriteSheet = require "src.game.spritesheet"

	local slice
	local divider = name:find(spriteSheet.class.SLICE_SEPARATOR)
	if divider then
		name = name:sub(1, divider - 1)
		slice = name:sub(divider + 1, -1)
	end

	local sprite = spriteSheet:getSprite(string.split(name, spriteSheet.class.NAME_SEPARATOR), slice)
	assert(sprite:isValid(), "Failed to load sprite "..name)

	return sprite
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
