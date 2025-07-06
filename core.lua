DialogKey = LibStub("AceAddon-3.0"):NewAddon("DialogKey", "AceConsole-3.0", "AceTimer-3.0")

local defaults = {							-- Default settings
	global = {
		keys = {
			"SPACE",
		},
		ignoreDisabledButtons = true,
		showGlow = true,
		shownBindWarning = false,
		additionalButtons = {}
	}
}

local buttons = {							-- List of buttons to try and click
	StaticPopup1Button1,
	QuestFrameCompleteButton,
	QuestFrameCompleteQuestButton,
	QuestFrameAcceptButton,
	GossipTitleButton1
}

function DialogKey:OnInitialize()			-- Runs on addon initialization
	self.db = LibStub("AceDB-3.0"):New("DialogKeyDB", defaults, true)
	
	self.keybindMode = false
	self.keybindIndex = 0
	
	self:RegisterChatCommand("dk", "ChatCommand")
	self:RegisterChatCommand("dkey", "ChatCommand")
	self:RegisterChatCommand("dialogkey", "ChatCommand")
	
	self.frame = CreateFrame("Frame", "DialogKeyFrame", UIParent)
	self.frame:EnableKeyboard(true)
	self.frame:SetPropagateKeyboardInput(true)
	self.frame:SetFrameStrata("TOOLTIP") -- Ensure we receive keyboard events first
	self.frame:SetScript("OnKeyDown", self.HandleKey)
	
	self.glowFrame = CreateFrame("Frame", "DialogKeyGlow", UIParent)
	self.glowFrame:SetPoint("CENTER", 0, 0)
	self.glowFrame:SetFrameStrata("TOOLTIP")
	self.glowFrame:SetSize(50,50)
	self.glowFrame:SetScript("OnUpdate", self.GlowFrameUpdate)
	self.glowFrame:Hide()
	self.glowFrame.tex = self.glowFrame:CreateTexture()
	self.glowFrame.tex:SetAllPoints()
	self.glowFrame.tex:SetTexture(1,1,0,0.5)
	
	self:ShowOldKeybindWarning()
	self:CreateOptionsFrame()
end

function DialogKey:ChatCommand(input)		-- Chat command handler
	args = {strsplit(" ", input:trim())}
	
	if args[1] == "v" or args[1] == "ver" or args[1] == "version" then
		print(GAME_VERSION_LABEL..": "..GetAddOnMetadata("DialogKey","Version"))
	elseif args[1] == "add" or args[1] == "a" or args[1] == "watch" then
		if args[2] then
			self:WatchFrame(args[2])
		else
			self:AddMouseFocus()
		end
	elseif args[1] == "remove" or args[1] == "r" or args[1] == "unwatch" then
		if args[2] then
			self:UnwatchFrame(args[2])
		else
			self:RemoveMouseFocus()
		end
	else
		InterfaceOptionsFrame_OpenToCategory(self.options)
		InterfaceOptionsFrame_OpenToCategory(self.options)
	end
end

function DialogKey:CreateOptionsFrame()		-- Constructs the options frame
	self.options = CreateFrame("Frame")
	
	local title = self.options:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetFont("Fonts\\FRIZQT__.TTF", 16)
	title:SetText("DialogKey")
	title:SetPoint("TOPLEFT", 16, -16)
	
	local subtitle = self.options:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	subtitle:SetFont("Fonts\\FRIZQT__.TTF", 10)
	subtitle:SetText("Version " .. GetAddOnMetadata("DialogKey","Version"))
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 4, -8)
	
	self.options.keybindButtons = {}
	
	local button1 = CreateFrame("Button", nil, self.options, "UIPanelButtonTemplate")
	button1:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 4,-64)
	button1:SetWidth(120)
	button1:SetHeight(26)
	button1:SetText(GetBindingText(self.db.global.keys[1]))
	button1:RegisterForClicks("LeftButtonDown", "RightButtonDown")
	
	button1:SetScript("OnClick", function(self, button)
		if button == "LeftButton" then
			DialogKey:EnableKeybindMode(1)
		else
			DialogKey:ClearBind(1)
		end
	end)
	
	button1:SetScript("OnHide", DialogKey.DisableKeybindMode)
	self.options.keybindButtons[1] = button1
	
	local button2 = CreateFrame("Button", nil, self.options, "UIPanelButtonTemplate")
	button2:SetPoint("LEFT", button1, "RIGHT", 30,0)
	button2:SetWidth(120)
	button2:SetHeight(26)
	button2:SetText(GetBindingText(self.db.global.keys[2]))
	button2:RegisterForClicks("LeftButtonDown", "RightButtonDown")
	
	button2:SetScript("OnClick", function(self, button)
		if button == "LeftButton" then
			DialogKey:EnableKeybindMode(2)
		else
			DialogKey:ClearBind(2)
		end
	end)
	
	button2:SetScript("OnHide", DialogKey.DisableKeybindMode)
	self.options.keybindButtons[2] = button2
	
	local keybindOr = self.options:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	keybindOr:SetFont("Fonts\\FRIZQT__.TTF", 12)
	keybindOr:SetTextColor(1,1,1,1)
	keybindOr:SetText("or")
	keybindOr:SetPoint("LEFT", button1, "RIGHT", 0, 2)
	keybindOr:SetPoint("RIGHT", button2, "LEFT", 0, 2)
	
	local keybindTitle = self.options:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	keybindTitle:SetFont("Fonts\\FRIZQT__.TTF", 12)
	keybindTitle:SetTextColor(1,1,1,1)
	keybindTitle:SetJustifyH("LEFT")
	keybindTitle:SetWidth(500)
	keybindTitle:SetWordWrap(true)
	keybindTitle:SetText("Click the button to set the key used to accept quests, confirm dialogs, etc. Right-click a button to unbind a key. The key will perform its usual action if there's nothing to accept or confirm.")
	keybindTitle:SetPoint("BOTTOMLEFT", button1, "TOPLEFT", 0, 4)
	
	local keybindReminder = self.options:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	keybindReminder:SetFont("Fonts\\FRIZQT__.TTF", 10)
	keybindReminder:SetTextColor(1,1,1,1)
	keybindReminder:SetText("Press any key...")
	keybindReminder:SetPoint("LEFT", button2, "RIGHT", 4, 0)
	keybindReminder:Hide()
	self.options.keybindReminder = keybindReminder
	
	local ignoreCheckbox = CreateFrame("CheckButton", "DialogKeyOptIgnore", self.options, "UICheckButtonTemplate")
	ignoreCheckbox:SetPoint("TOPLEFT", button1, "BOTTOMLEFT", -3, -20)
	_G["DialogKeyOptIgnoreText"]:SetText("Ignore Disabled Buttons")
	ignoreCheckbox:SetScript("OnShow", function(self) self:SetChecked(DialogKey.db.global.ignoreDisabledButtons) end)
	ignoreCheckbox:SetScript("OnClick", function(self) DialogKey.db.global.ignoreDisabledButtons = self:GetChecked() end)
	ignoreCheckbox:SetChecked(DialogKey.db.global.ignoreDisabledButtons)
	
	local ignoreSubtitle = ignoreCheckbox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	ignoreSubtitle:SetFont("Fonts\\FRIZQT__.TTF", 10)
	ignoreSubtitle:SetText("If unchecked, the key will not perform its usual action when trying to complete an uncompleted quest")
	ignoreSubtitle:SetPoint("TOPLEFT", ignoreCheckbox, "BOTTOMLEFT", 4, -2)
	
	local glowCheckbox = CreateFrame("CheckButton", "DialogKeyOptGlow", self.options, "UICheckButtonTemplate")
	glowCheckbox:SetPoint("TOPLEFT", ignoreCheckbox, "BOTTOMLEFT", 0, -30)
	_G["DialogKeyOptGlowText"]:SetText("Show glow on clicked buttons")
	glowCheckbox:SetScript("OnShow", function(self) self:SetChecked(DialogKey.db.global.showGlow) end)
	glowCheckbox:SetScript("OnClick", function(self) DialogKey.db.global.showGlow = self:GetChecked() end)
	glowCheckbox:SetChecked(DialogKey.db.global.showGlow)
	
	local glowSubtitle = glowCheckbox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	glowSubtitle:SetFont("Fonts\\FRIZQT__.TTF", 10)
	glowSubtitle:SetText("Shows a glow around everything the addon clicks on")
	glowSubtitle:SetPoint("TOPLEFT", glowCheckbox, "BOTTOMLEFT", 4, -2)
	
	local additionalScroll = CreateFrame("ScrollFrame", "DialogKeyScrollFrame", self.options, "InputScrollFrameTemplate")
	additionalScroll:SetSize(300,150)
	additionalScroll:SetPoint("TOPLEFT", glowCheckbox, "BOTTOMLEFT", 9, -50)
	additionalScroll.CharCount:Hide()
	self.options.additionalScroll = additionalScroll
	
	local newvalue = table.concat(self.db.global.additionalButtons, "\n")
	additionalScroll.EditBox.previousText = newvalue
	additionalScroll.EditBox:SetText(newvalue)
	additionalScroll.EditBox:SetMaxLetters(0)
	additionalScroll.EditBox:SetWidth(additionalScroll:GetWidth())
	additionalScroll.EditBox:Enable()
	additionalScroll.EditBox:SetFont("Fonts\\ARIALN.TTF", 16)
	
	additionalScroll.EditBox:SetScript("OnEnterPressed", nil)
	
	additionalScroll.EditBox:SetScript("OnTextChanged", function(self)
		if self.previousText ~= self:GetText() then
			DialogKey.options.additionalSave:Show()
		end
		
		self.previousText = self:GetText()
	end)
	
	local additionalSave = CreateFrame("Button", nil, self.options, "UIPanelButtonTemplate")
	additionalSave:SetPoint("TOPRIGHT", self.options.additionalScroll, "BOTTOMRIGHT", 7,-4)
	additionalSave:SetWidth(50)
	additionalSave:SetHeight(20)
	additionalSave:SetText("Save")
	additionalSave:SetScript("OnClick", DialogKey.SaveAdditionalButtons)
	additionalSave:Hide()
	self.options.additionalSave = additionalSave
	
	local additionalTitle = self.options:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	additionalTitle:SetFont("Fonts\\FRIZQT__.TTF", 12)
	additionalTitle:SetTextColor(1,1,1,1)
	additionalTitle:SetJustifyH("LEFT")
	additionalTitle:SetText("Additional buttons to click")
	additionalTitle:SetPoint("BOTTOMLEFT", self.options.additionalScroll, "TOPLEFT", -4, 6)
	
	local additionalExplanation = self.options:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	additionalExplanation:SetFont("Fonts\\FRIZQT__.TTF", 10)
	additionalExplanation:SetTextColor(1,1,1,1)
	additionalExplanation:SetJustifyH("LEFT")
	additionalExplanation:SetWordWrap(true)
	additionalExplanation:SetWidth(500)
	additionalExplanation:SetText("Type a button's name here to track it. DialogKeys will attempt to click on any tracked buttons when you hit the bound key. Note: not all buttons can be tracked.\n\nTo track a new button, hover over it and type |cffffff00/dialogkey add|r\nTo untrack a button, hover over it and type |cffffff00/dialogkey remove|r")
	additionalExplanation:SetPoint("TOPLEFT", self.options.additionalScroll, "BOTTOMLEFT", -4, -30)
	
	self.options.name = "DialogKey"
	InterfaceOptions_AddCategory(self.options)
end

function DialogKey:ShowOldKeybindWarning()	-- Shows a popup warning the user that they've got old VEK binds
	if not self.db.global.shownBindWarning then
		self.db.global.shownBindWarning = true
		
		local key1 = GetBindingKey("ACCEPTDIALOG")
		local key2 = GetBindingKey("ACCEPTDIALOG_CHAT")
		
		-- Treat only having the second key bound as only having the first key bound for simplicity
		if key2 and not key1 then
			key1 = key2
			key2 = nil
		end
		
		local str
		if key1 then
			if key2 then
				str = "DialogKey is a replacement of Versatile Enter Key, which is now obsolete.\n\nYour '" .. GetBindingText(key1) .. "' and '" .. GetBindingText(key2) .. "' keys are still bound to Versatile Enter Key actions. You should rebind them to their original actions if they were originally bound to something important!"
			else
				str = "DialogKey is a replacement of Versatile Enter Key, which is now obsolete.\n\nYour '" .. GetBindingText(key1) .. "' key is still bound to a Versatile Enter Key action. You should rebind it to its original action if it was originally bound to something important!"
			end
		end
		
		if str then
			StaticPopupDialogs["DIALOGKEY_OLDBINDWARNING"] = {
				text = str,
				button1 = "Open Keybinds",
				button2 = OKAY,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				
				OnAccept = function()
					KeyBindingFrame_LoadUI()
					ShowUIPanel(KeyBindingFrame)
				end
			}
			StaticPopup_Show("DIALOGKEY_OLDBINDWARNING")
		end
	end
end

function DialogKey:GlowFrameUpdate(delta)	-- Fades out the glow frame
	-- Use delta (time since last frame) so animation takes same amount of time regardless of framerate
	self:SetAlpha(self:GetAlpha() - delta*3)
	if self:GetAlpha() <= 0 then self:Hide() end
end

-- Chat handlers --
function DialogKey:AddMouseFocus()			-- Adds the button under the cursor to the list of additional buttons to click
	local frame = GetMouseFocus()
	if not frame or frame:GetObjectType() ~= "Button" then
		print("The cursor must be over a button to track it")
		return
	end
	
	if not frame:GetName() then
		print("That button cannot be tracked")
		return
	end
	
	self:WatchFrame(frame:GetName())
end

function DialogKey:RemoveMouseFocus()		-- Removes the button under the cursor from the list of additional buttons to click
	local frame = GetMouseFocus()
	if not frame or frame:GetObjectType() ~= "Button" then
		print("The cursor must be over a button to untrack it")
		return
	end
	
	if not frame:GetName() then
		print("That button is not being tracked")
		return
	end
	
	self:UnwatchFrame(frame:GetName())
end

function DialogKey:WatchFrame(name)			-- Add given frame to the watch list
	tinsert(self.db.global.additionalButtons, name)
	print("Started tracking '" .. name .. "'")
	
	local frame = _G[name]
	if frame and frame:IsVisible() then
		self:Glow(frame, "add")
	end
	
	self:UpdateAdditionalFrames()
end

function DialogKey:UnwatchFrame(name)		-- Remove given frame from the watch list
	local removed = false
	for i,watchedframe in pairs(self.db.global.additionalButtons) do
		if watchedframe == name then
			removed = true
			tremove(self.db.global.additionalButtons, i)
		end
	end
	
	if removed then
		print("Stopped tracking '" .. name .. "'")
	else
		print("'" .. name .. "' is not being tracked")
	end
	
	local frame = _G[name]
	if frame and frame:IsVisible() then
		self:Glow(frame, "remove")
	end
	
	self:UpdateAdditionalFrames()
end

-- Primary functions --
function DialogKey:HandleKey(key)			-- Run for every key hit ever; runs ClickButtons() if it's the bound one
	if DialogKey.keybindMode then
		DialogKey:HandleKeybind(key)
		return
	end
	
	if key == DialogKey.db.global.keys[1] or key == DialogKey.db.global.keys[2] then
		local success = DialogKey:ClickButtons()
		self:SetPropagateKeyboardInput(not success)
	else
		self:SetPropagateKeyboardInput(true)
	end
end

function DialogKey:ClickButtons()			-- Main function to click on dialog buttons when the bound key is pressed
	-- If we're typing into an editbox, don't do anything
	if GetCurrentKeyBoardFocus() then
		return
	end
	
	for i,frame in pairs(buttons) do
		if self:ClickButton(frame) then
			return true
		end
	end
	
	for i,frameName in pairs(self.db.global.additionalButtons) do
		local frame = _G[frameName]
		if frame and self:ClickButton(frame) then
			return true
		end
	end
end

function DialogKey:ClickButton(frame)		-- Helper of ClickButtons, attempts to click the given button
	if frame:IsVisible() and (not self.db.global.ignoreDisabledButtons or (self.db.global.ignoreDisabledButtons and frame:IsEnabled())) then
		self:Glow(frame, "click")
		frame:Click()
		return true
	end
end

function DialogKey:Glow(frame, mode)		-- Show the glow frame over a frame. Mode is "click", "add", or "remove"
	if mode == "click" then
		if DialogKey.db.global.showGlow then
			self.glowFrame:SetAllPoints(frame)
			self.glowFrame.tex:SetTexture(1,1,0,0.5)
			self.glowFrame:Show()
			self.glowFrame:SetAlpha(1)
		end
	elseif mode == "add" then
		self.glowFrame:SetAllPoints(frame)
		self.glowFrame.tex:SetTexture(0,1,0,0.5)
		self.glowFrame:Show()
		self.glowFrame:SetAlpha(1)
	elseif mode == "remove" then
		self.glowFrame:SetAllPoints(frame)
		self.glowFrame.tex:SetTexture(1,0,0,0.5)
		self.glowFrame:Show()
		self.glowFrame:SetAlpha(1)
	end
end

-- Binding mode --
function DialogKey:EnableKeybindMode(index)	-- Enables keybinding mode in the options frame
	self.options.additionalScroll.EditBox:ClearFocus()
	
	if self.keybindMode then
		return
	end
	
	-- Disable all other keybind buttons
	for i,button in pairs(self.options.keybindButtons) do
		if i ~= index then
			button:Disable()
		end
	end
	
	self.keybindMode = true
	self.keybindIndex = index
	self.options.keybindReminder:Show()
	self.frame:SetPropagateKeyboardInput(false)
end

function DialogKey:DisableKeybindMode()		-- Disables keybinding mode in the options frame
	DialogKey.keybindMode = false
	DialogKey.options.keybindReminder:Hide()
	
	-- Enable all keybind buttons
	for i,button in pairs(DialogKey.options.keybindButtons) do
		button:Enable()
	end
	
	DialogKey.timer = DialogKey:ScheduleTimer(function()
		DialogKey.frame:SetPropagateKeyboardInput(true)
	end, 0.1)
end

function DialogKey:HandleKeybind(key)		-- Run for a keypress during binding mode; saves that key as the bound one
	self.options.keybindButtons[self.keybindIndex]:SetText(GetBindingText(key))
	self.db.global.keys[self.keybindIndex] = key
	self:DisableKeybindMode()
	
	-- Clear this assignment from other options so you don't have both options set to SPACE or whatever; not necessary, but clean
	for i,thiskey in pairs(self.db.global.keys) do
		if i ~= self.keybindIndex and thiskey == key then
			self.db.global.keys[i] = nil
			self.options.keybindButtons[i]:SetText("")
		end
	end
end

function DialogKey:ClearBind(index)			-- Clears the keybind from the given binding button
	DialogKey.db.global.keys[index] = nil
	DialogKey.options.keybindButtons[index]:SetText("")
end

-- Options frame helpers --
function DialogKey:SaveAdditionalButtons()	-- Save the button names in the additional input to the saved settings
	self:Hide()
	local editbox = DialogKey.options.additionalScroll.EditBox
	editbox:ClearFocus()
	
	local final = {}
	for i,name in pairs({strsplit("\n",editbox:GetText())}) do
		name = strtrim(name)
		if name:len() > 0 then
			tinsert(final, name)
		end
	end
	
	DialogKey.db.global.additionalButtons = final
end

function DialogKey:UpdateAdditionalFrames()	-- Updates the "Additional buttons" textbox with the latest settings
	local editbox = self.options.additionalScroll.EditBox
	local newvalue = table.concat(self.db.global.additionalButtons, "\n")
	editbox.previousText = newvalue
	editbox:SetText(newvalue)
end
