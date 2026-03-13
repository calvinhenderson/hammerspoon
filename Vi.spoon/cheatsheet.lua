--- @class Vi.Cheatsheet
local Cheatsheet = {}
Cheatsheet.__index = Cheatsheet

local TEMPLATE_FIELD = {
	STYLESHEET = 1,
	SHORTCUTS = 2,
	ICON = 3,
	TITLE = 4,
	DESCRIPTION = 5,
}

local TEMPLATE_HTML = [[
<!DOCTYPE html>
<html>
<head><style type="text/css">%s</style></head>
<body>
  <div class="cheatsheet">
    <div class="content">
      <div class="columns">%s</div>
    </div>
    <hr>
    <footer>
      %s
      <div class="title-section">
        <div class="title">%s</div>
        <small class="subtitle">%s</small>
      </div>
    </footer>
  </div>
</body>
</html>
]]

local MODIFIER_GLYPHS = {
	["cmd"] = "⌘",
	["alt"] = "⌥",
	["shift"] = "⇧",
	["ctrl"] = "⌃",
	["fn"] = "fn",
}

local KEY_GLYPHS = {
	["return"] = "↩",
	["enter"] = "↩",
	["delete"] = "⌫",
	["escape"] = "⎋",
	["right"] = "→",
	["left"] = "←",
	["up"] = "↑",
	["down"] = "↓",
	["pageup"] = "⇞",
	["pagedown"] = "⇟",
	["home"] = "↖",
	["end"] = "↘",
	["tab"] = "⇥",
	["space"] = "␣",
}

local function r(x, y, w, h)
	return { x = x, y = y, w = w, h = h }
end

local function split(str, delimiter)
	local parts = {}
	local pattern = string.format("([^%s]+)", delimiter)
	for p in str:gmatch(pattern) do
		table.insert(parts, p)
	end
	return parts
end

local function deep_copy(tbl)
	local copy = {}
	if type(tbl) == "table" then
		for k, v in pairs(tbl) do
			copy[k] = deep_copy(v)
		end
	else
		copy = tbl
	end
	return copy
end

function Cheatsheet:init(vi)
	self.Vi = vi

	if not self.view then
		self.view = assert(hs.webview.new(r(0, 0, 0, 0)))
		self.view:windowStyle({ "utility", "titled", "closable" })
		self.view:level(hs.drawing.windowLevels.modalPanel)
		self.view:darkMode(true)
		self.view:shadow(true)
	end
end

function Cheatsheet:template_hotkey(hotkey, title)
	return string.format(
		[[
    <div class="block-item %s">
    <div class="shortcut-hotkey">%s</div>
    <div class="shortcut-title">%s</div>
    </div>
    ]],
		title and "block-item-title",
		hotkey,
		title
	)
end

function Cheatsheet:template_icon(icon)
	return icon and string.format(
		[[
    <img class="icon" src="%s" />
    ]],
		icon
	)
end

function Cheatsheet:shortcut_label(shortcut)
	if shortcut and shortcut.metadata and shortcut.metadata.name then
		return shortcut.metadata.name
	else
		return "→"
	end
end

function Cheatsheet:shortcut_metadata(shortcut)
	return shortcut.metadata or {}
end

function Cheatsheet:shortcut_hotkey(str)
	local hotkey = ""
	local mods = split(str, "-")
	local key = table.remove(mods, #mods)
	table.sort(mods)
	for _, m in ipairs(mods) do
		hotkey = hotkey .. (MODIFIER_GLYPHS[m] or m)
	end
	return hotkey .. (KEY_GLYPHS[key] or key)
end

function Cheatsheet:template_shortcuts(shortcuts)
	local s = ""

	-- sort the keys alphabetically
	local sorted_keys = {}
	for k, v in pairs(shortcuts) do
		if k ~= "metadata" and k ~= "action" then
			sorted_keys[#sorted_keys + 1] = {
				k = k,
				v = deep_copy(v),
			}
		end
	end

	table.sort(sorted_keys, function(a, b)
		return a.k < b.k
	end)

	local back = { k = "delete", v = { metadata = { name = "Back" } } }
	local cancel = { k = "escape", v = { metadata = { name = "Cancel" } } }
	local exit = { k = "escape", v = { metadata = { name = "Exit" } } }

	-- These shorcuts are hard-coded
	if self.Vi:numEvents() > 0 then
		table.insert(sorted_keys, #sorted_keys + 1, back)
		table.insert(sorted_keys, #sorted_keys + 1, cancel)
	else
		table.insert(sorted_keys, #sorted_keys + 1, exit)
	end

	for _, shortcut in ipairs(sorted_keys) do
		local hotkey = self:shortcut_hotkey(shortcut.k)
		local label = self:shortcut_label(shortcut.v)
		s = s
			.. string.format(
				[[
        <div class="block">%s</div>
        ]],
				self:template_hotkey(hotkey, label)
			)
	end
	return s
end

function Cheatsheet:build_template(icon, title, description, shortcuts, css)
	if not icon then
		icon = ""
	end

	local model = {
		[TEMPLATE_FIELD.ICON] = self:template_icon(icon),
		[TEMPLATE_FIELD.TITLE] = title,
		[TEMPLATE_FIELD.DESCRIPTION] = description,
		[TEMPLATE_FIELD.STYLESHEET] = css,
		[TEMPLATE_FIELD.SHORTCUTS] = self:template_shortcuts(shortcuts),
	}

	return string.format(TEMPLATE_HTML, table.unpack(model))
end

function Cheatsheet:resource(filename)
	local path = hs.spoons.resourcePath(filename)
	local file = assert(io.open(path, "rb"))
	local data = file:read("*all")
	file:close()
	return data
end

function Cheatsheet:show(shortcuts)
	local metadata = self:shortcut_metadata(shortcuts)
	self.name = metadata.name or ""
	self.description = metadata.description or ""
	self.shortcuts = shortcuts

	local app = hs.application.frontmostApplication()
	local icon = nil

	if app then
		local bundleId = app:bundleID()
		icon = hs.image.imageFromAppBundle(bundleId)
		icon = icon and icon:encodeAsURLString()
	end

	local title = self.name .. " Cheat Sheet"

	self.view:windowTitle(title)

	local frame = hs.screen.mainScreen():fullFrame()
	local width = 200
	local height = 400 + (#shortcuts * 100)
	self.view:frame({
		x = frame.w - width,
		y = frame.h - height,
		w = width,
		h = height,
	})

	local css = self:resource("cheatsheet.css")
	local template = self:build_template(icon, title, self.description, self.shortcuts, css)
	self.view:html(template)

	self.view:show()
end

function Cheatsheet:hide()
	if self.view then
		self.view:hide()
	end
end

return Cheatsheet
