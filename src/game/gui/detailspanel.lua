local Widget = require "src.game.gui.widget"

local Button = require "src.game.gui.button"

local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local DetailsPanel = Widget:subclass("DetailsPanel")

function DetailsPanel:initialize(y, buttonEvents)
	self.buttonEvents = buttonEvents

	self.font = love.graphics.newFont("asset/font/Norse.otf", 16)
	self.fontBold = love.graphics.newFont("asset/font/Norse-Bold.otf", 16)

	local background = spriteSheet:getSprite("details-panel")

	local screenWidth, _ = screen:getDimensions()
	Widget.initialize(self, screenWidth - background:getWidth(), y - background:getHeight(), 0, 0, background)

	local buttonSprite = spriteSheet:getSprite("details-button (Up)")
	self.button = Button(self.x + 2 + (background:getWidth() - buttonSprite:getWidth()) / 2,
	                     self.y + background:getHeight() - buttonSprite:getHeight() - self.font:getHeight() - 6,
	                     1, 5, "details-button", self.fontBold)

	self.villagerDetails = {
		{ "Name", "getName" },
		{ "Age", "getAge" },
		{ "Hunger", "getHunger" },
		{ "Sleepiness", "getSleepiness" },
		{},
		{ "Occupation", "getOccupationName", true },
		{ "Strength", "getStrength" },
		{ "Craftsmanship", "getCraftsmanship" }
	}

	local woodPalette = spriteSheet:getSprite("wood-palette")
	self.woodPalette = {
		outline = { woodPalette:getPixel(1, 0) },
		bright = { woodPalette:getPixel(2, 0) },
		medium = { woodPalette:getPixel(3, 0) },
		dark = { woodPalette:getPixel(4, 0) }
	}
end

function DetailsPanel:update(dt)
	if not self:isShown() then
		return
	end

	if self.button:isPressed() then
		if not self.button:isWithin(screen:getCoordinate(love.mouse.getPosition())) then
			self.button:setPressed(false)
		end
		-- FIXME: Would be nice if the button could be activate again if the pressed mouse hovers over the button
		-- again, but it would require some refactoring of the click events.
	end

	-- FIXME: Don't need to do this every frame...
	local selection = state:getSelection()
	if selection:has("RunestoneComponent") then
		if selection:has("ConstructionComponent") then
			self.button:setText("Cancel")
		else
			self.button:setText("Upgrade")
		end
	end
end

function DetailsPanel:draw()
	if not self:isShown() then
		return
	end

	Widget.draw(self)

	-- XXX:
	local RenderSystem = require "src.game.rendersystem"

	-- Start of the text stuff
	local x, y = self.x + 5, self.y + 13

	local selection = state:getSelection()

	if selection:has("VillagerComponent") then
		local villager = selection:get("VillagerComponent")
		local adult = selection:has("AdultComponent") and selection:get("AdultComponent")

		--love.graphics.setColor(0, 0, 0)
		love.graphics.setColor(RenderSystem.NEW_OUTLINE_COLOR) -- XXX: True pixel font won't have this problem.

		for _,details in ipairs(self.villagerDetails) do
			local key, value, adultComp = details[1], details[2], details[3]
			if not key then
				if not adult then
					break
				end
			else
				key = key .. ": "
				if adultComp then
					value = adult[value](adult)
				else
					value = villager[value](villager)
				end
				if type(value) == "number" then
					value = string.format("%.2f", value)
				end
				love.graphics.setFont(self.fontBold)
				love.graphics.print(key, x, y)

				love.graphics.setFont(self.font)
				love.graphics.print(value, x + self.fontBold:getWidth(key), y)
				y = y + math.floor(self.fontBold:getHeight() * 1.5)
			end
		end

		love.graphics.setColor(1, 1, 1)
	elseif selection:has("RunestoneComponent") then
		local runestone = selection:get("RunestoneComponent")

		--love.graphics.setColor(0, 0, 0)
		love.graphics.setColor(RenderSystem.NEW_OUTLINE_COLOR) -- XXX: True pixel font won't have this problem.
		love.graphics.setFont(self.fontBold)
		love.graphics.print("Stage: ", x, y)

		love.graphics.setFont(self.font)
		love.graphics.print(tostring(runestone:getLevel()), x + self.fontBold:getWidth("Stage: "), y)

		x, y = self.button:getPosition()
		local w, h = self.button:getDimensions()
		local ox = -1
		local oy = self.font:getHeight() + 1
		--love.graphics.setColor(self.woodPalette.medium)
		--love.graphics.rectangle("fill", x - ox, y + 1, w + ox, h + oy)

		love.graphics.setColor(self.woodPalette.outline)
		love.graphics.setLineWidth(1)
		love.graphics.setLineStyle("rough")
		love.graphics.rectangle("line", x - ox, y + 1, w + ox, h + oy)

		if not selection:has("ConstructionComponent") then
			x = x - ox + 1
			y = y + h + 2
			love.graphics.print("Cost:", x, y)
			x = x + self.font:getWidth("Cost: ")

			-- XXX: Too much logic in the GUI?
			local BuildingComponent = require "src.game.buildingcomponent"
			local ConstructionComponent = require "src.game.constructioncomponent"
			local ResourceComponent = require "src.game.resourcecomponent"
			--local WorkComponent = require "src.game.workcomponent"
			for resource,amount in pairs(ConstructionComponent.MATERIALS[BuildingComponent.RUNESTONE][runestone:getLevel()]) do
				if amount > 0 then
					love.graphics.setColor(RenderSystem.NEW_OUTLINE_COLOR) -- XXX: True pixel font won't have this problem.
					love.graphics.print(amount.."x", x, y)
					x = x + self.font:getWidth(amount.."x") + 1
					--local name = WorkComponent.WORK_NAME[WorkComponent.RESOURCE_TO_WORK[resource]] -- XXX: This is silly
					local name = ResourceComponent.RESOURCE_NAME[resource]
					local sprite = spriteSheet:getSprite("headers", name.."-icon")
					if not self.apa then
						self.apa = 1
					end
					love.graphics.setColor(1, 1, 1)
					spriteSheet:draw(sprite, x, math.floor(y - (self.font:getHeight() - sprite:getHeight()) / 2) + 1)
					x = x + sprite:getWidth() + self.font:getWidth(" ")
				end
			end
		end

		love.graphics.setColor(1, 1, 1)
		self.button:draw()
	end
end

function DetailsPanel:hide()
	state:clearSelection()
end

function DetailsPanel:isShown()
	return state:getSelection() ~= nil
end

function DetailsPanel:handlePress(x, y, released)
	assert(self:isShown())

	-- XXX: Another check for whether the/a button is shown.
	if state:getSelection():has("RunestoneComponent") then
		if self.button:isWithin(x, y) then
			if released and self.button:isPressed() then
				if state:getSelection():has("ConstructionComponent") then
					self.buttonEvents("runestone-upgrade-cancel")
				else
					self.buttonEvents("runestone-upgrade")
				end
			end
			self.button:setPressed(not released)
		end
	end
end

return DetailsPanel
