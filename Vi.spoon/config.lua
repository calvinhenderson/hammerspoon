--- @class Vi.Config
--- @field alert_enabled boolean Whether to play the alert sounds
--- @field alert_sound string The sound effect to play when alerting
--- @field alert_volume number The volume of the alert sound effect
--- @field actios_leave_modes boolean Whether performing an action will leave the current mode.
local Config = {}
Config.__index = Config

function Config:init(vi)
	self.Vi = vi
	self.alert_enabled = true
	self.alert_sound = "Tink"
	self.alert_volume = 1.0
	self.actions_leave_modes = true
end

function Config:mergeConfig(config)
	for k, v in pairs(config) do
		self[k] = v
	end
end

return Config
