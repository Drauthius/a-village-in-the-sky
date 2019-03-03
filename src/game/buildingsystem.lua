local lovetoys = require "lib.lovetoys.lovetoys"

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

function BuildingSystem:initialize(engine)
	lovetoys.System.initialize(self)

	self.engine = engine
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
		local propeller = lovetoys.Entity()
		local propellerData = spriteSheet:getData("Blades") -- Edgy
		local sprite = spriteSheet:getSprite("windmill-blades 0")
		propeller:add(PositionComponent(entity:get("PositionComponent"):getGrid())) -- TODO
		local dx, dy = entity:get("SpriteComponent"):getDrawPosition()
		dx = dx + propellerData.bounds.x + math.floor((propellerData.bounds.w - sprite:getWidth()) / 2)
		dy = dy + propellerData.bounds.y + math.floor((propellerData.bounds.h - sprite:getHeight()) / 2)
		-- Not sure about the offset.
		propeller:add(SpriteComponent(sprite, dx + 2, dy + 2))

		self.engine:addEntity(propeller, entity)

		-- We'll save it here for now.
		building.propeller = propeller
	else
		error("Dunno what to do with "..tostring(typeName).." :(")
	end

	for i=1,chimneys do
		local chimneyData = spriteSheet:getData(typeName.."-chimney"..(chimneys == 1 and "" or i))
		local chimney = blueprint:createSmokeParticle()
		chimney:add(AssignmentComponent(1))
		chimney:add(PositionComponent(entity:get("PositionComponent"):getGrid())) -- TODO
		local dx, dy = entity:get("SpriteComponent"):getDrawPosition()
		dx = dx + chimneyData.bounds.x + math.floor(chimneyData.bounds.w / 2)
		dy = dy + chimneyData.bounds.y + math.floor(chimneyData.bounds.h / 2)
		-- Not sure why the offset is needed, but it is.
		chimney:get("SpriteComponent"):setDrawPosition(dx + 2, dy + 1)
		self.engine:addEntity(chimney, entity)
		building:addChimney(chimney)
	end
end

function BuildingSystem:buildingEnteredEvent(event)
	local entity = event:getBuilding()

	self:_openDoor(entity)

	if not event:isTemporary() then
		local building = entity:get("BuildingComponent")

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
			print(frame1, frame2)
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

		for _,chimney in ipairs(building:getChimneys()) do
			if chimney:get("AssignmentComponent"):getNumAssignees() < 1 then
				chimney:get("AssignmentComponent"):assign(event:getVillager())
				chimney:get("ParticleComponent"):getParticleSystem():start()
				return
			end
		end

		error("No free chimney?")
	end
end

function BuildingSystem:buildingLeftEvent(event)
	local entity = event:getBuilding()
	local building = entity:get("BuildingComponent")
	local found, numWorkers = false, 0

	self:_openDoor(entity)

	for _,chimney in ipairs(building:getChimneys()) do
		if chimney:get("AssignmentComponent"):isAssigned(event:getVillager()) then
			chimney:get("AssignmentComponent"):unassign(event:getVillager())
			chimney:get("ParticleComponent"):getParticleSystem():pause()
			found = true
		else
			numWorkers = numWorkers + chimney:get("AssignmentComponent"):getNumAssignees()
		end
	end

	assert(found, "Villager not assigned to chimney?")

	if building:getType() == BuildingComponent.BAKERY and numWorkers < 1 then
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

return BuildingSystem
