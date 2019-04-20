local lovetoys = require "lib.lovetoys.lovetoys"

local PositionSystem = lovetoys.System:subclass("PositionSystem")

function PositionSystem.requires()
	return {"PositionComponent"}
end

function PositionSystem:initialize(map)
	lovetoys.System.initialize(self)
	self.map = map
end

function PositionSystem:update(dt)
end

-- Called when an entity gets the position component.
function PositionSystem:onAddEntity(entity)
	if entity:has("VillagerComponent") then
		local grid = entity:get("PositionComponent"):getGrid()
		self.map:occupy(entity, grid)
		entity:get("PositionComponent"):setTile(self.map:gridToTileCoords(grid.gi, grid.gj))
	end
end

-- Called when an entity with the position component is removed, or the position component is removed.
function PositionSystem:onRemoveEntity(entity)
	-- Unreserve any reserved grids.
	-- XXX: The call is different depending on the type of the entity.
	if entity:has("VillagerComponent") then
		self.map:unoccupy(entity, entity:get("PositionComponent"):getGrid())
	else
		self.map:remove(entity)
	end
end

return PositionSystem
