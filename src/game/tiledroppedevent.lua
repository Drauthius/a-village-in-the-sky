local class = require "lib.middleclass"

local TileDroppedEvent = class("TileDroppedEvent")

function TileDroppedEvent:initialize(tile)
	self.tile = tile
end

function TileDroppedEvent:getTile()
	return self.tile
end

return TileDroppedEvent
