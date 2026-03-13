--- @alias Vi.Alert table
local Alert = {}
Alert.__index = Alert

function Alert:init(vi)
	self.Vi = vi
end

function Alert:alert()
	if not self.Vi:config("alert_enabled") then
		return
	end

	local sound = hs.sound.getByName(self.Vi:config("alert_sound"))
	local volume = self.Vi:config("alert_volume", 1)

	if sound then
		sound:volume(volume):play()
	end
end

return Alert
