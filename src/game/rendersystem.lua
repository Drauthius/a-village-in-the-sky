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
local table = require "lib.table"

local BuildingComponent = require "src.game.buildingcomponent"
local WorkComponent = require "src.game.workcomponent"

local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local RenderSystem = lovetoys.System:subclass("RenderSystem")

RenderSystem.static.OLD_OUTLINE_COLOR = { 0.0, 0.0, 0.0, 1.0 }
RenderSystem.static.NEW_OUTLINE_COLOR = spriteSheet:getOutlineColor()
RenderSystem.static.SELECTED_OUTLINE_COLOR = { 0.15, 0.70, 0.15, 1.0 }
RenderSystem.static.BEHIND_OUTLINE_COLOR = { 0.70, 0.70, 0.70, 1.0 }
RenderSystem.static.SELECTED_BEHIND_OUTLINE_COLOR = { 0.60, 0.95, 0.60, 1.0 }

RenderSystem.static.MAX_REPLACE_COLORS = 16

RenderSystem.static.COLOR_OUTLINE_SHADER = love.graphics.newShader([[
uniform bool noShadow;
uniform bool shadowOnly;
uniform bool outlineOnly;
uniform int numColorReplaces;
uniform vec4 oldColor[]]..RenderSystem.MAX_REPLACE_COLORS..[[];
uniform vec4 newColor[]]..RenderSystem.MAX_REPLACE_COLORS..[[];

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	vec4 texturecolor = Texel(texture, texture_coords);

	if(texturecolor.a == 0.0)
		discard; // Don't count for stencil tests.
	if(shadowOnly && texturecolor.a > 0.5)
		discard;
	for(int i = 0; i < numColorReplaces; ++i) {
		if((outlineOnly && i != 0) || (noShadow && texturecolor.a < 0.5))
			discard;
		if(texturecolor == oldColor[i])
			return newColor[i] * color;
	}

	if(outlineOnly || (noShadow && texturecolor.a < 0.5))
		discard;

	return texturecolor * color;
}
]])

function RenderSystem.requires()
	return {"SpriteComponent"}
end

function RenderSystem:initialize()
	lovetoys.System.initialize(self)

	self.font = love.graphics.newFont("asset/font/Norse-Bold.otf", 16)

	RenderSystem.COLOR_OUTLINE_SHADER:send("noShadow", false)
	RenderSystem.COLOR_OUTLINE_SHADER:send("shadowOnly", false)
	RenderSystem.COLOR_OUTLINE_SHADER:send("outlineOnly", false)
	-- NOTE: First colour is reserved for the outline.
	RenderSystem.COLOR_OUTLINE_SHADER:send("numColorReplaces", 1)
	RenderSystem.COLOR_OUTLINE_SHADER:send("oldColor", RenderSystem.OLD_OUTLINE_COLOR)
	RenderSystem.COLOR_OUTLINE_SHADER:send("newColor", RenderSystem.NEW_OUTLINE_COLOR)

	-- NOTE: Global
	love.graphics.setShader(RenderSystem.COLOR_OUTLINE_SHADER)

	-- Terrain stuff
	self.terrain = love.graphics.newSpriteBatch(spriteSheet:getImage())
	self.tileDropping = false

	-- Object stuff
	self.objects = { {}, {} } -- Divided up into two passes
	self.recalculateObjects = false
end

function RenderSystem:update(dt)
	if self.tileDropping then
		-- Needs to be recalculated until the tile has completed dropping.
		self:_recalculateTerrain()
	end
	if self.recalculateObjects then
		self:_recalculateObjects()
		self.recalculateObjects = false
	end
end

function RenderSystem:draw()
	love.graphics.setColor(1, 1, 1)

	-- Draw the ground.
	love.graphics.draw(self.terrain)

	-- Draw things connected to the ground.
	for i,entity in ipairs(self.objects[1]) do
		self:_drawEntity(i, entity)
	end

	-- Draw things above ground.
	for i,entity in ipairs(self.objects[2]) do
		self:_drawEntity(i, entity)
	end

	-- Draw the stuff on the cursor
	if state:isPlacing() then
		self:_drawEntity(0, state:getPlacing())
	end

	-- Draw the outline of things behind other things.
	do
		love.graphics.setStencilTest("greater", 0)
		RenderSystem.COLOR_OUTLINE_SHADER:send("outlineOnly", true)

		for _,entity in ipairs(self.objects[2]) do
			if state:getSelection() == entity then
				RenderSystem.COLOR_OUTLINE_SHADER:send("newColor", RenderSystem.SELECTED_BEHIND_OUTLINE_COLOR)
			else
				RenderSystem.COLOR_OUTLINE_SHADER:send("newColor", RenderSystem.BEHIND_OUTLINE_COLOR)
			end

			if entity:has("VillagerComponent") then
				local sprite = entity:get("SpriteComponent")
				spriteSheet:draw(sprite:getSprite(), sprite:getDrawPosition())
			end
		end

		love.graphics.setStencilTest()
		RenderSystem.COLOR_OUTLINE_SHADER:send("outlineOnly", false)
		RenderSystem.COLOR_OUTLINE_SHADER:send("newColor", RenderSystem.NEW_OUTLINE_COLOR)
	end
	love.graphics.setColor(1, 1, 1, 1)

	-- Headers for things connected to the ground.
	for _,entity in ipairs(self.objects[1]) do
		self:_drawHeader(entity)
	end
	-- Headers for things above ground.
	for _,entity in ipairs(self.objects[2]) do
		self:_drawHeader(entity)
	end
end

function RenderSystem:onAddEntity(entity)
	if entity:has("TileComponent") then
		-- Fired only when tiles are created by a level.
		self:_recalculateTerrain()
	elseif entity:has("PositionComponent") then
		self.recalculateObjects = true

		-- Set something that can be overwritten next update, in case something should happen before then.
		entity:get("SpriteComponent"):setDrawIndex(1000)
	elseif not entity:has("PlacingComponent") then
		print(entity, "is not a tile or placing, nor has a position component")
	end
end

function RenderSystem:onRemoveEntity(entity)
	self.recalculateObjects = true
end

function RenderSystem:onEntityMoved(entity)
	-- FIXME: Ideally we would only move around/sort the entity that actually moved, instead of all of them.
	self.recalculateObjects = "keep"
end

function RenderSystem:onTileDropped()
	self.tileDropping = true
end

function RenderSystem:onTilePlaced()
	self.tileDropping = false
	self:_recalculateTerrain()
end

function RenderSystem:_recalculateTerrain()
	self.terrain:clear()

	local ground = {}
	for _,entity in pairs(self.targets) do
		if entity:has("TileComponent") then
			table.insert(ground, entity)
		end
	end
	table.sort(ground, function(a, b)
		local ai, aj = a:get("TileComponent"):getPosition()
		local bi, bj = b:get("TileComponent"):getPosition()
		if aj < bj then
			return true
		elseif aj == bj then
			return ai < bi
		else
			return false
		end
	end)

	for _,entity in ipairs(ground) do
		local sprite = entity:get("SpriteComponent")
		self.terrain:add(sprite:getSprite():getQuad(), sprite:getDrawPosition())
	end
end

function RenderSystem:_recalculateObjects()
	if self.recalculateObjects ~= "keep" then
		self.objects = {
			{}, -- Things drawn on the ground (fields).
			{}  -- Things above ground (buildings, villagers, etc.).
		}
		for _,entity in pairs(self.targets) do
			if entity:has("FieldEnclosureComponent") then
				table.insert(self.objects[1], entity)
			elseif entity:has("PositionComponent") then
				table.insert(self.objects[2], entity)
			end
		end
	end
	table.sort(self.objects[2], function(a, b)
		local ati, atj = assert(a:get("PositionComponent")):getTile()
		local bti, btj = assert(b:get("PositionComponent")):getTile()
		local aTopLeft, aBottomRight = a:get("PositionComponent"):getFromGrid(), a:get("PositionComponent"):getToGrid()
		local bTopLeft, bBottomRight = b:get("PositionComponent"):getFromGrid(), b:get("PositionComponent"):getToGrid()

		-- Do a first pass based on the tile.
		if ati < bti then
			return true
		elseif ati > bti then
			return false
		elseif atj < btj then
			return true
		elseif atj > btj then
			return false
		end

		-- Special rule to take care of villagers walking "inside" things.
		local single, otherTopLeft, otherBottomRight
		if aTopLeft == aBottomRight then
			single = aTopLeft
			otherTopLeft = bTopLeft
			otherBottomRight = bBottomRight
		elseif bTopLeft == bBottomRight then
			single = bTopLeft
			otherTopLeft = aTopLeft
			otherBottomRight = aBottomRight
		end
		if single and
		   single.gi >= otherTopLeft.gi and single.gi <= otherBottomRight.gi and
		   single.gj >= otherTopLeft.gj and single.gi <= otherBottomRight.gj then
			return single ~= aTopLeft
		end

		-- FIXME: Imperfect sorting of sprites (especially if used across tiles).
		if aBottomRight.gi < bTopLeft.gi then
			return true
		elseif aTopLeft.gi > bBottomRight.gi then
			return false
		else
			return aTopLeft.gj < bTopLeft.gj
		end
	end)
end

function RenderSystem:_drawEntity(i, entity)
	local sprite = entity:get("SpriteComponent")
	sprite:setDrawIndex(i)
	local dx, dy = sprite:getDrawPosition()
	local vpsx, vpsy, vpex, vpey = state:getViewport()

	-- Check if the entity is outside the screen.
	if dx > vpex or dy > vpey or
	   dx + sprite:getSprite():getWidth() < vpsx or dy + sprite:getSprite():getHeight() < vpsy then
		return
	end

	local newColors
	if entity:has("ColorSwapComponent") and next(entity:get("ColorSwapComponent"):getReplacedColors()) then
		local colorSwap = entity:get("ColorSwapComponent")
		local oldColors = colorSwap:getReplacedColors()
		newColors = colorSwap:getReplacingColors()
		assert(#oldColors == #newColors and #newColors + 1 < RenderSystem.MAX_REPLACE_COLORS, "Something's wrong")
		RenderSystem.COLOR_OUTLINE_SHADER:send("oldColor", RenderSystem.OLD_OUTLINE_COLOR, unpack(oldColors))
		RenderSystem.COLOR_OUTLINE_SHADER:send("numColorReplaces", #newColors + 1)
	end

	if state:getSelection() == entity then
		RenderSystem.COLOR_OUTLINE_SHADER:send("newColor", RenderSystem.SELECTED_OUTLINE_COLOR, unpack(newColors or {}))
	elseif entity:has("BlinkComponent") and entity:get("BlinkComponent"):isActive() then
		RenderSystem.COLOR_OUTLINE_SHADER:send("newColor", entity:get("BlinkComponent"):getColor(), unpack(newColors or {}))
	else
		RenderSystem.COLOR_OUTLINE_SHADER:send("newColor", RenderSystem.NEW_OUTLINE_COLOR, unpack(newColors or {}))
	end

	local includeShadow = false
	if entity:has("ParticleComponent") then
		includeShadow = true
	else
		RenderSystem.COLOR_OUTLINE_SHADER:send("noShadow", true)
	end

	local oldViewport
	-- Transparent background for buildings under construction, and setup for the non-transparent part.
	if entity:has("ConstructionComponent") then
		local underConstruction = not entity:has("RunestoneComponent")

		if underConstruction then
			love.graphics.setColor(1, 1, 1, 0.5)
			spriteSheet:draw(sprite:getSprite(), dx, dy)

			-- Draw the outline in full technicolor...
			love.graphics.setColor(1, 1, 1, 1)
			RenderSystem.COLOR_OUTLINE_SHADER:send("outlineOnly", true)
			spriteSheet:draw(sprite:getSprite(), dx, dy)
			RenderSystem.COLOR_OUTLINE_SHADER:send("outlineOnly", false)

			local percent = entity:get("ConstructionComponent"):getPercentDone()
			local quad = sprite:getSprite():getQuad()
			local x, y, w, h = quad:getViewport()
			oldViewport = { x, y, w, h }
			local _, ty, _, th = sprite:getSprite():getTrimmedDimensions()

			local deficit = th - th * percent / 100
			deficit = math.floor(deficit) -- Looks a bit weird with fractions.
			quad:setViewport(x, y + ty + deficit, w, th - deficit)
			dy = dy + ty + deficit
		end
	end

	love.graphics.setColor(sprite:getColor())

	if entity:has("VillagerComponent") then
		-- Get rid of any previous stencil values on that position.
		love.graphics.stencil(function()
			love.graphics.setColorMask()
			spriteSheet:draw(sprite:getSprite(), dx, dy)
		end, "replace", 0, true)
	elseif entity:has("ResourceComponent") and entity:get("ResourceComponent"):isUsable() then
		spriteSheet:draw(sprite:getSprite(), dx, dy)
	elseif entity:has("ParticleComponent") then
		love.graphics.draw(entity:get("ParticleComponent"):getParticleSystem(), dx, dy)
	else
		-- Increase the stencil value for non-villager, non-resource things.
		love.graphics.stencil(function()
			love.graphics.setColorMask()
			spriteSheet:draw(sprite:getSprite(), dx, dy)
		end, "replace", 1, true)
	end

	if not includeShadow then
		-- Draw the shadow separately
		RenderSystem.COLOR_OUTLINE_SHADER:send("noShadow", false)
		RenderSystem.COLOR_OUTLINE_SHADER:send("shadowOnly", true)
		-- The colour mask makes it so that the shadow doesn't "stick out" from the tiles.
		love.graphics.setColorMask(true, true, true, false)
		spriteSheet:draw(sprite:getSprite(), dx, dy)

		-- Reset
		love.graphics.setColorMask()
		RenderSystem.COLOR_OUTLINE_SHADER:send("shadowOnly", false)
	end

	-- Reset
	RenderSystem.COLOR_OUTLINE_SHADER:send("numColorReplaces", 1)
	RenderSystem.COLOR_OUTLINE_SHADER:send("newColor", RenderSystem.NEW_OUTLINE_COLOR)
	if oldViewport then
		-- Reset quad
		local quad = sprite:getSprite():getQuad()
		quad:setViewport(unpack(oldViewport))
	end

	-- Text overlay
	if entity:has("ConstructionComponent") then
		local percent = entity:get("ConstructionComponent"):getPercentDone()
		love.graphics.setFont(self.font)
		percent = percent .. "%"

		local fw, fh = self.font:getWidth(percent), self.font:getHeight()

		-- Calculate position
		dx, dy = sprite:getDrawPosition()
		local tx, ty, tw, th = sprite:getSprite():getTrimmedDimensions()
		dx = dx + tx + (tw - fw) / 2
		dy = dy + ty + (th - fh) / 1.5 -- Pull it down a bit

		-- Drop shadow
		love.graphics.setColor(0, 0, 0, 0.5)
		love.graphics.print(percent, dx + 1, dy + 1)
		-- Text
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.print(percent, dx, dy)
	end
end

function RenderSystem:_drawHeader(entity)
	local sprite = entity:get("SpriteComponent")
	local isSelected = state:getSelection() == entity

	-- FIXME: Headers are shown even when the entity is outside of the screen and has been culled.

	if entity:has("VillagerComponent") then
		if state:isTimeStopped() then
			return -- Don't show any headers during a gameplay pause.
		end

		local villager = entity:get("VillagerComponent")

		-- Multiple icons are chained together beautifully.
		local icons = {}

		-- Homeless icon.
		if not villager:getHome() then
			table.insert(icons, (spriteSheet:getSprite("headers", "no-home-icon")))
		end
		if villager:getSleepiness() > require("src.game.villagersystem").SLEEP.SLEEPINESS_THRESHOLD then -- XXX
			table.insert(icons, (spriteSheet:getSprite("headers", "sleepy-icon")))
		end
		if villager:getStarvation() > 0.0 then
			table.insert(icons, (spriteSheet:getSprite("headers", "hungry-icon")))
		end
		if villager:getHome() and entity:has("AdultComponent") and not entity:get("AdultComponent"):getWorkArea() then
			local occupation = entity:get("AdultComponent"):getOccupation()
			if occupation == WorkComponent.WOODCUTTER then
				table.insert(icons, (spriteSheet:getSprite("headers", "missing-woodcutter-icon")))
			elseif occupation == WorkComponent.MINER then
				table.insert(icons, (spriteSheet:getSprite("headers", "missing-miner-icon")))
			end
		end

		local numIcons = #icons
		if numIcons > 0 then
			local ox = -5
			-- Assumes that each icon has the same width.
			local w = numIcons * icons[1]:getWidth() + ox * (numIcons - 1)
			local sx, sy = entity:get("GroundComponent"):getIsometricPosition()
			sx = sx - w / 2
			-- XXX: Guesswork, to get an offset from the ground that doesn't "bob" when the sprite changes.
			if entity:has("AdultComponent") then
				sy = sy - 27
			else
				sy = sy - 25
			end

			for _,icon in ipairs(icons) do
				spriteSheet:draw(icon, sx, sy)
				sx = sx + icon:getWidth() + ox
			end
		end

		--[[
		local header = spriteSheet:getSprite("headers", "person-header")
		local x, y = sprite:getDrawPosition()
		x = x - 5
		if entity:has("AdultComponent") then
			y = y - 10
		else
			y = y - 8
		end
		--self.font = love.graphics.newFont("asset/font/Norse-Bold.otf", 16)
		local font = love.graphics.newFont("asset/font/Norse.otf", 14)
		font:setFilter("linear", "linear", 1)
		--print(font:getFilter())
		love.graphics.setFont(font)
		spriteSheet:draw(header, x, y)
		love.graphics.print("Lars Larsson", x, y)
		--]]
	elseif entity:has("DwellingComponent") then
		local dwelling = entity:get("DwellingComponent")

		-- Check whether the header should be hidden.
		if not isSelected and not state:getShowBuildingHeaders() and
		   entity:get("AssignmentComponent"):getNumAssignees() == entity:get("AssignmentComponent"):getMaxAssignees() and
		   not dwelling:isRelated() and dwelling:getFood() > 0 then
			return
		end

		local header = spriteSheet:getSprite("headers", "dwelling-header")
		local headerData = spriteSheet:getData("dwelling-header")
		local x, y = sprite:getOriginalDrawPosition()
		local w, h = header:getDimensions()
		local tw = sprite:getSprite():getWidth()

		x = x + (tw - w) / 2
		y = y - h / 2
		spriteSheet:draw(header, x, y)

		do -- Adult icons
			local maleIcon = spriteSheet:getSprite("headers", "male-icon")
			local femaleIcon = spriteSheet:getSprite("headers", "female-icon")
			local villagers = entity:get("AssignmentComponent"):getAssignees()
			local j = 1
			for i=1,#villagers do
				local icon = villagers[i]:get("VillagerComponent"):getGender() == "male" and maleIcon or femaleIcon
				spriteSheet:draw(icon, 10 + x + ((i - 1) * (icon:getWidth() + 1)), y + 1)
				j = j + 1
			end

			local vacantIcon = spriteSheet:getSprite("headers", "vacant-icon")
			for i=j,2 do
				spriteSheet:draw(vacantIcon, 10 + x + ((i - 1) * (vacantIcon:getWidth() + 1)), y + 1)
			end

			if dwelling:isRelated() then
				-- XXX: Value
				spriteSheet:draw(spriteSheet:getSprite("headers", "family-ties-icon"), x + 22, y)
			end
		end

		do -- Child icons
			local boyIcon = spriteSheet:getSprite("headers", "boy-icon")
			local girlIcon = spriteSheet:getSprite("headers", "girl-icon")
			local childBox = spriteSheet:getData("child-row-1")

			for i,child in ipairs(dwelling:getChildren()) do
				local icon = child:get("VillagerComponent"):getGender() == "male" and boyIcon or girlIcon
				local iconsPerRow = math.floor(childBox.bounds.w / icon:getWidth())
				local row = spriteSheet:getData("child-row-"..math.floor((i - 1) / iconsPerRow + 1))
				local col = (i - 1) % iconsPerRow

				spriteSheet:draw(
					icon,
					x + row.bounds.x - headerData.bounds.x + col * icon:getWidth(),
					y + row.bounds.y - headerData.bounds.y)
			end
		end

		do -- Bread icons
			local breads = { spriteSheet:getData("bread1-placement"), spriteSheet:getData("bread2-placement") }
			local food = dwelling:getFood()
			if food == 0 then
				local noFoodIcon = spriteSheet:getSprite("headers", "hungry-icon")
				spriteSheet:draw(noFoodIcon,
					x + (breads[1].bounds.x - headerData.bounds.x)
					  + ((breads[1].bounds.w + breads[2].bounds.w + 2) - noFoodIcon:getWidth()) / 2,
					y + (breads[1].bounds.y - headerData.bounds.y) + (breads[1].bounds.h - noFoodIcon:getHeight()) / 2)
			else
				local wholeBreadIcon = spriteSheet:getSprite("headers", "whole-bread-icon")
				local halfBreadIcon = spriteSheet:getSprite("headers", "half-bread-icon")
				for i=1,math.min(2, food+0.5) do
					local bread = wholeBreadIcon
					if i - food == 0.5 then
						bread = halfBreadIcon
					end

					spriteSheet:draw(bread,
						x + (breads[i].bounds.x - headerData.bounds.x),
						y + (breads[i].bounds.y - headerData.bounds.y))
				end
			end
		end
	elseif entity:has("AssignmentComponent") and entity:has("BuildingComponent") then
		local spots = entity:get("AssignmentComponent"):getMaxAssignees()

		-- Check whether the header should be hidden.
		if not isSelected and not entity:has("ConstructionComponent") and not state:getShowBuildingHeaders() and
		   entity:get("AssignmentComponent"):getNumAssignees() == entity:get("AssignmentComponent"):getMaxAssignees() then
			return
		end

		local header = spriteSheet:getSprite("headers",
			entity:has("ConstructionComponent") and "construction-header" or (spots .. "-spot-building-header"))
		local x, y = sprite:getOriginalDrawPosition()
		local w, h = header:getDimensions()
		local tw = sprite:getSprite():getWidth()

		x = x + (tw - w) / 2
		y = y - h / 2
		spriteSheet:draw(header, x, y)

		-- For constructions, use the header as a progress bar.
		if entity:has("ConstructionComponent") then
			header = spriteSheet:getSprite("headers", spots .. "-spot-building-header")

			local percent = entity:get("ConstructionComponent"):getPercentDone()
			local quad = header:getQuad()
			local qx, qy, qw, qh = quad:getViewport()

			local ox = 3 -- Remove some of the outline and spiky things
			local ow = 2 -- Remove some pixels at the end
			local deficit = (qw - ox - ow) - (qw - ox - ow) * percent / 100
			deficit = math.floor(deficit) -- Looks a bit weird with fractions.
			quad:setViewport(qx + ox, qy, qw - deficit - ox - ow, qh)

			spriteSheet:draw(header, x + ox, y)

			-- Reset quad
			quad:setViewport(qx, qy, qw, qh)
		end

		local typeSlice
		local type = entity:get("BuildingComponent"):getType()
		if type == BuildingComponent.DWELLING then
			typeSlice = "house-icon"
		elseif type == BuildingComponent.BLACKSMITH then
			typeSlice = "blacksmith-icon"
		elseif type == BuildingComponent.FIELD then
			typeSlice = "farmer-icon"
		elseif type == BuildingComponent.BAKERY then
			typeSlice = "baker-icon"
		elseif type == BuildingComponent.RUNESTONE then
			typeSlice = "runestone-icon"
		else
			error("Unknown building type '" .. tostring(type) .. "'")
		end
		local typeIcon = spriteSheet:getSprite("headers", typeSlice)
		spriteSheet:draw(typeIcon, x - typeIcon:getWidth() / 2 - 1, y + (h - typeIcon:getHeight()) / 2)

		local occupiedIcon = spriteSheet:getSprite("headers", "occupied-icon")
		local j = 1
		for i=1,entity:get("AssignmentComponent"):getNumAssignees() do
			-- XXX: Value
			spriteSheet:draw(occupiedIcon, 9 + x + ((i - 1) * (occupiedIcon:getWidth() + 1)), y + 1)
			j = j + 1
		end

		local vacantIcon = spriteSheet:getSprite("headers", "vacant-icon")
		for i=j,spots do
			spriteSheet:draw(vacantIcon, 9 + x + ((i - 1) * (vacantIcon:getWidth() + 1)), y + 1)
		end
	end
end

return RenderSystem
