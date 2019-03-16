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
	SEED_DELAY = 5,
	GROW_DELAY = 5,
	HARVEST_DELAY = 5
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
	local state = fields[1]:get("FieldComponent"):getState()
	for _,field in ipairs(fields) do
		if not field:get("WorkComponent"):isComplete() or field:get("FieldComponent"):getState() ~= state then
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
	workPlace:get("WorkComponent"):increaseCompletion(10.0) -- TODO: Value!
	if workPlace:get("WorkComponent"):isComplete() then
		local state = field:getState()
		if state == FieldComponent.UNCULTIVATED then
			state = FieldComponent.PLOWED
			local stateName = FieldComponent.STATE_NAMES[state]:gsub("^%l", string.upper)
			workPlace:get("SpriteComponent"):setSprite(spriteSheet:getSprite("field-single ("..stateName..")"))
		elseif state == FieldComponent.PLOWED then
			state = FieldComponent.IN_PROGRESS
			workPlace:add(TimerComponent(FieldSystem.TIMERS.SEED_DELAY, function()
				workPlace:remove("TimerComponent")
				field:setState(FieldComponent.SEEDED)
				local stateName = FieldComponent.STATE_NAMES[field:getState()]:gsub("^%l", string.upper)
				workPlace:get("SpriteComponent"):setSprite(spriteSheet:getSprite("field-single ("..stateName..")"))
			end))
		elseif state == FieldComponent.SEEDED then
			state = FieldComponent.IN_PROGRESS
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
		elseif state == FieldComponent.GROWING then
			state = FieldComponent.IN_PROGRESS
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
		elseif state == FieldComponent.HARVESTING then
			state = FieldComponent.UNCULTIVATED
			local stateName = FieldComponent.STATE_NAMES[state]:gsub("^%l", string.upper)
			workPlace:get("SpriteComponent"):setSprite(spriteSheet:getSprite("field-single ("..stateName..")"))

			entity:add(CarryingComponent(ResourceComponent.GRAIN, 3))
		end

		field:setState(state)
		workPlace:get("AssignmentComponent"):unassign(entity)

		self.eventManager:fireEvent(WorkCompletedEvent(workPlace, entity))
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
