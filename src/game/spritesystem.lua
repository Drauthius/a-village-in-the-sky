local lovetoys = require "lib.lovetoys.lovetoys"
local table = require "lib.table"

local FieldComponent = require "src.game.fieldcomponent"
local InteractiveComponent = require "src.game.interactivecomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local VillagerComponent = require "src.game.villagercomponent"
local WorkComponent = require "src.game.workcomponent"

local WorkEvent = require "src.game.workevent"

local spriteSheet = require "src.game.spritesheet"

local SpriteSystem = lovetoys.System:subclass("SpriteSystem")

SpriteSystem.static.ANIMATIONS = {
	idle = {},
	walking = {
		nothing = {},
		[ResourceComponent.WOOD] = {},
		[ResourceComponent.IRON] = {},
		[ResourceComponent.TOOL] = {},
		[ResourceComponent.GRAIN] = {},
		[ResourceComponent.BREAD] = {}
	},
	walking_to_work = {
		[WorkComponent.WOODCUTTER] = {},
		[WorkComponent.MINER] = {},
		[WorkComponent.BLACKSMITH] = {},
		[WorkComponent.FARMER] = {},
		[WorkComponent.BAKER] = {},
		[WorkComponent.BUILDER] = {}
	},
	working = {
		[WorkComponent.WOODCUTTER] = {},
		[WorkComponent.MINER] = {},
		[WorkComponent.BUILDER] = {}
	}
}

function SpriteSystem.requires()
	return {"SpriteComponent"}
end

function SpriteSystem:initialize(eventManager)
	lovetoys.System.initialize(self)

	self.eventManager = eventManager

	-- Make sure to clone the table since we want to change things in it.
	SpriteSystem.ANIMATIONS.idle = table.clone(spriteSheet:getFrameTag("Emptyhanded"), true)
	SpriteSystem.ANIMATIONS.idle.to = SpriteSystem.ANIMATIONS.idle.from

	local walking = SpriteSystem.ANIMATIONS.walking
	walking.nothing = spriteSheet:getFrameTag("Emptyhanded")

	for resource,name in pairs(ResourceComponent.RESOURCE_NAME) do
		-- TODO: Consolidate!!
		if resource == ResourceComponent.IRON then
			name = "ore"
		elseif resource == ResourceComponent.GRAIN then
			name = "wheat"
		end

		walking[resource] = {
			[1] = spriteSheet:getFrameTag("1 "..name),
			[2] = spriteSheet:getFrameTag("2 "..(resource == ResourceComponent.TOOL and name .. "s" or name)),
			[3] = spriteSheet:getFrameTag("3 "..(resource == ResourceComponent.TOOL and name .. "s" or name))
		}
	end

	local toWork = SpriteSystem.ANIMATIONS.walking_to_work
	toWork[WorkComponent.WOODCUTTER] = spriteSheet:getFrameTag("Axe")
	toWork[WorkComponent.MINER] = spriteSheet:getFrameTag("Pickaxe")
	toWork[WorkComponent.BLACKSMITH] = spriteSheet:getFrameTag("Hammer")
	toWork[WorkComponent.FARMER] = spriteSheet:getFrameTag("Sickle")
	toWork[WorkComponent.BAKER] = spriteSheet:getFrameTag("Rolling pin")
	toWork[WorkComponent.BUILDER] = spriteSheet:getFrameTag("Hammer")

	local working = SpriteSystem.ANIMATIONS.working
	working[WorkComponent.WOODCUTTER] = {
		E = spriteSheet:getFrameTag("Woodcutter left"),
		W = spriteSheet:getFrameTag("Woodcutter right")
	}
	working[WorkComponent.MINER] = {
		E = spriteSheet:getFrameTag("Miner left"),
		W = spriteSheet:getFrameTag("Miner right")
	}
	working[WorkComponent.BUILDER] = {
		NE = spriteSheet:getFrameTag("Builder left"),
		NW = spriteSheet:getFrameTag("Builder right")
	}
	working[FieldComponent.UNCULTIVATED] = {
		NW = spriteSheet:getFrameTag("Plowing")
	}
	working[FieldComponent.PLOWED] = {
		NW = spriteSheet:getFrameTag("Seeding")
	}
	working[FieldComponent.SEEDED] = {
		NW = spriteSheet:getFrameTag("Seeding")
	}
	working[FieldComponent.GROWING] = {
		NW = spriteSheet:getFrameTag("Seeding")
	}
	working[FieldComponent.HARVESTING] = {
		NW = spriteSheet:getFrameTag("Reaping")
	}
end

function SpriteSystem:updateVillager(dt, entity)
	local villager = entity:get("VillagerComponent")
	local adult = entity:has("AdultComponent") and entity:get("AdultComponent")
	local sprite = entity:get("SpriteComponent")
	local animation = entity:get("AnimationComponent")

	-- Figure out the palette.
	local palette = villager:getPalette() - 1
	if palette == 0 then
		palette = ""
	else
		palette = "#" .. palette
	end

	-- Figure out the cardinal direction.
	local cardinalDir = villager:getCardinalDirection()

	-- Figure out the animation.
	local targetAnimation
	local animated = true
	local working = false
	if entity:has("CarryingComponent") then
		local carrying = entity:get("CarryingComponent")
		targetAnimation = SpriteSystem.ANIMATIONS.walking[carrying:getResource()][carrying:getAmount()]
		assert(targetAnimation, "Missing carrying animation for villager")
	elseif entity:has("WorkingComponent") then
		if entity:has("WalkingComponent") or not entity:get("WorkingComponent"):getWorking() then
			targetAnimation = SpriteSystem.ANIMATIONS.walking_to_work[adult:getOccupation()]
			assert(targetAnimation, "Missing walking animation")
			-- XXX: Didn't want to make a check like this, but here we are.
			if not entity:has("WalkingComponent") and
			   villager:getGoal() ~= VillagerComponent.GOALS.DROPOFF
			   and villager:getGoal() ~= VillagerComponent.GOALS.WORK_PICKUP then
				animated = false
			end
		else
			local key = adult:getOccupation()
			if key == WorkComponent.FARMER then
				-- Train-wreck anti-pattern?
				key = entity:get("AdultComponent"):getWorkPlace():get("FieldComponent"):getState()
			end
			assert(SpriteSystem.ANIMATIONS.working[key], "No animation for "..adult:getOccupationName())
			targetAnimation = SpriteSystem.ANIMATIONS.working[key][cardinalDir]
			working = true
			assert(targetAnimation, "Missing working animation. " ..
			       "Occupation: "..adult:getOccupationName()..", Direction: "..cardinalDir..", Key: "..key)
		end
	elseif entity:has("WalkingComponent") then
		targetAnimation = SpriteSystem.ANIMATIONS.walking.nothing
	else
		targetAnimation = SpriteSystem.ANIMATIONS.idle
		animated = false
	end

	-- Figure out the animation frame.
	local frame, newFrame
	if animation:getAnimation() ~= targetAnimation then
		newFrame = true
		animation:setAnimation(targetAnimation)
	elseif animated then
		local t = animation:getTimer() - dt
		if t <= 0 then
			newFrame = true
			animation:advance()
		else
			animation:setTimer(t)
		end
	end
	frame = animation:getCurrentFrame()

	-- Figure out the sprite.
	local slice, sliceFrame, targetSprite, duration
	if working then
		slice = "Working"
		sliceFrame = animation:getAnimation().from
		targetSprite, duration = spriteSheet:getSprite("villagers-action "..frame..palette, slice)
	else
		if adult then
			slice = villager:getGender() .. " - " .. cardinalDir
			targetSprite, duration = spriteSheet:getSprite("villagers "..frame..palette, slice)
		else
			slice = (villager:getGender() == "male" and "Boy" or "Girl") .. " - " .. cardinalDir
			targetSprite, duration = spriteSheet:getSprite("children "..frame..palette, slice)
		end
	end

	if newFrame then
		animation:setTimer(duration / 1000)
	end

	-- TODO: Improve?
	if working and newFrame then
		local frameNum = frame - animation:getAnimation().from
		if adult:getOccupation() == WorkComponent.BUILDER then
			if frameNum == 2 then
				self.eventManager:fireEvent(WorkEvent(entity, adult:getWorkPlace()))
			end
		elseif frameNum == 3 then
			self.eventManager:fireEvent(WorkEvent(entity, adult:getWorkPlace()))
		end
	end

	--local prevDrawX, prevDrawY = entity:get("SpriteComponent"):getDrawPosition()

	sprite:setSprite(targetSprite)

	local data = spriteSheet:getData(slice, sliceFrame)

	local x, y = entity:get("GroundComponent"):getIsometricPosition()
	local dx, dy = x - data.pivot.x - 1, y - data.pivot.y - 1
	sprite:setDrawPosition(dx, dy)

	if not entity:has("InteractiveComponent") then
		InteractiveComponent:makeInteractive(entity, dx, dy)
	else
		-- TODO: Moving doesn't work (sprite size changes drastically) :(
		--entity:get("InteractiveComponent"):move(dx - prevDrawX, dy - prevDrawY)
		entity:remove("InteractiveComponent")
		InteractiveComponent:makeInteractive(entity, dx, dy)
	end
end

function SpriteSystem:update(dt)
	for _,entity in pairs(self.targets) do
		if entity:has("VillagerComponent") then
			self:updateVillager(dt, entity)
		elseif entity:get("SpriteComponent"):needsRefresh() then
			if entity:has("ResourceComponent") then
				local resource = entity:get("ResourceComponent")
				local type = resource:getResource()
				local name = ResourceComponent.RESOURCE_NAME[type]
				local sprite = spriteSheet:getSprite(name.."-resource "..tostring(resource:getResourceAmount() - 1))

				entity:get("SpriteComponent"):setSprite(sprite)
				entity:get("SpriteComponent"):setNeedsRefresh(false)
			end
		end
	end
end

return SpriteSystem
