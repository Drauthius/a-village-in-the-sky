local lovetoys = require "lib.lovetoys.lovetoys"

local RunestoneUpgradedEvent = require "src.game.runestoneupgradedevent"

local AnimationComponent = require "src.game.animationcomponent"
local AssignmentComponent = require "src.game.assignmentcomponent"
local BuildingComponent = require "src.game.buildingcomponent"
local DwellingComponent = require "src.game.dwellingcomponent"
local EntranceComponent = require "src.game.entrancecomponent"
local FieldEnclosureComponent = require "src.game.fieldenclosurecomponent"
local PositionComponent = require "src.game.positioncomponent"
local ProductionComponent = require "src.game.productioncomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TimerComponent = require "src.game.timercomponent"

local blueprint = require "src.game.blueprint"
local soundManager = require "src.soundmanager"
local spriteSheet = require "src.game.spritesheet"

local BuildingSystem = lovetoys.System:subclass("BuildingSystem")

BuildingSystem.static.DOOR_OPEN_TIME = 0.5

function BuildingSystem.requires()
	return {"BuildingComponent"}
end

function BuildingSystem:initialize(engine, eventManager)
	lovetoys.System.initialize(self)

	self.engine = engine
	self.eventManager = eventManager
end

function BuildingSystem:update(dt)
end

function BuildingSystem:buildingCompletedEvent(event)
	local entity = event:getBuilding()
	local building = entity:get("BuildingComponent")

	local chimneys = 0
	local type = building:getType()
	local typeName = BuildingComponent.BUILDING_NAME[type]

	if type == BuildingComponent.DWELLING then
		entity:add(AssignmentComponent(2))
		entity:add(DwellingComponent())
		entity:add(EntranceComponent(type))

		chimneys = 2
	elseif type == BuildingComponent.BLACKSMITH then
		entity:add(AssignmentComponent(1))
		entity:add(EntranceComponent(type))
		entity:add(ProductionComponent(type))

		chimneys = 1
	elseif type == BuildingComponent.FIELD then
		entity:add(AssignmentComponent(2))
		entity:add(FieldEnclosureComponent())
	elseif type == BuildingComponent.BAKERY then
		entity:add(AssignmentComponent(3))
		entity:add(EntranceComponent(type))
		entity:add(ProductionComponent(type))

		chimneys = 3

		-- Create the nice propeller.
		local propeller = lovetoys.Entity(entity)
		local propellerData = spriteSheet:getData("Blades") -- Edgy
		local sprite = spriteSheet:getSprite("windmill-blades 0")
		local position = entity:get("PositionComponent")
		propeller:add(PositionComponent(position:getGrid(), nil, position:getTile()))
		local dx, dy = entity:get("SpriteComponent"):getDrawPosition()
		dx = dx + propellerData.bounds.x + math.floor((propellerData.bounds.w - sprite:getWidth()) / 2)
		dy = dy + propellerData.bounds.y + math.floor((propellerData.bounds.h - sprite:getHeight()) / 2)
		-- Not sure about the offset.
		propeller:add(SpriteComponent(sprite, dx + 2, dy + 2))

		self.engine:addEntity(propeller)

		-- We'll save it here for now.
		building.propeller = propeller
	elseif type == BuildingComponent.RUNESTONE then
		-- XXX: Might not want to handle it here?
		entity:get("RunestoneComponent"):setLevel(entity:get("RunestoneComponent"):getLevel() + 1)
		entity:get("SpriteComponent"):setNeedsRefresh(true)
		self.eventManager:fireEvent(RunestoneUpgradedEvent(entity))
	else
		error("Dunno what to do with "..tostring(typeName).." :(")
	end

	for i=1,chimneys do
		local position = entity:get("PositionComponent")
		local chimneyData = spriteSheet:getData(typeName.."-chimney"..(chimneys == 1 and "" or i))
		local chimney = blueprint:createSmokeParticle()
		chimney:add(AssignmentComponent(1))
		chimney:add(PositionComponent(position:getGrid(), nil, position:getTile()))
		local dx, dy = entity:get("SpriteComponent"):getOriginalDrawPosition()
		dx = dx + chimneyData.bounds.x + math.floor(chimneyData.bounds.w / 2)
		dy = dy + chimneyData.bounds.y + math.floor(chimneyData.bounds.h / 2)
		chimney:get("SpriteComponent"):setDrawPosition(dx, dy)
		chimney:setParent(entity)
		self.engine:addEntity(chimney)
		building:addChimney(chimney)
	end
end

function BuildingSystem:buildingEnteredEvent(event)
	local entity = event:getBuilding()

	self:_openDoor(entity)

	if not event:isTemporary() then
		local building = entity:get("BuildingComponent")
		local villager = event:getVillager()

		self:_assignChimney(entity, villager)
		building:addInside(villager)

		-- Propeller!
		if building:getType() == BuildingComponent.BAKERY and not building.propeller:has("AnimationComponent") then
			local propeller = building.propeller
			local animation = AnimationComponent()
			local frames = {}
			for i=0,2 do
				table.insert(frames, { spriteSheet:getSprite("windmill-blades "..i) })
			end
			animation:setAnimation({ from = 1, to = 3 })
			animation:setFrames(frames)
			local currentFrame
			for k,v in ipairs(frames) do
				if v[1] == building.propeller:get("SpriteComponent"):getSprite() then
					currentFrame = k
					break
				end
			end
			animation:setCurrentFrame(assert(currentFrame, "Uh-oh"))

			-- Wind up.
			local frame1, frame2 = math.max(1, (currentFrame + 1) % (#frames + 1)),
			                       math.max(1, (currentFrame + 2) % (#frames + 1))
			local oldDur, oldDur1, oldDur2 = frames[currentFrame][2], frames[frame1][2], frames[frame2][2]
			local newDur, newDur1, newDur2 = oldDur * 1.5, oldDur1 * 3.5, oldDur2 * 2.5
			frames[currentFrame][2], frames[frame1][2], frames[frame2][2] = newDur, newDur1, newDur2
			animation:setTimer(oldDur * 4 / 1000.0)
			propeller:set(TimerComponent((newDur + newDur1 + newDur2 + 10) / 1000, function()
				frames[currentFrame][2] = oldDur
				frames[frame1][2] = oldDur1
				frames[frame2][2] = oldDur2
				propeller:remove("TimerComponent")
			end))

			propeller:add(animation)
		end
	end
end

function BuildingSystem:buildingLeftEvent(event)
	local entity = event:getBuilding()
	local villager = event:getVillager()
	local building = entity:get("BuildingComponent")

	self:_openDoor(entity)
	self:_unassignChimney(entity, villager)

	building:removeInside(villager)

	-- Stop the propeller, if everyone has left.
	if building:getType() == BuildingComponent.BAKERY and #building:getInside() < 1 then
		local propeller = building.propeller

		local frames = propeller:get("AnimationComponent"):getFrames()
		local currentFrame = propeller:get("AnimationComponent"):getCurrentFrame()

		-- Wind down.
		local frame1, frame2 = math.max(1, (currentFrame + 1) % (#frames + 1)),
							   math.max(1, (currentFrame + 2) % (#frames + 1))
		local oldDur, oldDur1, oldDur2 = frames[currentFrame][2], frames[frame1][2], frames[frame2][2]
		local newDur, newDur1, newDur2 = oldDur * 3.5, oldDur1 * 1.5, oldDur2 * 2.5
		frames[currentFrame][2], frames[frame1][2], frames[frame2][2] = newDur, newDur1, newDur2
		propeller:set(TimerComponent((newDur + newDur1 + newDur2 + 10) / 1000.0, function()
			frames[currentFrame][2] = oldDur
			frames[frame1][2] = oldDur1
			frames[frame2][2] = oldDur2
			propeller:remove("TimerComponent")
			propeller:remove("AnimationComponent")
		end))
	end
end

function BuildingSystem:_openDoor(entity)
	soundManager:playEffect("doorOpened")
	entity:get("EntranceComponent"):setOpen(true)
	entity:get("SpriteComponent"):setNeedsRefresh(true)

	entity:set(TimerComponent(BuildingSystem.DOOR_OPEN_TIME, function()
		entity:get("EntranceComponent"):setOpen(false)
		entity:get("SpriteComponent"):setNeedsRefresh(true)
		soundManager:playEffect("doorClosed")
	end))
end

function BuildingSystem:_assignChimney(entity, villager)
	-- Check whether the child is living with a parent. In that case, they don't get a chimney.
	if entity:has("DwellingComponent") then
		local livingWithParents = true
		for _,v in ipairs(entity:get("AssignmentComponent"):getAssignees()) do
			if v == villager then
				livingWithParents = false
				break
			end
		end

		if livingWithParents then
			return
		end
	end

	for _,chimney in ipairs(entity:get("BuildingComponent"):getChimneys()) do
		if chimney:get("AssignmentComponent"):getNumAssignees() < 1 then
			chimney:get("AssignmentComponent"):assign(villager)
			chimney:get("ParticleComponent"):getParticleSystem():start()
			return
		end
	end

	error("No free chimney?")
end

function BuildingSystem:_unassignChimney(entity, villager)
	-- Check whether the child is living with a parent. In that case, they don't get a chimney.
	if entity:has("DwellingComponent") then
		local livingWithParents = true
		for _,v in ipairs(entity:get("AssignmentComponent"):getAssignees()) do
			if v == villager then
				livingWithParents = false
				break
			end
		end

		if livingWithParents then
			return
		end
	end

	for _,chimney in ipairs(entity:get("BuildingComponent"):getChimneys()) do
		if chimney:get("AssignmentComponent"):isAssigned(villager) then
			chimney:get("AssignmentComponent"):unassign(villager)
			chimney:get("ParticleComponent"):getParticleSystem():pause()
			return
		end
	end

	error("No chimney removed?")
end

return BuildingSystem
