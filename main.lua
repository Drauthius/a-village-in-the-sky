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

-- Set the default filter before loading anything.
love.graphics.setDefaultFilter("linear", "nearest")

local babel = require "lib.babel"
local GameState = require "lib.hump.gamestate"

local MainMenu = require "src.mainmenu"

local screen = require "src.screen"

function love.load()
	GameState.registerEvents()

	screen:setUp()

	babel.init({
		locales_folders = { "asset/i18n" }
	})

	GameState.switch(MainMenu, true)
end

function love.resize(width, height)
	screen:resize(width, height)
end
