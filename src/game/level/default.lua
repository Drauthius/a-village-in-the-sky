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

local Level = require "src.game.level"

local BuildingComponent = require "src.game.buildingcomponent"
local GroundComponent = require "src.game.groundcomponent"
local InteractiveComponent = require "src.game.interactivecomponent"
local PositionComponent = require "src.game.positioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TileComponent = require "src.game.tilecomponent"
local WorkComponent = require "src.game.workcomponent"

local InfoPanel = require "src.game.gui.infopanel"

local blueprint = require "src.game.blueprint"
local state = require "src.game.state"
local spriteSheet = require "src.game.spritesheet"

local DefaultLevel = Level:subclass("DefaultLevel")

function DefaultLevel:initialize(...)
	Level.initialize(self, ...)

	self.objectives = {
		{
			text = "Place a grass tile",
			pre = function()
				state:setTimeStopped(true)

				state:setAvailableTerrain({ TileComponent.GRASS })
				state:setAvailableBuildings({ BuildingComponent.DWELLING })
				self.gui:changeAvailibility(InfoPanel.CONTENT.PLACE_TERRAIN)
				self.gui:changeAvailibility(InfoPanel.CONTENT.PLACE_BUILDING)

				self.gui:hideYearPanel(true)
				self.gui:setHint(InfoPanel.CONTENT.PLACE_TERRAIN, TileComponent.GRASS)
			end,
			cond = function()
				for ti,tj,type in self.map:eachTile() do
					if type == TileComponent.GRASS and (ti ~= 0 or tj ~= 0) then
						return true
					end
				end
			end
		},

		{
			text = "Place a dwelling",
			pre = function()
				self.gui:hideYearPanel(true)
				self.gui:setHint(InfoPanel.CONTENT.PLACE_BUILDING, BuildingComponent.DWELLING)
			end,
			cond = function()
				for _,entity in pairs(self.engine:getEntitiesWithComponent("ConstructionComponent")) do
					if entity:get("ConstructionComponent"):getType() == BuildingComponent.DWELLING then
						return true
					end
				end
			end
		},

		{
			text = "Assign a villager to build the dwelling",
			pre = function()
				self.gui:hideYearPanel(true)
				self.gui:setHint(function()
					if state:getSelection() and state:getSelection():has("AdultComponent") then
						for _,entity in pairs(self.engine:getEntitiesWithComponent("ConstructionComponent")) do
							if entity:get("ConstructionComponent"):getType() == BuildingComponent.DWELLING then
								return entity
							end
						end
					else
						return select(2, next(self.engine:getEntitiesWithComponent("AdultComponent")))
					end
				end)
			end,
			cond = function()
				for _,entity in pairs(self.engine:getEntitiesWithComponent("ConstructionComponent")) do
					if entity:get("ConstructionComponent"):getType() == BuildingComponent.DWELLING and
					   entity:get("AssignmentComponent"):getNumAssignees() > 0 then
						return true
					end
				end
			end
		},

		{
			text = "Once done, assign a villager to the house",
			pre = function()
				self.gui:hideYearPanel(true)
				self.gui:setHint(function()
					local dwelling = select(2, next(self.engine:getEntitiesWithComponent("DwellingComponent")))
					if not dwelling then
						return nil
					elseif state:getSelection() and state:getSelection():has("AdultComponent") then
						return dwelling
					else
						return select(2, next(self.engine:getEntitiesWithComponent("AdultComponent")))
					end
				end)
			end,
			cond = function()
				for _,entity in pairs(self.engine:getEntitiesWithComponent("DwellingComponent")) do
					if entity:get("AssignmentComponent"):getNumAssignees() > 0 then
						return true
					end
				end
			end,
			post = function()
				state:setTimeStopped(false)
				self.gui:showYearPanel()
				self.gui:setHint(nil)
			end
		},

		{
			text = "Place man and woman in a house to get children",
			cond = function()
				for _,entity in pairs(self.engine:getEntitiesWithComponent("DwellingComponent")) do
					local assignees = entity:get("AssignmentComponent"):getAssignees()
					if #assignees >= 2 then
						return assignees[1]:get("VillagerComponent"):getGender() ~= assignees[2]:get("VillagerComponent"):getGender()
					end
				end
			end,
		},
		{ withPrevious = true,
			text = "Build a blacksmith",
			pre = function()
				state:setAvailableBuildings({ BuildingComponent.DWELLING, BuildingComponent.BLACKSMITH })
				self.gui:changeAvailibility(InfoPanel.CONTENT.PLACE_BUILDING)
			end,
			cond = function()
				for _,entity in pairs(self.engine:getEntitiesWithComponent("ProductionComponent")) do
					if entity:get("BuildingComponent"):getType() == BuildingComponent.BLACKSMITH then
						return true
					end
				end
			end
		},
		{ withPrevious = true,
			text = "Upgrade the runestone",
			cond = function()
				for _,entity in pairs(self.engine:getEntitiesWithComponent("RunestoneComponent")) do
					if entity:get("RunestoneComponent"):getLevel() > 1 then
						return true
					end
				end
			end,
			post = function()
				state:setAvailableTerrain({ TileComponent.GRASS, TileComponent.FOREST, TileComponent.MOUNTAIN })
				self.gui:changeAvailibility(InfoPanel.CONTENT.PLACE_TERRAIN)
			end
		},

		{
			text = "Place a forest, and assign a woodcutter",
			cond = function()
				for _,entity in pairs(self.engine:getEntitiesWithComponent("AdultComponent")) do
					if entity:get("AdultComponent"):getOccupation() == WorkComponent.WOODCUTTER then
						return true
					end
				end
			end
		},
		{ withPrevious = true,
			text = "Build a field",
			pre = function()
				state:setAvailableBuildings({ BuildingComponent.DWELLING, BuildingComponent.BLACKSMITH, BuildingComponent.FIELD })
				self.gui:changeAvailibility(InfoPanel.CONTENT.PLACE_BUILDING)
			end,
			cond = function()
				return next(self.engine:getEntitiesWithComponent("FieldEnclosureComponent")) ~= nil
			end
		},

		{
			text = "Place a mountain, and assign a miner",
			cond = function()
				for _,entity in pairs(self.engine:getEntitiesWithComponent("AdultComponent")) do
					if entity:get("AdultComponent"):getOccupation() == WorkComponent.MINER then
						return true
					end
				end
			end
		},
		{ withPrevious = true,
			text = "Build a bakery",
			pre = function()
				state:setAvailableBuildings({
					BuildingComponent.DWELLING,
					BuildingComponent.BLACKSMITH,
					BuildingComponent.FIELD,
					BuildingComponent.BAKERY
				})
				self.gui:changeAvailibility(InfoPanel.CONTENT.PLACE_BUILDING)
			end,
			cond = function()
				for _,entity in pairs(self.engine:getEntitiesWithComponent("ProductionComponent")) do
					if entity:get("BuildingComponent"):getType() == BuildingComponent.BAKERY then
						return true
					end
				end
			end
		},

		{
			text = "Reach 25 villagers",
			cond = function()
				local num = 0
				for _ in pairs(self.engine:getEntitiesWithComponent("VillagerComponent")) do
					num = num + 1
				end
				return num >= 25
			end
		},

		{
			text = "Reach 100 villagers",
			cond = function()
				local num = 0
				for _ in pairs(self.engine:getEntitiesWithComponent("VillagerComponent")) do
					num = num + 1
				end
				return num >= 100
			end
		}
	}
end

function DefaultLevel:initial()
	do -- Initial tile.
		local tile = lovetoys.Entity()
		tile:add(TileComponent(TileComponent.GRASS, 0, 0))
		tile:add(SpriteComponent(spriteSheet:getSprite("grass-tile"), -self.map.halfTileWidth))
		self.engine:addEntity(tile)
		self.map:addTile(TileComponent.GRASS, 0, 0)
	end

	do -- Initial runestone.
		local runestone = blueprint:createRunestone()
		local x, y, minGrid, maxGrid = self.map:addObject(runestone, 0, 0)
		runestone:get("SpriteComponent"):setDrawPosition(x, y)
		runestone:add(PositionComponent(minGrid, maxGrid, 0, 0))
		InteractiveComponent:makeInteractive(runestone, x, y)
		self.engine:addEntity(runestone)
	end

	local startingResources = {
		[ResourceComponent.WOOD] = 33,
		[ResourceComponent.IRON] = 9,
		[ResourceComponent.TOOL] = 15,
		[ResourceComponent.BREAD] = 12
	}

	-- Split so that we can assign the children to the adults.
	local startingVillagers = {
		{ -- Adults
			maleVillagers = 2,
			femaleVillagers = 2
		},
		{ -- Children
			maleChild = 1,
			femaleChild = 1
		}
	}
	local startingPositions = {
		{ 11, 2 },
		{ 12, 6 },
		{ 12, 10 },
		{ 9, 12 },
		{ 5, 12 },
		{ 2, 11 }
		--{ 8, 4 }
	}

	for type,num in pairs(startingResources) do
		while num > 0 do
			local resource = blueprint:createResourcePile(type, math.min(3, num))
			resource:add(PositionComponent(self.map:getFreeGrid(0, 0, type), nil, 0, 0))
			self.map:addResource(resource, resource:get("PositionComponent"):getGrid())
			self.engine:addEntity(resource)

			num = num - resource:get("ResourceComponent"):getResourceAmount()
		end
	end

	local females = {}
	for _,tbl in ipairs(startingVillagers) do
		for type,num in pairs(tbl) do
			for _=1,num do
				local isMale = type:match("^male")
				local isChild = type:match("Child$")
				local mother

				if isChild then
					mother = table.remove(females)
				end

				local villager = blueprint:createVillager(mother, nil,
				                                          isMale and "male" or "female",
				                                          isChild and 10 or 20)

				if not isMale and not isChild then
					table.insert(females, villager)
				end

				local gi, gj = unpack(table.remove(startingPositions) or {})
				local grid
				if not gi or not gj then
					grid = self.map:getFreeGrid(0, 0, "villager")
					gi, gj = grid.gi, grid.gj
				else
					grid = self.map:getGrid(gi, gj)
				end

				villager:add(PositionComponent(grid, nil, 0, 0))
				villager:add(GroundComponent(self.map:gridToGroundCoords(gi + 0.5, gj + 0.5)))
				villager:add(require("src.game.seniorcomponent")())

				self.engine:addEntity(villager)
			end
		end
	end
end

function DefaultLevel:getResources(tileType)
	if tileType == TileComponent.GRASS then
		local numTiles = 0
		for _ in pairs(self.engine:getEntitiesWithComponent("TileComponent")) do
			numTiles = numTiles + 1
			if numTiles >= 8 then
				return math.max(0, math.floor((love.math.random(9) - 5) / 2)), 0
			end
		end
		return 0, 0
	elseif tileType == TileComponent.FOREST then
		return love.math.random(3, 7), 0
	elseif tileType == TileComponent.MOUNTAIN then
		return math.max(0, love.math.random(5) - 4), love.math.random(3, 5)
	end
end

function DefaultLevel:shouldPlaceRunestone(ti, tj)
	for _,entity in pairs(self.engine:getEntitiesWithComponent("RunestoneComponent")) do
		local tti, ttj = entity:get("PositionComponent"):getTile()
		-- Manhattan distance.
		local distance = math.abs(tti - ti) + math.abs(ttj - tj)
		if distance < 3 then
			return false
		end
	end

	-- FIXME: An unlucky player might not be able to expand their village.
	return love.math.random() < 0.3
end

return DefaultLevel
