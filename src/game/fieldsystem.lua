local lovetoys = require "lib.lovetoys.lovetoys"

local AssignmentComponent = require "src.game.assignmentcomponent"
local CarryingComponent = require "src.game.carryingcomponent"
local FieldComponent = require "src.game.fieldcomponent"
local PositionComponent = require "src.game.positioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TimerComponent = require "src.game.timercomponent"
local VillagerComponent = require "src.game.villagercomponent"
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
	return {"FieldComponent"}
end

function FieldSystem:initialize(engine, map)
	lovetoys.System.initialize(self)
	self.engine = engine
	self.map = map
end

function FieldSystem:update(dt)
	for _,entity in pairs(self.targets) do
		local field = entity:get("FieldComponent")
		local patches = field:getPatches()
		if not patches then
			patches = self:_initiate(entity)
		end

		local state = field:getState()
		for _,patch in ipairs(patches) do
			if patch.state == state or patch.state == FieldComponent.IN_PROGRESS then
				state = nil
				break
			end
		end

		if state then
			if state == FieldComponent.HARVESTING then
				state = FieldComponent.UNCULTIVATED
			else
				state = state + 1 -- Lazy
			end
			field:setState(state)
			for _,patch in ipairs(patches) do
				patch:get("WorkComponent"):reset()
			end
		end
	end
end

function FieldSystem:workEvent(event)
	local entity = event:getVillager()
	local workPlace = event:getWorkPlace()

	if not workPlace:has("FieldComponent") then
		-- Handled elsewhere.
		return
	end

	-- Try to find which patch the villager is working on.
	local field = workPlace:get("FieldComponent")
	local patches = assert(field:getPatches(), "Field not set up")
	local workedPatch
	for _,patch in ipairs(patches) do
		if patch:get("AssignmentComponent"):isAssigned(entity) then
			workedPatch = patch
			break
		end
	end
	assert(workedPatch, "Could not find patch.")

	workedPatch:get("WorkComponent"):increaseCompletion(10.0) -- TODO: Value!
	if workedPatch:get("WorkComponent"):isComplete() then
		local state = workedPatch.state
		if state == FieldComponent.UNCULTIVATED then
			state = FieldComponent.PLOWED
			local stateName = FieldComponent.STATE_NAMES[state]:gsub("^%l", string.upper)
			workedPatch:get("SpriteComponent"):setSprite(spriteSheet:getSprite("field-single ("..stateName..")"))
		elseif state == FieldComponent.PLOWED then
			state = FieldComponent.IN_PROGRESS
			workedPatch:add(TimerComponent(FieldSystem.TIMERS.SEED_DELAY, function()
				workedPatch:remove("TimerComponent")
				workedPatch.state = FieldComponent.SEEDED
				local stateName = FieldComponent.STATE_NAMES[workedPatch.state]:gsub("^%l", string.upper)
				workedPatch:get("SpriteComponent"):setSprite(spriteSheet:getSprite("field-single ("..stateName..")"))
			end))
		elseif state == FieldComponent.SEEDED then
			state = FieldComponent.IN_PROGRESS
			workedPatch:add(TimerComponent(FieldSystem.TIMERS.GROW_DELAY, function()
				workedPatch:remove("TimerComponent")
				workedPatch.state = FieldComponent.GROWING
				local stateName = FieldComponent.STATE_NAMES[workedPatch.state]:gsub("^%l", string.upper)
				workedPatch:get("SpriteComponent"):setSprite(spriteSheet:getSprite("field-single ("..stateName..")"))
			end))
		elseif state == FieldComponent.GROWING then
			state = FieldComponent.IN_PROGRESS
			workedPatch:add(TimerComponent(FieldSystem.TIMERS.HARVEST_DELAY, function()
				workedPatch:remove("TimerComponent")
				workedPatch.state = FieldComponent.HARVESTING
				local stateName = FieldComponent.STATE_NAMES[workedPatch.state]:gsub("^%l", string.upper)
				workedPatch:get("SpriteComponent"):setSprite(spriteSheet:getSprite("field-single ("..stateName..")"))
			end))
		elseif state == FieldComponent.HARVESTING then
			state = FieldComponent.UNCULTIVATED
			local stateName = FieldComponent.STATE_NAMES[state]:gsub("^%l", string.upper)
			workedPatch:get("SpriteComponent"):setSprite(spriteSheet:getSprite("field-single ("..stateName..")"))

			entity:add(CarryingComponent(ResourceComponent.GRAIN, 3))
		end

		workedPatch.state = state
		workedPatch:get("AssignmentComponent"):unassign(entity)
		entity:remove("WorkingComponent")
		entity:get("VillagerComponent"):setGoal(VillagerComponent.GOALS.NONE)
	end
end

function FieldSystem:_initiate(entity)
	local grid = entity:get("PositionComponent"):getFromGrid()
	local endGrid = entity:get("PositionComponent"):getToGrid()
	local ti, tj = entity:get("PositionComponent"):getTile()
	local data = spriteSheet:getData("Field")
	local patches = {}
	for i=1,9 do
		local patch = lovetoys.Entity(entity)

		-- The position of the patch.
		local fromGrid = self.map:getGrid(grid.gi + FieldSystem.GRID_OFFSETS[i].ogi,
		                                  grid.gj + FieldSystem.GRID_OFFSETS[i].ogj)
		local toGrid = self.map:getGrid(fromGrid.gi + 3, fromGrid.gj + 3)
		patch:add(PositionComponent(fromGrid, toGrid, ti, tj))

		-- The sprite of the patch.
		-- The slices telling where the patches are are a bit annoying to use...
		local dx, dy = self.map:gridToWorldCoords(fromGrid.gi + 2, fromGrid.gj + 2)
		dx, dy = dx - data.pivot.x - 1, dy - data.pivot.y - 1
		patch:add(SpriteComponent(spriteSheet:getSprite("field-single (Uncultivated)"), dx, dy))

		patch:add(AssignmentComponent(1))
		local workGrids = { { rotation = 315, ogi = toGrid.gi - endGrid.gi + 1, ogj = toGrid.gj - endGrid.gj - 2 } }
		patch:add(WorkComponent(WorkComponent.FARMER, workGrids))

		self.engine:addEntity(patch)
		table.insert(patches, patch)

		-- TODO: Hack
		patch.state = FieldComponent.UNCULTIVATED
	end

	local field = entity:get("FieldComponent")
	field:setPatches(patches)
	field:setWorkedPatch(1)
	field:setState(FieldComponent.UNCULTIVATED)
	return patches
end

return FieldSystem
