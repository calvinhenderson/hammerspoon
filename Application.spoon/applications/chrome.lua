--- @class Application.App
local Chrome = {}
Chrome.__index = Chrome

Chrome.bundleid = "com.google.Chrome"

function Chrome.launch_profile(profile)
	hs.execute(string.format("open -nb %s --args --profile-directory='%s'", Chrome.bundleid, profile or "Default"))
end

function Chrome.prev_tab()
	hs.eventtap.keyStroke({ "ctrl", "shift" }, "tab")
	return true
end

function Chrome.next_tab()
	hs.eventtap.keyStroke({ "ctrl" }, "tab")
	return true
end

return Chrome
