--- @alias ScrollButton.Configuration {
---   button?: integer,
---   key?: string,
---   x_scale: number,
---   y_scale: number,
---   scroll_direction: -1 | 1 | 0,
---   unit: "pixel" | "line",
--- }

local Config = {}
Config.__index = Config

local DEFAULTS = {
	button = 3,
	x_scale = 1,
	y_scale = 1,
	scroll_direction = 0,
	unit = "pixel",
}

--- @param scroll_button table
function Config.init(scroll_button)
	Config.ScrollButton = scroll_button
end

function Config:start() end

--- @param new ScrollButton.Configuration
function Config:mergeConfig(new)
	if not self.config then
		self.config = {}
	end

	for k, v in pairs(new) do
		self.config[k] = v
	end
end

function Config:get(key)
	return self.config[key] or DEFAULTS[key]
end

return Config
