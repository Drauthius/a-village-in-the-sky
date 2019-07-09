local lovetoys = require "lib.lovetoys.lovetoys"

local WorkCompletedEvent = require "src.game.workcompletedevent"
local AssignmentComponent = require "src.game.assignmentcomponent"
local CarryingComponent = require "src.game.carryingcomponent"
local FieldComponent = require "src.game.fieldcomponent"
local PositionComponent = require "src.game.positioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TimerComponent = require "src.game.timercomponent"
local WorkComponent = require "src.game.workcomponent"

local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local FieldSystem = lovetoys.System:subclass("FieldSystem")

FieldSystem.static.GRID_OFFSETS = {
	{ ogi =  0, ogj =  0 },
	{ ogi =  0, ogj =  5 },
	{ ogi =  0, ogj = 10 },
	{ ogi =  5, ogj =  0 },
	{ ogi =  5, ogj =  5 },
	{ ogi =  5, ogj = 10 },
	{ ogi = 10, ogj =  0 },
	{ ogi = 10, ogj =  5 },
	{ ogi = 10, ogj = 10 },
}

FieldSystem.static.TIMERS = {
	SEED_DELAY = 10,
	GROW_DELAY = 10,
	HARVEST_DELAY = 10
}

FieldSystem.static.COMPLETION = {
	-- How many animation frames to require before the plot is completed.
	-- Same for all plot states, at the moment.
	-- (2 minutes for all 9 plots using 4 animations (1 cycle) with default 0.2 seconds for each animation)
	100 / ((120 / (0.2 * 4)) / 9)
}

function FieldSystem.requires()
	return {"FieldEnclosureComponent"}
end

function FieldSystem:initialize(engine, eventManager, map)
	lovetoys.System.initialize(self)
	self.engine = engine
	self.eventManager = eventManager
	self.map = map
end

function FieldSystem:update(dt)
	for _,entity in pairs(self.targets) do
		self:_update(entity)
	end
end

function FieldSystem:_update(entity)
	local fieldEnclosure = entity:get("FieldEnclosureComponent")
	local fields = fieldEnclosure:getFields()
	if not fields then
		fields = self:_initiate(entity)
	end

	-- Check whether all fields are completed.
	local fieldState = fields[1]:get("FieldComponent"):getState()
	for _,field in ipairs(fields) do
		if not field:get("WorkComponent"):isComplete() or field:get("FieldComponent"):getState() ~= fieldState then
			return
		end
	end

	-- All fields complete, reset them all.
	for _,field in ipairs(fields) do
		field:get("WorkComponent"):reset()
	end
end

function FieldSystem:workEvent(event)
	local entity = event:getVillager()
	local workPlace = event:getWorkPlace()

	if not workPlace:has("FieldComponent") then
		-- Handled elsewhere.
		return
	end

	local field = workPlace:get("FieldComponent")
	workPlace:get("WorkComponent"):increaseCompletion(FieldSystem.COMPLETION[1] * state:getYearModifier())
	if workPlace:get("WorkComponent"):isComplete() then
		local fieldState = field:getState()
		if fieldState == FieldComponent.UNCULTIVATED then
			fieldState = FieldComponent.PLOWED
			local stateName = FieldComponent.STATE_NAMES[fieldState]:gsub("^%l", string.upper)
			workPlace:get("SpriteComponent"):setSprite(spriteSheet:getSprite("field-single ("..stateName..")"))
		elseif fieldState == FieldComponent.PLOWED then
			fieldState = FieldComponent.IN_PROGRESS
			workPlace:add(TimerComponent(FieldSystem.TIMERS.SEED_DELAY, function()
				workPlace:remove("TimerComponent")
				field:setState(FieldComponent.SEEDED)
				local stateName = FieldComponent.STATE_NAMES[field:getState()]:gsub("^%l", string.upper)
				workPlace:get("SpriteComponent"):setSprite(spriteSheet:getSprite("field-single ("..stateName..")"))
			end))
		elseif fieldState == FieldComponent.SEEDED then
			fieldState = FieldComponent.IN_PROGRESS
			workPlace:add(TimerComponent(FieldSystem.TIMERS.GROW_DELAY, function()
				workPlace:remove("TimerComponent")
				field:setState(FieldComponent.GROWING)
				local stateName = FieldComponent.STATE_NAMES[field:getState()]:gsub("^%l", string.upper)
				local spriteName = "field-single ("..stateName..")"
				local sprites = { spriteName }
				if field:getIndex() <= 3 then
					table.insert(sprites, (spriteName:gsub("%)", " Outline W)")))
				end
				if (field:getIndex() - 1) % 3 == 0 then
					table.insert(sprites, (spriteName:gsub("%)", " Outline E)")))
				end
				workPlace:get("SpriteComponent"):setSprite(spriteSheet:getSprite(sprites))
			end))
		elseif fieldState == FieldComponent.GROWING then
			fieldState = FieldComponent.IN_PROGRESS
			workPlace:add(TimerComponent(FieldSystem.TIMERS.HARVEST_DELAY, function()
				workPlace:remove("TimerComponent")
				field:setState(FieldComponent.HARVESTING)
				local stateName = FieldComponent.STATE_NAMES[field:getState()]:gsub("^%l", string.upper)
				local spriteName = "field-single ("..stateName..")"
				local sprites = { spriteName }
				--if field:getIndex() <= 3 then
					--table.insert(sprites, (spriteName:gsub("%)", " Outline W)")))
				--end
				--if (field:getIndex() - 1) % 3 == 0 then
					--table.insert(sprites, (spriteName:gsub("%)", " Outline E)")))
				--end
				workPlace:get("SpriteComponent"):setSprite(spriteSheet:getSprite(sprites))
			end))
		elseif fieldState == FieldComponent.HARVESTING then
			fieldState = FieldComponent.UNCULTIVATED
			local stateName = FieldComponent.STATE_NAMES[fieldState]:gsub("^%l", string.upper)
			workPlace:get("SpriteComponent"):setSprite(spriteSheet:getSprite("field-single ("..stateName..")"))

			entity:add(CarryingComponent(ResourceComponent.GRAIN, 3))
		end

		field:setState(fieldState)
		workPlace:get("AssignmentComponent"):unassign(entity)

		-- Check whether all fields are completed.
		local complete = true
		for _,otherField in ipairs(field:getEnclosure():get("FieldEnclosureComponent"):getFields()) do
			if otherField:get("FieldComponent"):getState() ~= fieldState and
			   not otherField:get("WorkComponent"):isComplete() and
			   otherField:get("AssignmentComponent"):getNumAssignees() < 1 then
				complete = false
				break
			end
		end

		self.eventManager:fireEvent(WorkCompletedEvent(workPlace, entity, not complete))
	end
end

function FieldSystem:_initiate(entity)
	local grid = entity:get("PositionComponent"):getFromGrid()
	local ti, tj = entity:get("PositionComponent"):getTile()
	local data = spriteSheet:getData("Field")
	local fields = {}
	for i=1,9 do
		local field = lovetoys.Entity(entity)

		-- The position of the patch.
		local fromGrid = self.map:getGrid(grid.gi + FieldSystem.GRID_OFFSETS[i].ogi,
		                                  grid.gj + FieldSystem.GRID_OFFSETS[i].ogj)
		local toGrid = self.map:getGrid(fromGrid.gi + 3, fromGrid.gj + 3)
		field:add(PositionComponent(fromGrid, toGrid, ti, tj))

		-- The sprite of the field.
		-- The slices telling where the fields are are a bit annoying to use...
		local dx, dy = self.map:gridToWorldCoords(fromGrid.gi + 2, fromGrid.gj + 2)
		dx, dy = dx - data.pivot.x - 1, dy - data.pivot.y - 1
		field:add(SpriteComponent(spriteSheet:getSprite("field-single (Uncultivated)"), dx, dy))

		field:add(AssignmentComponent(1))
		field:add(WorkComponent(WorkComponent.FARMER))
		field:add(FieldComponent(entity, i))

		self.engine:addEntity(field)
		table.insert(fields, field)
	end

	entity:get("FieldEnclosureComponent"):setFields(fields)
	return fields
end

return FieldSystem
