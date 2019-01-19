local lovetoys = require "lib.lovetoys.lovetoys"

local BuildingComponent = require "src.game.buildingcomponent"
local TileComponent = require "src.game.tilecomponent"

local state = require "src.game.state"

local PlacingSystem = lovetoys.System:subclass("PlacingSystem")

function PlacingSystem.requires()
	return {"PlacingComponent", "SpriteComponent"}
end

function PlacingSystem:initialize(map)
	lovetoys.System.initialize(self)
	self.map = map
end

function PlacingSystem:update(dt)
	for _,entity in pairs(self.targets) do
		if not state:isPlacing() then
			error("Not placing, but got a placing component")
		end

		local mx, my = state:getMousePosition()
		local ti, tj = self.map:worldToTileCoords(mx, my)
		ti, tj = math.floor(ti), math.floor(tj)

		local snap = self.map:isValidPosition(entity, entity:get("PlacingComponent"):isTile(), ti, tj)

		if entity:get("PlacingComponent"):isTile() then
			if snap then
				local type = entity:get("PlacingComponent"):getType()
				if type == "grass" then
					type = TileComponent.GRASS
				elseif type == "wood" then
					type = TileComponent.FOREST
				elseif type == "mountain" then
					type = TileComponent.MOUNTAIN
				else
					error("Unknown tile type "..tostring(type))
				end
				entity:set(TileComponent(type, ti, tj))
			elseif entity:has("TileComponent") then
				entity:remove("TileComponent")
			end
		else
			if snap then
				local type = entity:get("PlacingComponent"):getType()
				if type == "dwelling" then
					type = BuildingComponent.DWELLING
				elseif type == "blacksmith" then
					type = BuildingComponent.BLACKSMITH
				elseif type == "field" then
					type = BuildingComponent.FIELD
				elseif type == "bakery" then
					type = BuildingComponent.BAKERY
				else
					error("Unknown building type "..tostring(type))
				end
				entity:set(BuildingComponent(type, ti, tj))
			elseif entity:has("BuildingComponent") then
				entity:remove("BuildingComponent")
			end
		end

		local spriteComponent = entity:get("SpriteComponent")

		if entity:has("TileComponent") then
			local x, y = self.map:tileToWorldCoords(ti, tj)
			spriteComponent:setDrawPosition(x - self.map.halfTileWidth, y)
			spriteComponent:setColor(0.40, 1, 0.40, 0.8)
		elseif entity:has("BuildingComponent") then
			local x, y = self.map:tileToWorldCoords(ti, tj)
			spriteComponent:setDrawPosition(x - self.map.halfTileWidth,
					y - spriteComponent:getSprite():getHeight() + self.map.tileHeight)
			spriteComponent:setColor(0.40, 1, 0.40, 0.8)
		else
			local sprite = spriteComponent:getSprite()
			local dx, dy = mx - sprite:getWidth() / 2, my - sprite:getHeight() / 2
			spriteComponent:setDrawPosition(dx, dy)
			spriteComponent:setColor(1, 0.40, 0.40, 0.8)
		end
	end
end

return PlacingSystem
