local ScrollButton = {}
ScrollButton.__index = ScrollButton

-- Metadata
ScrollButton.name = "ScrollButton"
ScrollButton.version = "0.1"
ScrollButton.author = "Calvin Henderson"
ScrollButton.homepage = "https://github.com/calvinhenderson/hammerspoon/blob/main/ScrollButton.spoon"
ScrollButton.license = "MIT - https://opensource.org/licenses/MIT"

-- Load modules
ScrollButton.Config = dofile(hs.spoons.resourcePath("config.lua"))
ScrollButton.Events = dofile(hs.spoons.resourcePath("events.lua"))

-- Initialize modules
ScrollButton.Config.init(ScrollButton)
ScrollButton.Events.init(ScrollButton)

--- @param config ScrollButton.Configuration
function ScrollButton:setup(config)
	ScrollButton.Config:mergeConfig(config)
end

function ScrollButton:start()
	ScrollButton.Config:start()
	ScrollButton.Events:start()
end

function ScrollButton:stop()
	ScrollButton.Events:stop()
end

return ScrollButton
