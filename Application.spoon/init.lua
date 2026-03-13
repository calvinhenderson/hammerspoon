local Application = {}
Application.__index = Application

-- Metadata
Application.name = "Application"
Application.version = "0.1"
Application.author = "Calvin Henderson"
Application.homepage = "https://github.com/calvinhenderson/hammerspoon/blob/main/Application.spoon"
Application.license = "MIT - https://opensource.org/licenses/MIT"

local function load_app(app)
	local path = string.format("applications/%s.lua", app)
	return dofile(hs.spoons.resourcePath(path))
end

-- Load application-specific configs
Application.Apps = {
	Chrome = load_app("chrome"),
}

function Application._matches(text, matchtext)
	return string.find(text, matchtext) ~= nil
end

function Application._match(window, matchtexts)
	print("[Application._match", hs.inspect(window:title()))
	local bundleid = window:application():bundleID()
	if hs.fnutils.contains(matchtexts, bundleid) then
		return true
	end
	local title = window:title()
	for _, matchtext in pairs(matchtexts) do
		if Application._matches(title, matchtext) then
			return true
		end
	end
	print("not matching title:" .. title .. "or bundleid:" .. bundleid)
	return false
end

function Application.find_window(matchtexts)
	local new_w = nil

	if type(matchtexts) == "string" then
		matchtexts = { matchtexts } -- further code assumes a table
	end

	if Application._match(hs.window.focusedWindow(), matchtexts) then
		-- app has focus, find last matching window
		for _, w in pairs(hs.window.orderedWindows()) do
			if Application._match(w, matchtexts) then
				new_w = w -- remember last match
			end
		end
	else
		local all_windows = hs.window.filter.new(true):setCurrentSpace(nil):getWindows()
		-- app does not have focus, find first matching window
		for _, w in pairs(all_windows) do
			if Application._match(w, matchtexts) then
				new_w = w
				break -- break on first match
			end
		end
	end

	return new_w
end

function Application.focus_window(matchtexts)
	local w = Application.find_window(matchtexts)
	if w then
		w:raise():focus()
	else
		hs.alert.show("No window open for " .. hs.inspect(matchtexts))
	end
end

function Application.focus_or_launch(matchtexts, launch_fn)
	local w = Application.find_window(matchtexts)
	if w then
		w:raise():focus()
	else
		launch_fn()
	end
end

return Application
