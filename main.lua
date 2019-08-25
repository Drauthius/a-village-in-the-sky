-- Set the default filter before loading anything.
love.graphics.setDefaultFilter("linear", "nearest")

local babel = require "lib.babel"
local GameState = require "lib.hump.gamestate"

local MainMenu = require "src.mainmenu"

local screen = require "src.screen"

function love.load()
	--local Bound = require "lib.gui.bound"
	--Bound.static.debug = true

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
