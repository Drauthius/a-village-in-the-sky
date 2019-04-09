local lovetoys = require "lib.lovetoys.lovetoys"

local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local RenderSystem = lovetoys.System:subclass("RenderSystem")

RenderSystem.static.OLD_OUTLINE_COLOR = { 0.0, 0.0, 0.0, 1.0 }
RenderSystem.static.NEW_OUTLINE_COLOR = { 0.15, 0.15, 0.15, 1.0 }
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
end

function RenderSystem.requires()
	return {"SpriteComponent"}
end

function RenderSystem:draw()
	love.graphics.setColor(1, 1, 1)
	local ground = {}
	local objects = {}

	-- TODO: Can be optimized (spritebatched)
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

	-- TODO: Can probably cache (overwrite addEntity/removeEntity?)
	for _,entity in pairs(self.targets) do
		if entity:has("FieldEnclosureComponent") then
			local ti, tj = entity:get("PositionComponent"):getTile()
			for k,tile in ipairs(ground) do
				if tile:has("TileComponent") then
					local i, j = tile:get("TileComponent"):getPosition()
					if ti == i and tj == j then
						table.insert(ground, k + 1, entity)
						break
					end
				end
			end
		elseif entity:has("PositionComponent") then
			table.insert(objects, entity)
		end
	end
	table.sort(objects, function(a, b)
		local aTopLeft, aBottomRight = a:get("PositionComponent"):getFromGrid(), a:get("PositionComponent"):getToGrid()
		local bTopLeft, bBottomRight = b:get("PositionComponent"):getFromGrid(), b:get("PositionComponent"):getToGrid()

		if aBottomRight.gj < bTopLeft.gj then
			return true
		elseif aTopLeft.gj > bBottomRight.gj then
			return false
		else
			return aTopLeft.gi < bTopLeft.gi
		end
	end)

	if state:isPlacing() then
		table.insert(objects, state:getPlacing())
	end

	for _,entity in ipairs(ground) do
		if entity:has("BlinkComponent") and entity:get("BlinkComponent"):isActive() then
			RenderSystem.COLOR_OUTLINE_SHADER:send("newColor", entity:get("BlinkComponent"):getColor())
		else
			RenderSystem.COLOR_OUTLINE_SHADER:send("newColor", RenderSystem.NEW_OUTLINE_COLOR)
		end

		local sprite = entity:get("SpriteComponent")
		love.graphics.setColor(sprite:getColor())
		spriteSheet:draw(sprite:getSprite(), sprite:getDrawPosition())
	end

	for i,entity in ipairs(objects) do
		local sprite = entity:get("SpriteComponent")
		sprite:setDrawIndex(i)
		local dx, dy = sprite:getDrawPosition()

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

		-- Transparent background for buildings under construction, and setup for the non-transparent part.
		if entity:has("ConstructionComponent") then
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
			sprite.oldViewport = { x, y, w, h }
			local _, ty, _, th = sprite:getSprite():getTrimmedDimensions()

			local deficit = th - th * percent / 100
			deficit = math.floor(deficit) -- Looks a bit weird with fractions.
			quad:setViewport(x, y + ty + deficit, w, th - deficit)
			dy = dy + ty + deficit
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

		-- Text overlay
		if entity:has("ConstructionComponent") then
			-- Reset quad
			local quad = sprite:getSprite():getQuad()
			quad:setViewport(unpack(sprite.oldViewport))
			sprite.oldViewport = nil

			-- Prepare text
			local percent = entity:get("ConstructionComponent"):getPercentDone()
			love.graphics.setFont(self.font)
			local grid = entity:get("PositionComponent"):getGrid()
			local gi, gj = grid.gi, grid.gj
			-- TODO
			local ox, oy = 4, 2
			local Fx, Fy = (gi - gj) * ox, (gi + gj) * oy
			Fy = Fy - oy * 2 - self.font:getHeight()

			-- Drop shadow
			love.graphics.setColor(0, 0, 0, 0.5)
			love.graphics.print(percent .. "%", Fx + 1, Fy + 1)
			-- Text
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.print(percent .. "%", Fx, Fy)
		end
	end

	do -- Behind outline.
		love.graphics.setStencilTest("greater", 0)
		RenderSystem.COLOR_OUTLINE_SHADER:send("outlineOnly", true)

		for _,entity in ipairs(objects) do
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

	-- Headers
	for _,entity in ipairs(objects) do
		local sprite = entity:get("SpriteComponent")

		if entity:has("VillagerComponent") then
			local villager = entity:get("VillagerComponent")

			if not villager:getHome() then
				local header = spriteSheet:getSprite("headers", "no-home-icon")
				local w, _ = header:getDimensions()

				local x, y = entity:get("GroundComponent"):getIsometricPosition()
				x = x - w / 2
				y = y - 28 -- TODO: Guesswork, not true for children.
				spriteSheet:draw(header, x, y)
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
		elseif entity:has("ConstructionComponent") then
			local header = spriteSheet:getSprite("headers", "4-spot-building-header")
			local x, y = sprite:getOriginalDrawPosition()
			local w, h = header:getDimensions()
			local tw = sprite:getSprite():getWidth()

			x = x + (tw - w) / 2
			y = y - h / 2
			spriteSheet:draw(header, x, y)

			local icon = spriteSheet:getSprite("headers", "occupied-icon")
			for i=1,entity:get("AssignmentComponent"):getNumAssignees() do
				-- XXX: Value
				spriteSheet:draw(icon, 9 + x + ((i - 1) * (icon:getWidth() + 1)), y + 1)
			end
		elseif entity:has("DwellingComponent") then
			local dwelling = entity:get("DwellingComponent")
			local header = spriteSheet:getSprite("headers", "dwelling-header")
			local x, y = sprite:getOriginalDrawPosition()
			local w, h = header:getDimensions()
			local tw = sprite:getSprite():getWidth()

			x = x + (tw - w) / 2
			y = y - h / 2
			spriteSheet:draw(header, x, y)

			if dwelling:isRelated() then
				-- XXX: Value
				spriteSheet:draw(spriteSheet:getSprite("headers", "family-ties-icon"), x + 22, y)
			end

			local headerData = spriteSheet:getData("dwelling-header")
			for _,type in ipairs({ "boys", "girls", "food" }) do
				local data = spriteSheet:getData(type .. "-count")
				local Fx, Fy = x + data.bounds.x - headerData.bounds.x, y + data.bounds.y - headerData.bounds.y

				local amount
				if type == "food" then
					love.graphics.setFont(love.graphics.newFont("asset/font/Norse.otf", data.bounds.h))
					amount = dwelling:getFood()
				else
					love.graphics.setFont(love.graphics.newFont(data.bounds.h))
					if type == "boys" then
						amount = dwelling:getNumBoys()
					else
						amount = dwelling:getNumGirls()
					end
				end

				-- Drop shadow
				--love.graphics.setColor(0, 0, 0, 0.5)
				love.graphics.setColor(RenderSystem.NEW_OUTLINE_COLOR)
				love.graphics.print(tostring(amount), Fx + 1, Fy + 1)
				-- Text
				love.graphics.setColor(RenderSystem.BEHIND_OUTLINE_COLOR)
				love.graphics.print(tostring(amount), Fx, Fy)
			end
			love.graphics.setColor(1, 1, 1, 1)

			local maleIcon = spriteSheet:getSprite("headers", "male-icon")
			local femaleIcon = spriteSheet:getSprite("headers", "female-icon")
			local villagers = entity:get("AssignmentComponent"):getAssignees()
			for i=1,#villagers do
				local icon = villagers[i]:get("VillagerComponent"):getGender() == "male" and maleIcon or femaleIcon
				spriteSheet:draw(icon, 10 + x + ((i - 1) * (icon:getWidth() + 1)), y + 1)
			end
		end
	end
end

return RenderSystem
