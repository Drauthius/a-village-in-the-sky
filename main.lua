-- Set the default filter before loading anything.
love.graphics.setDefaultFilter("linear", "nearest")

local babel = require "lib.babel"
local GameState = require "lib.hump.gamestate"

local Game = require "src.game"

local screen = require "src.screen"

function love.load()
	--local Bound = require "lib.gui.bound"
	--Bound.static.debug = true

	-- Too lazy to specify all callbacks except the error handler.
	-- (Why is the error handler even overridden?)
	local errorhandler = love.errorhandler
	GameState.registerEvents()
	-- Restore the default error handler.
	love.errorhandler = errorhandler

	screen:setUp()

	babel.init({
		locales_folders = { "asset/i18n" }
	})

	GameState.switch(Game)
end

function love.resize(width, height)
	screen:resize(width, height)
end
