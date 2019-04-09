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

Blueprint.static.PARTICLE_SYSTEMS = {}
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

function Blueprint:createRunestone()
	local runestone = lovetoys.Entity()
	local sprite = spriteSheet:getSprite("monolith 0")
	local collision = spriteSheet:getSprite("monolith (Grid information) 0")

	runestone:add(CollisionComponent(collision))
	runestone:add(SpriteComponent(sprite))
	runestone:add(RunestoneComponent())

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
				  { 0.812, 0.663, 0.569, 1 } }
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
				  { 0.753, 0.812, 0.808, 1 } }
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

	entity:add(VillagerComponent({
		hairy = love.math.random() < 0.5,
		gender = gender,
		age = age
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

	local particleSystem = Blueprint.PARTICLE_SYSTEMS.WOOD_SPARK
	if not particleSystem then
		particleSystem = love.graphics.newParticleSystem(spriteSheet:getImage(), 32)
		particleSystem:setQuads(sprite:getQuad())
		particleSystem:setColors(0.388, 0.326, 0.263, 0.9)
		particleSystem:setEmissionRate(69)
		particleSystem:setEmitterLifetime(0.1)
		local _, _, w, h = sprite:getQuad():getViewport()
		particleSystem:setOffset(w/2, h/2)
		particleSystem:setInsertMode("random")
		particleSystem:setLinearAcceleration(0, 50, 0, 80)
		particleSystem:setRadialAcceleration(-2, -10)
		particleSystem:setEmissionArea("uniform", 2, 2)
		particleSystem:setParticleLifetime(0.3)
		particleSystem:setRotation(-math.pi, math.pi)
		particleSystem:setSpeed(30, 30)
		particleSystem:setSpread(2*math.pi)
		particleSystem:setSizeVariation(0.5)
		particleSystem:setSizes(1.0, 0.5)
		particleSystem:setSpin(-math.pi, math.pi)
		particleSystem:setSpinVariation(1)
		particleSystem:emit(1)

		Blueprint.PARTICLE_SYSTEMS.WOOD_SPARK = particleSystem
	end

	entity:add(ParticleComponent(particleSystem:clone(), true))
	entity:add(SpriteComponent(sprite))

	return entity
end

function Blueprint:createIronSparksParticle()
	local entity = lovetoys.Entity()
	local sprite = spriteSheet:getSprite("spark")

	local particleSystem = Blueprint.PARTICLE_SYSTEMS.IRON_SPARK
	if not particleSystem then
		particleSystem = love.graphics.newParticleSystem(spriteSheet:getImage(), 32)
		particleSystem:setQuads(sprite:getQuad())
		particleSystem:setColors(0.665, 0.680, 0.645, 0.9)
		particleSystem:setEmissionRate(69)
		particleSystem:setEmitterLifetime(0.1)
		local _, _, w, h = sprite:getQuad():getViewport()
		particleSystem:setOffset(w/2, h/2)
		particleSystem:setInsertMode("random")
		particleSystem:setLinearAcceleration(0, 50, 0, 80)
		particleSystem:setRadialAcceleration(-2, -10)
		particleSystem:setEmissionArea("uniform", 2, 2)
		particleSystem:setParticleLifetime(0.3)
		particleSystem:setRotation(-math.pi, math.pi)
		particleSystem:setSpeed(30, 30)
		particleSystem:setSpread(2*math.pi)
		particleSystem:setSizeVariation(0.5)
		particleSystem:setSizes(1.0, 0.5)
		particleSystem:setSpin(-math.pi, math.pi)
		particleSystem:setSpinVariation(1)
		particleSystem:emit(1)

		Blueprint.PARTICLE_SYSTEMS.IRON_SPARK = particleSystem
	end

	entity:add(ParticleComponent(particleSystem:clone(), true))
	entity:add(SpriteComponent(sprite))

	return entity
end

function Blueprint:createSmokeParticle()
	local entity = lovetoys.Entity()
	local sprite = spriteSheet:getSprite("smoke")

	local particleSystem = Blueprint.PARTICLE_SYSTEMS.SMOKE
	if not particleSystem then
		particleSystem = love.graphics.newParticleSystem(spriteSheet:getImage(), 32)
		particleSystem:setQuads(sprite:getQuad())
		particleSystem:setColors(1, 1, 1, 0.8,
		                         1, 1, 1, 0.5,
		                         1, 1, 1, 0.0)
		particleSystem:setEmissionRate(5)
		particleSystem:setEmitterLifetime(-1)
		local _, _, w, h = sprite:getQuad():getViewport()
		particleSystem:setOffset(w/2, h/2)
		particleSystem:setInsertMode("random")
		particleSystem:setLinearAcceleration(-0.5, -3, 0.5, -3)
		particleSystem:setRadialAcceleration(10, 10)
		particleSystem:setParticleLifetime(2, 3)
		particleSystem:setRotation(math.rad(1), math.rad(360))
		particleSystem:setSizeVariation(0.2)
		particleSystem:setSizes(0.5, 1.0, 2.5)
		particleSystem:setSpin(math.rad(5), math.rad(15))
		particleSystem:setSpinVariation(1)
		particleSystem:pause()

		Blueprint.PARTICLE_SYSTEMS.SMOKE = particleSystem
	end

	entity:add(ParticleComponent(particleSystem:clone(), false))
	entity:add(SpriteComponent(sprite))

	return entity
end

function Blueprint:createDustParticle(direction, small)
	local entity = lovetoys.Entity()
	local frames = spriteSheet:getFrameTag("Dust "..direction)
	local firstSprite, duration = spriteSheet:getSprite("dust-effect "..frames.from)

	local particleSystem = Blueprint.PARTICLE_SYSTEMS[(small and "SMALL_" or "").."DUST_"..direction]
	if not particleSystem then
		local quads = { firstSprite:getQuad() }
		for i=frames.from + 1, frames.to do
			table.insert(quads, spriteSheet:getSprite("dust-effect "..i):getQuad())
		end

		particleSystem = love.graphics.newParticleSystem(spriteSheet:getImage(), 32)
		particleSystem:setQuads(quads)
		particleSystem:setEmitterLifetime(0.1)
		local _, _, w, h = firstSprite:getQuad():getViewport()
		particleSystem:setOffset(w/2, h/2)
		particleSystem:setSpeed(15)
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
		particleSystem:setDirection(dir)
		particleSystem:setParticleLifetime(duration * #quads / 1000 / 2)
		if small then
			particleSystem:setEmissionRate(20)
			particleSystem:setEmissionArea("ellipse", 3, 15, dir)
			particleSystem:setSizes(0.4)
		else
			particleSystem:setEmissionRate(30)
			particleSystem:setEmissionArea("ellipse", 3, 25, dir)
			particleSystem:setSizes(0.6)
		end
		particleSystem:emit(1)

		Blueprint.PARTICLE_SYSTEMS[(small and "SMALL_" or "").."DUST_"..direction] = particleSystem
	end

	entity:add(ParticleComponent(particleSystem:clone(), true))
	entity:add(SpriteComponent(firstSprite))

	return entity
end

function Blueprint:createDeathParticle(villager)
	local entity = lovetoys.Entity()
	local sprite, key

	if villager:has("AdultComponent") then
		local hairy = villager:get("VillagerComponent"):isHairy() and "(Hairy) " or ""
		sprite = spriteSheet:getSprite("villagers "..hairy.."1", villager:get("VillagerComponent"):getGender().." - SE")
		key = "ADULT_DEATH"
	else
		sprite = spriteSheet:getSprite("children 1",
			(villager:get("VillagerComponent"):getGender() == "male" and "Boy" or "Girl").." - SE")
		key = "CHILD_DEATH"
	end

	local particleSystem = Blueprint.PARTICLE_SYSTEMS[key]
	if not particleSystem then
		particleSystem = love.graphics.newParticleSystem(spriteSheet:getImage(), 1)
		particleSystem:setQuads(sprite:getQuad())
		particleSystem:setColors(0.2, 0.2, 0.9, 0.8,
		                         0.2, 0.2, 0.9, 0.5,
								 0.2, 0.2, 0.9, 0.0)
		particleSystem:setEmissionRate(10)
		particleSystem:setEmitterLifetime(0.1)
		local _, _, w, h = sprite:getQuad():getViewport()
		particleSystem:setOffset(w/2, h/2)
		particleSystem:setLinearAcceleration(-0.5, -3, 0.5, -3)
		particleSystem:setRadialAcceleration(10)
		particleSystem:setParticleLifetime(3)
		particleSystem:emit(1)

		Blueprint.PARTICLE_SYSTEMS[key] = particleSystem
	end

	entity:add(ParticleComponent(particleSystem:clone(), true))
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
