--- @class CommandPalette
--- @alias CommandPalette.Action function<CommandPalette.Choice>
--- @alias CommandPalette.Choice {
---   text: string,
---   subText?: string,
---   image?: hs.image,
---   application?: string,
---   command?: string,
---   applescript?: string,
---   action?: CommandPalette.Action,
---   wid?: number|nil,
--- }
local CommandPalette = {}
CommandPalette.__index = CommandPalette

-- Metadata
CommandPalette.name = "CommandPalette"
CommandPalette.version = "0.1"
CommandPalette.author = "Calvin Henderson"
CommandPalette.homepage = "https://github.com/calvinhenderson/hammerspoon/blob/main/CommandPalette.spoon"
CommandPalette.license = "MIT - https://opensource.org/licenses/MIT"

CommandPalette.logger = hs.logger.new("CommandPalette", "info")

local function sort_choices(choices)
	table.sort(choices, function(a, b)
		return a.subText < b.subText and a.text < b.text
	end)
end

--- Initializes the CommandPalette
--- @return CommandPalette # reference to self for chaining
function CommandPalette:init()
	self.choices = self.choices or {}
	self.actions = self.actions or {}

	if not self.chooser then
		self.chooser = hs.chooser
			.new(function(choice)
				self:choose(choice)
			end)
			:searchSubText(true)
	end

	return self
end

--- Sets the default choices for the chooser
--- @param choices CommandPalette.Choice[]
--- @return CommandPalette # reference to self for chaining
function CommandPalette:defaultChoices(choices)
	self:init()

	self.actions = {}
	self.choices = {}

	for _, choice in ipairs(choices) do
		self:addChoice(choice)
	end

	return self
end

--- Removes a choice by matching a key in the given choice
--- @return CommandPalette # reference to self for chaining
function CommandPalette:removeChoice(choice)
	self:init()
	for i, c in ipairs(self.choices) do
		if string.find(c.text, choice.text) or string.find(c.subText, choice.subText) then
			table.remove(self.choices, i)
			return self
		end
	end

	return self
end

--- Adds a new choice
--- @param choice CommandPalette.Choice
--- @return CommandPalette # reference to self for chaining
function CommandPalette:addChoice(choice)
	self:init()
	-- Functions cannot be encoded in the chooser so we must
	-- replace functions with a key to lookup the function.
	if choice.action and type(choice.action) == "function" then
		local k = ("%s:%s"):format(choice.text, choice.subText)
		self.actions[k] = choice.action
		choice.action = k
	end

	table.insert(self.choices, #self.choices + 1, choice)

	return self
end

--- Performs the action specified by the given choice
--- @param choice CommandPalette.Choice
--- @return CommandPalette # reference to self for chaining
function CommandPalette:choose(choice)
	self:init()

	if not choice then
		return self
	elseif choice.command then
		hs.execute(choice.command, true)
	elseif choice.application then
		if hs.application.open(choice.application) then
			self.logger.i("Activated application " .. choice.application)
		elseif
			hs.osascript.applescript(([[
        tell application "%s" to activate
      ]]):format(choice.application))
		then
			self.logger.i("Activated application " .. choice.application)
		else
			hs.alert("Failed to find application " .. choice.application)
		end
	elseif choice.applescript then
		hs.osascript.applescript(choice.applescript)
	elseif choice.action and type(self.actions[choice.action]) == "function" then
		self.actions[choice.action]()
	elseif choice.wid then
		if self.windows and self.windows[choice.wid] then
			self.windows[choice.wid]:becomeMain():focus()
		else
			self.logger.ef("Failed to find window [%s] in %s", hs.inspect(choice.wid), hs.inspect(self.windows))
			hs.alert("Failed to find window")
		end
	end

	return self
end

--- Sets the `hs.chooser` placeholder text to `placeholder`
--- @param placeholder? string
--- @return CommandPalette # reference to self for chaining
function CommandPalette:setPlaceholder(placeholder)
	self:init()
	self.chooser:placeholderText(placeholder or "")
	return self
end

--- Sets whether to include open windows in the command palette
--- @param include? boolean Defaults to true
--- @return CommandPalette # reference to self for chaining
function CommandPalette:includeWindows(include)
	self:init()
	self.exclude_windows = not include
	return self
end

--- Shows the `hs.chooser` with the current choices
--- @return CommandPalette # reference to self for chaining
function CommandPalette:show()
	self:init()

	local choices = {}

	if not self.exclude_windows then
		self.windows = hs.window.filter.new():setCurrentSpace(nil):getWindows()
		for i, w in ipairs(self.windows) do
			local app = w:application()

			local title = string.format("%s - %s", w:title() ~= "" and w:title() or app:name(), app:name())

			table.insert(choices, {
				wid = i,
				text = title,
				subText = "App Windows",
				image = app and app:bundleID() and hs.image.imageFromAppBundle(app:bundleID()),
			})
		end
	end

	for _, c in ipairs(self.choices) do
		table.insert(choices, c)
	end

	sort_choices(choices)

	self.chooser:query("")
	self.chooser:choices(choices)
	self.chooser:show()

	return self
end

return CommandPalette
