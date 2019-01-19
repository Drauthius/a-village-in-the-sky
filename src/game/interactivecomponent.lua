local class = require "lib.middleclass"

local InteractiveComponent = class("InteractiveComponent")

function InteractiveComponent.static:makeInteractive(entity, x, y)
	local tx, ty, tw, th = entity:get("SpriteComponent"):getSprite():getTrimmedDimensions()
	entity:add(InteractiveComponent(x + tx, y + ty, tw, th))
end

function InteractiveComponent:initialize(x, y, w, h)
	self.x, self.y = x, y
	self.w, self.h = w, h
	self.ox, self.oy = 0, 0
	--print(("at %d,%d -> %d,%d"):format(x, y, x + w, y + h))
end

function InteractiveComponent:isWithin(x, y)
	return x >= self.x - self.ox and
		   y >= self.y - self.oy and
		   x <= self.x + self.w + self.ox and
		   y <= self.y + self.h + self.oy
end

function InteractiveComponent:move(dx, dy)
	self.x, self.y = self.x + dx, self.y + dy
end

return InteractiveComponent
