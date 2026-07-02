--- @class Application.App
local Chrome = {}
Chrome.__index = Chrome

Chrome.bundleid = "com.google.Chrome"

function Chrome.launch_profile(profile, ...)
	local args = table.concat(table.pack(...), " ")
	hs.execute(
		string.format(
			"open -nb %s --args --profile-directory='%s' %s",
			Chrome.bundleid,
			profile or "Default",
			args or ""
		)
	)
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
