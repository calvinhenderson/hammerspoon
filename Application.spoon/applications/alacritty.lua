--- @class Application.App
local Alacritty = {}
Alacritty.__index = Alacritty

Alacritty.bundleid = "org.alacritty"

function Alacritty.new_window()
	hs.execute(string.format("open -nb %s", Alacritty.bundleid))
end

function Alacritty.prev_tab()
	hs.eventtap.keyStroke({ "cmd", "shift" }, "[")
	return true
end

function Alacritty.next_tab()
	hs.eventtap.keyStroke({ "cmd", "shift" }, "]")
	return true
end

return Alacritty
