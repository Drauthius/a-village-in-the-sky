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

function Blueprint:createSmokeParticle()
	local entity = lovetoys.Entity()
	local sprite = spriteSheet:getSprite("smoke")

	local particleSystem = Blueprint.PARTICLE_SYSTEMS.SMOKE
	if not particleSystem then
		particleSystem = love.graphics.newParticleSystem(spriteSheet:getImage(), 15)
		particleSystem:setQuads(sprite:getQuad())
		particleSystem:setColors(1, 1, 1, 1,
		                         1, 1, 1, 0.7,
		                         1, 1, 1, 0)
		particleSystem:setEmissionRate(1.8)
		particleSystem:setEmitterLifetime(-1)
		local _, _, w, h = sprite:getQuad():getViewport()
		particleSystem:setOffset(w/2, h/2)
		particleSystem:setInsertMode("random")
		particleSystem:setLinearAcceleration(-1, -4, 1, -4)
		particleSystem:setRadialAcceleration(12, 12)
		particleSystem:setParticleLifetime(2, 3)
		particleSystem:setRotation(math.rad(1), math.rad(360))
		particleSystem:setSizeVariation(0.2)
		particleSystem:setSizes(0.5, 1.0, 1.5, 2)
		particleSystem:setSpin(math.rad(5), math.rad(15))
		particleSystem:setSpinVariation(1)

		Blueprint.PARTICLE_SYSTEMS.SMOKE = particleSystem
	end

	entity:add(ParticleComponent(particleSystem:clone(), false))
	entity:add(SpriteComponent(sprite))

	return entity
end

return Blueprint()
