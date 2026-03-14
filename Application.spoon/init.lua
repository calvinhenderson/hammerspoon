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

--- @class Application.App
--- @field new_window function? Opens a new application window
--- @field prev_tab function? Goes to the prev application tab
--- @field next_tab function? Goes to the next application tab

-- Load application-specific configs
Application.Apps = {
	Alacritty = load_app("Alacritty"),
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
	return false
end

function Application._apps_by_bundle_id()
	if Application._apps_bundle_ids then
		return Application._apps_bundle_ids
	end

	Application._apps_bundle_ids = {}
	for _, v in pairs(Application.Apps) do
		if v.bundleid then
			Application._apps_bundle_ids[v.bundleid] = v
		end
	end

	return Application._apps_bundle_ids
end

--- Find an app-specific module for the given bundleid (or the currently focused application)
function Application._app_module_fn(bundleid, fn)
	if not bundleid then
		bundleid = hs.application.frontmostApplication():bundleID()
	end

	local app = Application._apps_by_bundle_id()[bundleid]
	if type(app) == "table" and type(app[fn]) == "function" then
		app[fn]()
		return true
	else
		return false
	end
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

function Application.new_window(bundleid)
	if not Application._app_module_fn(bundleid, "new_window") then
		hs.eventtap.keyStroke({ "cmd" }, "n")
	end
end

function Application.prev_tab(bundleid)
	if not Application._app_module_fn(bundleid, "prev_tab") then
		-- no default action
		return nil
	end
end

function Application.next_tab(bundleid)
	if not Application._app_module_fn(bundleid, "next_tab") then
		-- no default action
		return nil
	end
end

return Application
