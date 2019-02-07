local class = require "lib.middleclass"

local WorkComponent = require "src.game.workcomponent"

local VillagerComponent = class("VillagerComponent")

VillagerComponent.static.GOALS = {
	NONE = 0,
	DROPOFF = 1,
	WORK_PICKUP = 2,
	WORK = 3,
	WAIT = 4
}

function VillagerComponent:initialize(stats)
	self.name = stats.name or "Uh"
	self.age = stats.age or 0.0
	self.adult = self.age >= 16
	self.gender = stats.gender
	self.strength = stats.strength or 0.5
	self.craftsmanship = stats.craftsmanship or 0.5

	self.direction = love.math.random(0, 359)
	self.palette = love.math.random(1, 2)
	self.hairy = love.math.random(0, 1) == 1

	self.speedModifier = 1
	self.goal = VillagerComponent.GOALS.NONE
	self.home = nil
	self.workPlace = nil
	self.occupation = 0
end

function VillagerComponent:getName()
	return self.name
end

function VillagerComponent:getAge()
	return self.age
end

function VillagerComponent:isAdult()
	return self.adult
end

function VillagerComponent:getGender()
	return self.gender
end

function VillagerComponent:getStrenth()
	return self.strength
end

function VillagerComponent:getCraftsmanship()
	return self.craftsmanship
end

function VillagerComponent:isHairy()
	return self.hairy
end

function VillagerComponent:getPalette()
	return self.palette
end

function VillagerComponent:getDirection()
	return self.direction
end

function VillagerComponent:setDirection(dir)
	assert(dir >= 0 and dir <= 360, "Bad direction")
	self.direction = dir
end

function VillagerComponent:getCardinalDirection()
	-- Figure out the cardinal direction.
	-- Note! Directions are assumed to be in the isometric projection.
	-- (The sprites/slices were created that way.)
	local direction = self:getDirection()
	if direction >= 337.5 or direction <= 22.5 then
		return "N"
	elseif direction >= 22.5 and direction <= 67.5 then
		return "NE"
	elseif direction >= 67.5 and direction <= 112.5 then
		return "E"
	elseif direction >= 112.5 and direction <= 157.5 then
		return "SE"
	elseif direction >= 157.5 and direction <= 202.5 then
		return "S"
	elseif direction >= 202.5 and direction <= 247.5 then
		return "SW"
	elseif direction >= 247.5 and direction <= 292.5 then
		return "W"
	elseif direction >= 292.5 and direction <= 337.5 then
		return "NW"
	end
end

function VillagerComponent:getState()
	return self.state
end

function VillagerComponent:getGoal()
	return self.goal
end

function VillagerComponent:setGoal(goal)
	self.goal = goal
end

function VillagerComponent:getHome()
	return self.home
end

function VillagerComponent:setHome(home)
	self.home = home
end

function VillagerComponent:getWorkPlace()
	return self.workPlace
end

function VillagerComponent:setWorkPlace(entity)
	self.workPlace = entity
end

function VillagerComponent:setOccupation(occupation)
	self.occupation = occupation
end

function VillagerComponent:getOccupation()
	return self.occupation
end

function VillagerComponent:getOccupationName()
	return WorkComponent.WORK_NAME[self.occupation]
end

function VillagerComponent:getSpeedModifier()
	return self.speedModifier
end

return VillagerComponent
