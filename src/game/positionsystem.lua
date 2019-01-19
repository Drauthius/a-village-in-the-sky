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

function PositionSystem:onRemoveEntity(entity, group)
	--print("Remove event: "..tostring(entity)..", "..tostring(group))
	self.map:remove(entity)
end

return PositionSystem
