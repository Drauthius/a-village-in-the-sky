local class = require "lib.middleclass"

local Level = class("Level")

function Level:initiate(engine)
	error("Must be overridden")
end

function Level:getResources(tileType)
	return 0, 0
end

function Level:shouldPlaceRunestone()
	return false
end

return Level
