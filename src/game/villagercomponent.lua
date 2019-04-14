local class = require "lib.middleclass"

local VillagerComponent = class("VillagerComponent")

VillagerComponent.static.GOALS = {
	NONE = 0,
	DROPOFF = 1,
	FOOD_PICKUP = 2,
	FOOD_DROPOFF = 3,
	WORK_PICKUP = 4,
	WORK = 5,
	SLEEP = 6,
	EAT = 7,
	WAIT = 8,
	MOVING = 9,
	CHILDBIRTH = 10
}

function VillagerComponent:initialize(stats, mother, father)
	self.name = stats.name or "Uh"
	self.age = stats.age or 0.0 -- 0-death
	self.hairy = stats.hairy or false
	self.gender = stats.gender

	self.alive = true

	self.strength = stats.strength or 0.5 -- 0-1
	self.craftsmanship = stats.craftsmanship or 0.5 -- 0.1

	self.hunger = 0.0 -- 0-1
	self.starvation = 0.0 -- 0-1
	self.sleepiness = 0.0 -- 0-1

	self.direction = love.math.random(0, 359) -- 0-359

	self.goal = VillagerComponent.GOALS.NONE
	self.delay = 0.0
	self.home = nil
	self.isAtHome = false

	-- NOTE: These references need to be cleared to release the entities completely.
	self.mother = mother
	self.father = father
	self.children = {}
end

function VillagerComponent:getName()
	return self.name
end

function VillagerComponent:getAge()
	return self.age
end

function VillagerComponent:increaseAge(dt)
	self.age = self.age + dt
end

function VillagerComponent:getGender()
	return self.gender
end

function VillagerComponent:isHairy()
	return self.hairy
end

function VillagerComponent:getStrength()
	return self.strength
end

function VillagerComponent:getCraftsmanship()
	return self.craftsmanship
end

function VillagerComponent:isDead()
	return not self.alive
end

function VillagerComponent:setDead()
	self.alive = false
end

function VillagerComponent:getHunger()
	return self.hunger
end

function VillagerComponent:setHunger(hunger)
	self.hunger = hunger
end

function VillagerComponent:getStarvation()
	return self.starvation
end

function VillagerComponent:setStarvation(starvation)
	self.starvation = starvation
end

function VillagerComponent:getSleepiness()
	return self.sleepiness
end

function VillagerComponent:setSleepiness(sleepiness)
	self.sleepiness = sleepiness
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

function VillagerComponent:getGoal()
	return self.goal
end

function VillagerComponent:setGoal(goal)
	self.goal = goal
end

function VillagerComponent:getDelay()
	return self.delay
end

function VillagerComponent:setDelay(delay)
	self.delay = delay
end

function VillagerComponent:decreaseDelay(dt)
	self.delay = self.delay - dt
end

function VillagerComponent:getHome()
	return self.home
end

function VillagerComponent:setHome(home)
	self.home = home
end

function VillagerComponent:isHome()
	return self.isAtHome
end

function VillagerComponent:setIsHome(isAtHome)
	self.isAtHome = isAtHome
end

function VillagerComponent:getMother()
	return self.mother
end

function VillagerComponent:getFather()
	return self.mother
end

function VillagerComponent:addChild(child)
	table.insert(self.children, child)
end

function VillagerComponent:getChildren()
	return self.children
end

function VillagerComponent:clear()
	self.mother = nil
	self.father = nil
	self.children = {}
end

return VillagerComponent
