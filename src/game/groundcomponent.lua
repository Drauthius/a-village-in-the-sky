local class = require "lib.middleclass"

local GroundComponent = class("GroundComponent")

function GroundComponent.static:save()
	return {
		gx = self.gx,
		gy = self.gy
	}
end

function GroundComponent.static.load(_, data)
	return GroundComponent(data.gx, data.gy)
end

function GroundComponent:initialize(gx, gy)
	self:setPosition(gx, gy)
end

function GroundComponent:getPosition()
	return self.gx, self.gy
end

function GroundComponent:getIsometricPosition()
	return (self.gx - self.gy) / 2, (self.gx + self.gy) / 4
end

function GroundComponent:setPosition(gx, gy)
	self.gx, self.gy = gx, gy
end

return GroundComponent
