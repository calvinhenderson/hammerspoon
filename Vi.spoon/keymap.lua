--- @alias Vi.Mode 'n'|'i'|'v'|'s'|'c'|'o' A single mode
--- @alias Vi.Modes table<Vi.Mode> A list of modes
--- @alias Vi.KeyStr string A vi-style key mapping. i.e. `<C-w>j` or `gW`
--- @alias Vi.Action function A callback function that gets called when a shortcut is executed
--- @alias Vi.Metadata { name: string, leave?: boolean } Optional metadata
--- @alias Vi.Binding table<Vi.Mode|Vi.Modes, Vi.KeyStr, Vi.Action, Vi.Metadata?>

--- @class Vi.Keymap
local Keymap = {}
Keymap.__index = Keymap

--- Map Vim special key names to Hammerspoon key names
local KEYS_TO_HS = {
	["CR"] = "return",
	["Esc"] = "escape",
	["Space"] = "space",
	["Tab"] = "tab",
	["BS"] = "delete",
	["Up"] = "up",
	["Down"] = "down",
	["Left"] = "left",
	["Right"] = "right",
	["a"] = "a",
	["b"] = "b",
	["c"] = "c",
	["d"] = "d",
	["e"] = "e",
	["f"] = "f",
	["g"] = "g",
	["h"] = "h",
	["i"] = "i",
	["j"] = "j",
	["k"] = "k",
	["l"] = "l",
	["m"] = "m",
	["n"] = "n",
	["o"] = "o",
	["p"] = "p",
	["q"] = "q",
	["r"] = "r",
	["s"] = "s",
	["t"] = "t",
	["u"] = "u",
	["v"] = "v",
	["w"] = "w",
	["x"] = "x",
	["y"] = "y",
	["z"] = "z",
	["`"] = "`",
	["1"] = "1",
	["2"] = "2",
	["3"] = "3",
	["4"] = "4",
	["5"] = "5",
	["6"] = "6",
	["7"] = "7",
	["8"] = "8",
	["9"] = "9",
	["0"] = "0",
	["-"] = "-",
	["="] = "=",
	["["] = "[",
	["]"] = "]",
	["\\"] = "\\",
	[";"] = ";",
	["'"] = "'",
	[","] = ",",
	["."] = ".",
	["/"] = "/",
	["A"] = "shift-a",
	["B"] = "shift-b",
	["C"] = "shift-c",
	["D"] = "shift-d",
	["E"] = "shift-e",
	["F"] = "shift-f",
	["G"] = "shift-g",
	["H"] = "shift-h",
	["I"] = "shift-i",
	["J"] = "shift-j",
	["K"] = "shift-k",
	["L"] = "shift-l",
	["M"] = "shift-m",
	["N"] = "shift-n",
	["O"] = "shift-o",
	["P"] = "shift-p",
	["Q"] = "shift-q",
	["R"] = "shift-r",
	["S"] = "shift-s",
	["T"] = "shift-t",
	["U"] = "shift-u",
	["V"] = "shift-v",
	["W"] = "shift-w",
	["X"] = "shift-x",
	["Y"] = "shift-y",
	["Z"] = "shift-z",
	["~"] = "shift-`",
	["!"] = "shift-1",
	["@"] = "shift-2",
	["#"] = "shift-3",
	["$"] = "shift-4",
	["%"] = "shift-5",
	["^"] = "shift-6",
	["&"] = "shift-7",
	["*"] = "shift-8",
	["("] = "shift-9",
	[")"] = "shift-0",
	["_"] = "shift--",
	["+"] = "shift-=",
	["{"] = "shift-[",
	["}"] = "shift-]",
	["|"] = "shift-\\",
	[":"] = "shift-;",
	['"'] = "shift-'",
	["<"] = "shift-,",
	[">"] = "shift-.",
	["?"] = "shift-/",
}

--- Initializes the Keymap module
function Keymap:init(vi)
	self.Vi = vi
	self.bindings = {
		-- ["n"] = ... Normal (Apps/Windows)
		-- ["i"] = ... Insert (Typing/Passthrough)
		-- ["v"] = ... Visual (Mouse/Scroll)
		-- ["s"] = ... Selection (App/Window Switcher)
		-- ["c"] = ... Command (Fuzzy Finder)
		-- ["o"] = ... Operator Pending
	}
end

--- Logs a message from the Keymap module
function Keymap:log(...)
	self.Vi.log("Keymap", ...)
end

--- Parses Vim key mapping strings into a sequential table of Hammerspoon key chords.
---
--- ## Usage
---
--- ```lua
--- Keymap.parseKeyString("<C-w>v")
---   -> {"ctrl-w", "v"}
--- ```
---
--- ```lua
--- Keymap.parseKeyString("gW")
---   -> {"g", "shift-w"}
--- ```
--- @param keyStr string The keyboard mapping to be parsed
--- @return table
function Keymap:parseKeyString(keyStr)
	local sequence = {}
	local i = 1
	local len = #keyStr

	while i <= len do
		local char = keyStr:sub(i, i)

		-- Handle <modifier-key> or <special> notation
		if char == "<" then
			local closeIdx = keyStr:find(">", i)
			if closeIdx then
				local token = keyStr:sub(i + 1, closeIdx - 1)
				local mods = {}
				local baseKey = token

				-- Check for hyphenated modifiers (e.g., C-S-w)
				if token:find("-") then
					local parts = {}
					for part in token:gmatch("([^-]+)") do
						table.insert(parts, part)
					end

					baseKey = table.remove(parts) -- The last part is the actual key

					-- Map Vim modifiers to Hammerspoon flags
					for _, mod in ipairs(parts) do
						if mod == "C" then
							table.insert(mods, "ctrl")
						elseif mod == "S" then
							table.insert(mods, "shift")
						elseif mod == "A" or mod == "M" then
							table.insert(mods, "alt")
						elseif mod == "D" then
							table.insert(mods, "cmd") -- D for Command (MacVim standard)
						end
					end
				end

				-- Translate special keys like CR -> return
				baseKey = KEYS_TO_HS[baseKey] or baseKey

				-- Sort modifiers alphabetically for consistent serialization
				table.sort(mods)
				local serialized = ""
				if #mods > 0 then
					serialized = table.concat(mods, "-") .. "-"
				end
				serialized = serialized .. baseKey

				table.insert(sequence, serialized)
				i = closeIdx + 1
			else
				-- Failsafe: Unmatched '<', treat as literal character
				table.insert(sequence, "shift-,")
				i = i + 1
			end
		else
			-- Handle standard characters
			table.insert(sequence, KEYS_TO_HS[char] or char)
			i = i + 1
		end
	end

	return sequence
end

local function bindMapping(parent, bindKey, mappings, action, metadata)
	local mapping = table.remove(mappings, 1)

	if parent[bindKey] == nil then
		parent[bindKey] = {}
	end

	if mapping == nil then
		-- bind the action and exit
		parent[bindKey].action = action
		parent[bindKey].metadata = metadata

		return
	else
		-- recursively bind
		return bindMapping(parent[bindKey], mapping, mappings, action, metadata)
	end
end

--- Binds the given `keyStr` to `action` for `modes` modes.
--- @param mode Vi.Mode|Vi.Modes
--- @param keyStr Vi.KeyStr
--- @param action Vi.Action
--- @param metadata? Vi.Metadata
function Keymap:set(mode, keyStr, action, metadata)
	local modes = mode
	if type(modes) == "string" then
		modes = { mode }
	end

	for _, m in ipairs(modes) do
		local mappings = self:parseKeyString(keyStr)
		bindMapping(self.bindings, m, mappings, action, metadata)
	end
end

--- Merges the given bindings into the global bindings table. Overwriting any existing bindings.
--- @param bindings table<Vi.Binding>
function Keymap:mergeBindings(bindings)
	for _, binding in ipairs(bindings) do
		assert(
			#binding == 3 or #binding == 4,
			"invalid binding " .. hs.inspect(binding) .. " given. expected { mode(s), keyStr, action, metadata? }"
		)
		self:set(table.unpack(binding))
	end
end

--- Gets the table of bindings for the given mode.
--- @param mode Vi.Mode
--- @return table<Vi.Binding>
function Keymap:forMode(mode)
	return self.bindings[mode] or {}
end

return Keymap
