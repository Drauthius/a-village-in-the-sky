local class = require "lib.middleclass"

local EntityMovedEvent = class("EntityMovedEvent")

function EntityMovedEvent:initialize(entity)
	self.entity = entity
end

function EntityMovedEvent:getEntity()
	return self.entity
end

return EntityMovedEvent
