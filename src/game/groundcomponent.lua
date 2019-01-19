local class = require "lib.middleclass"

local GroundComponent = class("GroundComponent")

function GroundComponent:initialize(gx, gy)
	self:setPosition(gx, gy)
end

function GroundComponent:getPosition()
	return self.gx, self.gy
end

function GroundComponent:setPosition(gx, gy)
	self.gx, self.gy = gx, gy
end

return GroundComponent
