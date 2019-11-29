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

local lovetoys = require "lib.lovetoys.lovetoys"

local ChildbirthStartedEvent = require "src.game.childbirthstartedevent"
local ChildbirthEndedEvent = require "src.game.childbirthendedevent"

local PregnancyComponent = require "src.game.pregnancycomponent"
local TimerComponent = require "src.game.timercomponent"
local VillagerComponent = require "src.game.villagercomponent"

local PregnancySystem = lovetoys.System:subclass("PregnancySystem")

-- The age when fertility starts to decrease.
PregnancySystem.static.FERTILITY_DECREASE_AGE = 45
-- The amount it decreases per year.
PregnancySystem.static.FERTILITY_DECREASE_AMOUNT = 0.025

-- The age when menopause can affect a woman.
PregnancySystem.static.MENOPAUSE_AGE = 45
-- The accumulated chance per year to reach menopause.
PregnancySystem.static.MENOPAUSE_CHANCE = 0.025

-- Chance of intercourse when both adults are home.
PregnancySystem.static.INTERCOURSE_CHANCE = 0.95
-- Decrease for each child.
PregnancySystem.static.INTERCOURSE_CHILD_DECREASE = 0.05
-- Maximum number of children.
PregnancySystem.static.MAX_CHILDREN = 6

-- Number of days that the pregnancy can be early or late, in years.
PregnancySystem.static.PREGNANCY_VARIATION = 15 / 365
-- Time before the mother makes her way home to give birth, in years.
PregnancySystem.static.PREGNANCY_START = 2 / 12
-- Time that the pregnancy can overshoot in case the villager has a long way home, in years.
PregnancySystem.static.PREGNANCY_FINAL = 1 / 12

-- The chance that the mother dies during child birth.
PregnancySystem.static.MORTALITY_MOTHER = 0.0125
-- The chance that the child dies during child birth.
PregnancySystem.static.MORTALITY_CHILD = 0.025

function PregnancySystem.requires()
	return {"PregnancyComponent"}
end

function PregnancySystem:initialize(eventManager)
	lovetoys.System.initialize(self)
	self.eventManager = eventManager
end

function PregnancySystem:update(dt)
	for _,entity in pairs(self.targets) do
		local pregnancy = entity:get("PregnancyComponent")
		local expected = pregnancy:getExpected()
		local left = expected - TimerComponent.YEARS_PER_SECOND * dt

		if left <= PregnancySystem.PREGNANCY_START and expected > PregnancySystem.PREGNANCY_START then
			pregnancy:setInLabour(true)
			-- Send event to drop what you're doing and start making your way home.
			self.eventManager:fireEvent(ChildbirthStartedEvent(entity))
		elseif left <= 0 then
			local indoors = entity:get("VillagerComponent"):isHome()
			if indoors or left <= -PregnancySystem.PREGNANCY_FINAL then
				local motherDied, childDied
				if not indoors then
					-- The villager has no home or didn't make it back in time.
					childDied = true
				else
					childDied = love.math.random() < PregnancySystem.MORTALITY_CHILD
				end

				motherDied = love.math.random() < PregnancySystem.MORTALITY_MOTHER
				entity:remove("PregnancyComponent")

				local father, fatherUnique = pregnancy:getFather()
				self.eventManager:fireEvent(ChildbirthEndedEvent(entity, father, fatherUnique, motherDied, childDied, indoors))
				return
			end
		end

		pregnancy:setExpected(left)
	end
end

function PregnancySystem:buildingEnteredEvent(event)
	local entity = event:getVillager()

	if not entity:has("FertilityComponent") then
		return
	end

	-- Only in the privacy of their own home.
	if not event:getBuilding():has("DwellingComponent") then
		return
	end

	local buildingEntity = event:getBuilding()
	local building = buildingEntity:get("BuildingComponent")
	local dwelling = buildingEntity:get("DwellingComponent")

	-- Check whether there are two fertile individuals of different gender in the same building.
	-- This is done a bit hacky, because the parents might have a grown child living with them.
	local villagers = buildingEntity:get("AssignmentComponent"):getAssignees()
	-- Two people are needed to tango.
	if #villagers < 2 or #building:getInside() < 2 then
		return
	-- Of opposite gender.
	elseif villagers[1]:get("VillagerComponent"):getGender() == villagers[2]:get("VillagerComponent"):getGender() then
		return
	end
	for _,v in ipairs(building:getInside()) do
		-- The assigned villagers are the only ones that can produce a baby.
		if v ~= villagers[1] and v ~= villagers[2] then
			return
		-- If they are still fertile.
		elseif not v:has("FertilityComponent") then
			return
		-- And not already pregnant.
		elseif v:has("PregnancyComponent") then
			return
		-- Or recovering from a pregnancy.
		elseif v:get("VillagerComponent"):getGoal() == VillagerComponent.GOALS.CHILDBIRTH then
			return
		end
	end

	-- Check whether the individuals are related, or if there are already too many children.
	if dwelling:isRelated() or dwelling:getNumChildren() >= PregnancySystem.MAX_CHILDREN then
		return
	end

	-- Decrease chance per child living with the couple.
	local intercourseChance = PregnancySystem.INTERCOURSE_CHANCE -
	                          (dwelling:getNumBoys() + dwelling:getNumGirls()) * PregnancySystem.INTERCOURSE_CHILD_DECREASE

	local pregnancyChance = intercourseChance *
	                        math.min(villagers[1]:get("FertilityComponent"):getFertility(),
	                                 villagers[2]:get("FertilityComponent"):getFertility())
	if love.math.random() < pregnancyChance then
		local mother = villagers[1]:get("VillagerComponent"):getGender() == "female" and villagers[1] or villagers[2]
		local father = mother == villagers[1] and villagers[2] or villagers[1]
		assert(mother:get("VillagerComponent"):getGender() == "female", "No mother?")
		assert(father:get("VillagerComponent"):getGender() == "male", "No father?")

		--print(tostring(mother).." became pregnant with "..tostring(father).."'s baby.")
		local expected = 9 / 12 -- 9 months
		expected = expected +
		           love.math.random(-PregnancySystem.PREGNANCY_VARIATION, PregnancySystem.PREGNANCY_VARIATION)
		mother:add(PregnancyComponent(expected, father))
	end
end

function PregnancySystem:villagerAgedEvent(event)
	local entity = event:getVillager()
	local villager = entity:get("VillagerComponent")

	if not entity:has("FertilityComponent") then
		return
	end

	-- Decrease fertility after a certain age.
	if villager:getAge() >= PregnancySystem.FERTILITY_DECREASE_AGE then
		local fertility = entity:get("FertilityComponent"):getFertility()
		fertility = fertility - PregnancySystem.FERTILITY_DECREASE_AMOUNT
		if fertility <= 0 then
			print(entity, "has become infertile at the age of "..villager:getAge()..".")
			entity:remove("FertilityComponent")
			return
		end

		entity:get("FertilityComponent"):setFertility(fertility)
	end

	-- Check for menopause.
	if entity:get("VillagerComponent"):getGender() == "female" then
		local ageDiff = villager:getAge() - PregnancySystem.MENOPAUSE_AGE
		if ageDiff > 0 and
		   love.math.random() < ageDiff * PregnancySystem.MENOPAUSE_CHANCE then
			print(entity, "has reached menopause at the age of "..villager:getAge().. ".")
			entity:remove("FertilityComponent")
		end
	end
end

return PregnancySystem
