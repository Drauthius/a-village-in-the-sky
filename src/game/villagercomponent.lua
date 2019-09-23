--[[
Copyright (C) 2019  Albert Diserholt (@Drauthius)

This file is part of A Village in the Sky.

A Village in the Sky is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

A Village in the Sky is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with A Village in the Sky. If not, see <http://www.gnu.org/licenses/>.
--]]

local class = require "lib.middleclass"

local VillagerComponent = class("VillagerComponent")

VillagerComponent.static.GOALS = {
	NONE = 0,
	DROPOFF = 1,
	DROPPING_OFF = 2,
	PICKING_UP = 3,
	FOOD_PICKUP = 4,
	FOOD_PICKING_UP = 5,
	FOOD_DROPOFF = 6,
	WORK_PICKUP = 7,
	WORK_PICKING_UP = 8,
	WORK = 9,
	SLEEP = 10,
	SLEEPING = 11,
	EAT = 12,
	EATING = 13,
	MOVING = 14,
	CHILDBIRTH = 15
}

VillagerComponent.static.UNIQUE = 0
VillagerComponent.static.FEMININE_NAMES = require "asset.misc.feminine_names"
VillagerComponent.static.MASCULINE_NAMES = require "asset.misc.masculine_names"

function VillagerComponent.static:save(cassette)
	return {
		unique = self.unique,
		name = self.name,
		age = self.age,
		hairy = self.hairy,
		gender = self.gender,
		strength = self.strength,
		craftsmanship = self.craftsmanship,
		hunger = self.hunger,
		starvation = self.starvation,
		sleepiness = self.sleepiness,
		direction = self.direction,
		goal = self.goal,
		delay = self.delay,
		targetEntity = self.targetEntity and cassette:saveEntity(self.targetEntity) or nil,
		targetGrid = self.targetGrid and cassette:saveGrid(self.targetGrid) or nil,
		targetRotation = self.targetRotation,
		home = self.home and cassette:saveEntity(self.home) or nil,
		isAtHome = self.isAtHome,
		mother = self.mother and cassette:saveEntity(self.mother) or nil,
		motherUnique = self.motherUnique,
		father = self.father and cassette:saveEntity(self.father) or nil,
		fatherUnique = self.fatherUnique,
		children = cassette:saveEntityList(self.children)
	}
end

function VillagerComponent.static.load(cassette, data)
	local component = VillagerComponent:allocate()

	component.unique = data.unique
	component.name = data.name
	component.age = data.age
	component.hairy = data.hairy
	component.gender = data.gender
	component.strength = data.strength
	component.craftsmanship = data.craftsmanship
	component.hunger = data.hunger
	component.starvation = data.starvation
	component.sleepiness = data.sleepiness
	component.direction = data.direction
	component.goal = data.goal
	component.delay = data.delay
	component.targetEntity = data.targetEntity and cassette:loadEntity(data.targetEntity) or nil
	component.targetGrid = data.targetGrid and cassette:loadGrid(data.targetGrid) or nil
	component.targetRotation = data.targetRotation
	component.home = data.home and cassette:loadEntity(data.home) or nil
	component.isAtHome = data.isAtHome
	component.mother = data.mother and cassette:loadEntity(data.mother) or nil
	component.motherUnique = data.motherUnique
	component.father = data.father and cassette:loadEntity(data.father) or nil
	component.fatherUnique = data.fatherUnique
	component.children = cassette:loadEntityList(data.children)

	return component
end

function VillagerComponent:initialize(stats, mother, father)
	self.unique = VillagerComponent.UNIQUE
	VillagerComponent.static.UNIQUE = VillagerComponent.UNIQUE + 1

	self.age = stats.age or 0.0 -- 0-death
	self.hairy = stats.hairy or false
	self.gender = stats.gender -- "male" or "female"

	if self.gender == "male" then
		self.name = VillagerComponent.MASCULINE_NAMES[love.math.random(1, #VillagerComponent.MASCULINE_NAMES)]
	else
		self.name = VillagerComponent.FEMININE_NAMES[love.math.random(1, #VillagerComponent.FEMININE_NAMES)]
	end

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

	self.targetEntity = nil
	self.targetGrid = nil
	self.targetRotation = nil

	-- NOTE: These references need to be cleared to release the entities completely.
	self.mother = mother
	self.father = father
	self.children = {}

	-- XXX: The uniques will someday ruin someone's game.
	-- Note to self: Do not pass math.huge to love.math.random. It will not return a valid number.
	self.motherUnique = mother and mother:get("VillagerComponent"):getUnique() or -love.math.random(math.pow(2, 31))
	self.fatherUnique = father and father:get("VillagerComponent"):getUnique() or -love.math.random(math.pow(2, 31))
end

function VillagerComponent:getUnique()
	return self.unique
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

function VillagerComponent:getTargetEntity()
	return self.targetEntity
end

function VillagerComponent:setTargetEntity(entity)
	self.targetEntity = entity
end

function VillagerComponent:getTargetGrid()
	return self.targetGrid
end

function VillagerComponent:setTargetGrid(grid)
	self.targetGrid = grid
end

function VillagerComponent:getTargetRotation()
	return self.targetRotation
end

function VillagerComponent:setTargetRotation(rotation)
	self.targetRotation = rotation
end

function VillagerComponent:getMother()
	return self.mother, self.motherUnique
end

function VillagerComponent:clearMother()
	self.mother = nil
end

function VillagerComponent:getFather()
	return self.father, self.fatherUnique
end

function VillagerComponent:clearFather()
	self.father = nil
end

function VillagerComponent:addChild(child)
	table.insert(self.children, child)
end

function VillagerComponent:getChildren()
	return self.children
end

function VillagerComponent:removeChild(child)
	for i,v in ipairs(self.children) do
		if v == child then
			table.remove(self.children, i)
			return
		end
	end

	error("Child not found")
end

return VillagerComponent
