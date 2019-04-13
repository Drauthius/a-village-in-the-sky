local class = require "lib.middleclass"

local TilePlacedEvent = class("TilePlacedEvent")

function TilePlacedEvent:initialize(tile)
	self.tile = tile
end

function TilePlacedEvent:getTile()
	return self.tile
end

return TilePlacedEvent
