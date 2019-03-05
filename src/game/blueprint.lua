local class = require "lib.middleclass"
local lovetoys = require "lib.lovetoys.lovetoys"

local BuildingComponent = require "src.game.buildingcomponent"
local CollisionComponent = require "src.game.collisioncomponent"
local ParticleComponent = require "src.game.particlecomponent"
local PlacingComponent = require "src.game.placingcomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local RunestoneComponent = require "src.game.runestonecomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TileComponent = require "src.game.tilecomponent"
local WorkComponent = require "src.game.workcomponent"

local spriteSheet = require "src.game.spritesheet"

local Blueprint = class("Blueprint")

Blueprint.static.PARTICLE_SYSTEMS = {}

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
		particleSystem:setEmissionArea("ellipse", 3, 20, dir)
		particleSystem:setParticleLifetime(duration * #quads / 1000 / 2)
		if small then
			particleSystem:setEmissionRate(20)
			particleSystem:setSizes(0.4)
		else
			particleSystem:setEmissionRate(30)
			particleSystem:setSizes(0.6)
		end
		particleSystem:emit(1)

		Blueprint.PARTICLE_SYSTEMS[(small and "SMALL_" or "").."DUST_"..direction] = particleSystem
	end

	entity:add(ParticleComponent(particleSystem:clone(), true))
	entity:add(SpriteComponent(firstSprite))

	return entity
end

return Blueprint()
