local lovetoys = require "lib.lovetoys.lovetoys"

local state = require "src.game.state"

local ResourceSystem = lovetoys.System:subclass("ResourceSystem")

function ResourceSystem.requires()
	return {"ResourceComponent"}
end

function ResourceSystem:initialize(map)
	lovetoys.System.initialize(self)
	self.map = map
end

function ResourceSystem:update(dt)
end

-- Called when an entity gets the resource component.
function ResourceSystem:onAddEntity(entity)
	local resource = entity:get("ResourceComponent")

	-- Only update harvested resources.
	if resource:isUsable() then
		local sprite = entity:get("SpriteComponent")
		local grid = entity:get("PositionComponent"):getGrid()

		local ox, oy = self.map:gridToWorldCoords(grid.gi, grid.gj)
		ox = ox - self.map.halfGridWidth
		oy = oy - sprite:getSprite():getHeight() + self.map.gridHeight

		sprite:setDrawPosition(ox, oy)

		state:increaseResource(resource:getResource(), resource:getResourceAmount())
	end
end

-- Called when an entity with the resource component is removed, or the resource component is removed.
function ResourceSystem:onRemoveEntity(entity)
	-- FIXME: State updating is currently not handled here, since it is possible to partially take a resource.
end

return ResourceSystem
