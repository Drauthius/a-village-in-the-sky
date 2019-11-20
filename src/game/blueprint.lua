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

local AdultComponent = require "src.game.adultcomponent"
local AnimationComponent = require "src.game.animationcomponent"
local BuildingComponent = require "src.game.buildingcomponent"
local CollisionComponent = require "src.game.collisioncomponent"
local ColorSwapComponent = require "src.game.colorswapcomponent"
local FertilityComponent = require "src.game.fertilitycomponent"
local ParticleComponent = require "src.game.particlecomponent"
local PlacingComponent = require "src.game.placingcomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local RunestoneComponent = require "src.game.runestonecomponent"
local SeniorComponent = require "src.game.seniorcomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TileComponent = require "src.game.tilecomponent"
local VillagerComponent = require "src.game.villagercomponent"
local WorkComponent = require "src.game.workcomponent"

local spriteSheet = require "src.game.spritesheet"

local Blueprint = class("Blueprint")

Blueprint.static.VILLAGER_PALETTES = {}

-- Chance that the child does not dress/look like its parents, per item/group.
Blueprint.static.PALETTE_DEVIATION = 0.05

function Blueprint:createPlacingTile(type)
	local tile = lovetoys.Entity()

	local name = TileComponent.TILE_NAME[type]
	tile:add(PlacingComponent(true, type))
	tile:add(SpriteComponent(spriteSheet:getSprite(name .. "-tile")))

	return tile
end

function Blueprint:createPlacingBuilding(type)
	local building = lovetoys.Entity()

	local name = BuildingComponent.BUILDING_NAME[type]
	local sprite = spriteSheet:getSprite(name .. (type == BuildingComponent.FIELD and "" or " 0"))
	local collision = spriteSheet:getSprite(name .. " (Grid information)" ..
		(type == BuildingComponent.FIELD and "" or " 0"))

	building:add(PlacingComponent(false, type))
	building:add(CollisionComponent(collision))
	building:add(SpriteComponent(sprite))

	return building
end

function Blueprint:createRunestone(level)
	level = level or 1
	local runestone = lovetoys.Entity()
	-- XXX: Would be nice if the sprite could be added by a refresh, but the interactive component won't really have it.
	local sprite = spriteSheet:getSprite("runestone "..((level-1)*2))
	local collision = spriteSheet:getSprite("runestone (Grid information) 0")

	runestone:add(CollisionComponent(collision))
	runestone:add(SpriteComponent(sprite))
	runestone:add(RunestoneComponent(level))
	-- XXX: Don't really need this, but we do need it.
	runestone:add(BuildingComponent(BuildingComponent.RUNESTONE))

	return runestone
end

function Blueprint:createTree()
	local tree = lovetoys.Entity()
	local sprite = spriteSheet:getSprite("tree")
	local collision = spriteSheet:getSprite("tree (Grid information)")

	tree:add(CollisionComponent(collision))
	tree:add(SpriteComponent(sprite))
	tree:add(ResourceComponent(ResourceComponent.WOOD))
	tree:add(WorkComponent(WorkComponent.WOODCUTTER))

	-- TODO: Maybe consolidate the names or something, cause this is a bit whack.
	collision.data = spriteSheet:getData("Tree")

	return tree
end

function Blueprint:createIron()
	local iron = lovetoys.Entity()
	local sprite = spriteSheet:getSprite("iron")
	local collision = spriteSheet:getSprite("iron (Grid information)")

	iron:add(CollisionComponent(collision))
	iron:add(SpriteComponent(sprite))
	iron:add(ResourceComponent(ResourceComponent.IRON))
	iron:add(WorkComponent(WorkComponent.MINER))

	-- TODO: Maybe consolidate the names or something, cause this is a bit whack.
	collision.data = spriteSheet:getData("Ore") -- Come on

	return iron
end

function Blueprint:createResourcePile(type, amount)
	local resource = lovetoys.Entity()

	local name = ResourceComponent.RESOURCE_NAME[type]
	local sprite = spriteSheet:getSprite(name.."-resource "..tostring(amount - 1))

	resource:add(ResourceComponent(type, amount, true))
	resource:add(SpriteComponent(sprite))

	return resource
end

function Blueprint:createVillager(mother, father, gender, age)
	local entity = lovetoys.Entity()
	gender = gender or (love.math.random() < 0.5 and "male" or "female")
	age = age or 0

	local colors = Blueprint.VILLAGER_PALETTES.COLORS
	if not colors then
		local palette = spriteSheet:getSprite("villagers-palette")
		colors = {
			skin = {
				-- Default:
				{ { palette:getPixel(4, 0) },
				  { palette:getPixel(5, 0) } },
				-- Fairer:
				{ { 0.761, 0.584, 0.510, 1 },
				  { 0.812, 0.663, 0.569, 1 } },
				-- Browner:
				{ { 0.67, 0.45, 0.33, 1 },
				  { 0.77, 0.62, 0.47, 1 } }
			},
			hair = {
				-- Default:
				{ { palette:getPixel(6, 0) },
				  { palette:getPixel(7, 0) } },
				-- Lighter:
				{ { 0.490, 0.369, 0.145, 1 },
				  { 0.569, 0.471, 0.224, 1 } }
			},
			shirt = {
				-- Default:
				{ { palette:getPixel(8, 0) },
				  { palette:getPixel(9, 0) } },
				-- Lighter:
				{ { 0.506, 0.565, 0.600, 1 },
				  { 0.753, 0.812, 0.808, 1 } },
				-- Bluer:
				{ { 0.239, 0.310, 0.400, 1 },
				  { 0.349, 0.443, 0.502, 1 } },
				-- Redder:
				{ { 0.4, 0.125, 0.180, 1 },
				  { 0.502, 0.176, 0.176, 1 } }
			},
			pants = {
				-- Default:
				{ { palette:getPixel(10, 0) },
				  { palette:getPixel(11, 0) } },
				-- Browner:
				{ { 0.212, 0.169, 0.129, 1 },
				  { 0.259, 0.204, 0.165, 1 } }
			},
			shoes = {
				-- Default:
				{ { palette:getPixel(12, 0) },
				  { palette:getPixel(13, 0) } }
			}
		}
		Blueprint.VILLAGER_PALETTES.COLORS = colors
	end

	local parents = {}
	if mother then
		table.insert(parents, mother)
	end
	if father then
		table.insert(parents, father)
	end
	for _,parent in ipairs(parents) do
		parent:get("VillagerComponent"):addChild(entity)
	end

	local colorSwap = ColorSwapComponent()
	local skinColor = self:_getColor("skin", colors.skin, parents)
	for part,colorChoices in pairs(colors) do
		local color
		if part == "skin" then
			color = skinColor
		elseif part == "shoes" and love.math.random() < 0.5 then
			-- Barefoot!
			color = skinColor
		else
			color = self:_getColor(part, colorChoices, parents)
		end

		-- 1 is the default colour to replace.
		-- Always replace the hair, so that we can change it later without fuss.
		if color ~= colorChoices[1] or part == "hair" then
			colorSwap:add(part, colorChoices[1], color)
		end
	end
	entity:add(colorSwap)
	entity:add(SpriteComponent()) -- Filled in by the sprite system.
	entity:add(AnimationComponent())

	local strength, craftsmanship
	if #parents > 0 then
		strength = parents[love.math.random(1, #parents)]:get("VillagerComponent"):getStrength() +
		           love.math.random(-15, 2) / 100
		craftsmanship = parents[love.math.random(1, #parents)]:get("VillagerComponent"):getCraftsmanship() +
		                love.math.random(-15, 2) / 100
	end

	entity:add(VillagerComponent({
		hairy = love.math.random() < 0.5,
		gender = gender,
		age = age,
		strength = strength,
		craftsmanship = craftsmanship
	}, mother, father))
	if age >= 14 then -- XXX: Get value from some place.
		entity:add(AdultComponent())
		entity:add(FertilityComponent()) -- FIXME: This can be grossly inaccurate for the first year.
		if age >= 55 then -- XXX: Get value from some place.
			entity:add(SeniorComponent())
		end
	end

	return entity
end

function Blueprint:createWoodSparksParticle()
	local entity = lovetoys.Entity()
	local sprite = spriteSheet:getSprite("spark")

	local def = {
		_buffer = 32,
		_sprite = sprite,
		colors = { 0.388, 0.326, 0.263, 0.9 },
		emissionRate = 69,
		emitterLifetime = 0.1,
		insertMode = "random",
		linearAcceleration = { 0, 50, 0, 80 },
		radialAcceleration = { -2, -10 },
		emissionArea = { "uniform", 2, 2 },
		particleLifetime = 0.3,
		rotation = { -math.pi, math.pi },
		speed = { 30, 30 },
		spread = { 2*math.pi },
		sizeVariation = { 0.5 },
		sizes = { 1.0, 0.5 },
		spin = { -math.pi, math.pi },
		spinVariation = 1
	}

	entity:add(ParticleComponent(def, 1, true))
	entity:add(SpriteComponent(sprite))

	return entity
end

function Blueprint:createIronSparksParticle()
	local entity = lovetoys.Entity()
	local sprite = spriteSheet:getSprite("spark")

	local def = {
		_buffer = 32,
		_sprite = sprite,
		colors = { 0.665, 0.680, 0.645, 0.9 },
		emissionRate = 69,
		emitterLifetime = 0.1,
		insertMode = "random",
		linearAcceleration = { 0, 50, 0, 80 },
		radialAcceleration = { -2, -10 },
		emissionArea = { "uniform", 2, 2 },
		particleLifetime = 0.3,
		rotation = { -math.pi, math.pi },
		speed = { 30, 30 },
		spread = { 2*math.pi },
		sizeVariation = 0.5,
		sizes = { 1.0, 0.5 },
		spin = { -math.pi, math.pi },
		spinVariation = 1
	}

	entity:add(ParticleComponent(def, 1, true))
	entity:add(SpriteComponent(sprite))

	return entity
end

function Blueprint:createSmokeParticle()
	local entity = lovetoys.Entity()
	local sprite = spriteSheet:getSprite("smoke")

	local def = {
		_buffer = 32,
		_sprite = sprite,
		colors = { 1, 1, 1, 0.8,
		           1, 1, 1, 0.5,
		           1, 1, 1, 0.0 },
		emissionRate = 5,
		emitterLifetime = -1,
		insertMode = "random",
		linearAcceleration = { -0.5, -3, 0.5, -3 },
		radialAcceleration = { 10, 10 },
		particleLifetime = { 2, 3 },
		rotation = { math.rad(1), math.rad(360) },
		sizeVariation = 0.2,
		sizes = { 0.5, 1.0, 2.5 },
		spin = { math.rad(5), math.rad(15) },
		spinVariation = 1
	}

	entity:add(ParticleComponent(def, -1, false))
	entity:add(SpriteComponent(sprite))

	return entity
end

function Blueprint:createDustParticle(direction, small)
	local entity = lovetoys.Entity()
	local frames = spriteSheet:getFrameTag("Dust "..direction)

	local sprites = {}
	local duration
	for i=frames.from + 1, frames.to do
		local sprite, dur = spriteSheet:getSprite("dust-effect "..i)
		duration = duration or dur
		table.insert(sprites, sprite)
	end

	local dir
	if direction == "SE" then
		dir = math.pi/4
	elseif direction == "SW" then
		dir = 3*math.pi/4
	elseif direction == "NE" then
		dir = -math.pi/4
	elseif direction == "NW" then
		dir = -3*math.pi/4
	end

	local def = {
		_buffer = 16,
		_sprites = sprites,
		emitterLifetime = 0.1,
		speed = 15,
		direction = dir,
		particleLifetime = duration * #sprites / 1000 / 2
	}

	if small then
		def.emissionRate = 20
		def.emissionArea = { "ellipse", 3, 15, dir }
		def.sizes = 0.4
	else
		def.emissionRate = 30
		def.emissionArea = { "ellipse", 3, 25, dir }
		def.sizes = 0.6
	end

	entity:add(ParticleComponent(def, 1, true))
	entity:add(SpriteComponent(sprites[1]))

	return entity
end

function Blueprint:createDeathParticle(villager)
	local entity = lovetoys.Entity()
	local sprite

	if villager:has("AdultComponent") then
		local hairy = villager:get("VillagerComponent"):isHairy() and "(Hairy) " or ""
		sprite = spriteSheet:getSprite("villagers "..hairy.."1", villager:get("VillagerComponent"):getGender().." - SE")
	else
		sprite = spriteSheet:getSprite("children 1",
			(villager:get("VillagerComponent"):getGender() == "male" and "boy" or "girl").." - SE")
	end

	local def = {
		_buffer = 1,
		_sprite = sprite,
		colors = { 0.2, 0.2, 0.9, 0.8,
		           0.2, 0.2, 0.9, 0.5,
		           0.2, 0.2, 0.9, 0.0 },
		emissionRate = 10,
		emitterLifetime = 0.1,
		linearAcceleration = { -0.5, -3, 0.5, -3 },
		radialAcceleration = 10,
		particleLifetime = 3
	}

	entity:add(ParticleComponent(def, 1, true))
	entity:add(SpriteComponent(sprite))
	-- TODO: Either color swap to more phantasmal colours, or create new sprites.

	return entity
end

--
-- Internal functions
--

function Blueprint:_getColor(part, colorChoices, parents)
	local color

	if love.math.random() < Blueprint.PALETTE_DEVIATION or #parents < 1 then
		color = colorChoices[love.math.random(1, #colorChoices)]
	else
		color = parents[love.math.random(1, #parents)]:get("ColorSwapComponent"):getGroup(part)
		-- Make sure to return something at least.
		if not color then
			color = colorChoices[1]
		end
	end

	return color
end

return Blueprint()
