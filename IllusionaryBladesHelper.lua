-----------------------------------------------------------------------------------------------
-- Client Lua Script for IllusionaryBladesHelper
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "Spell"
require "GameLib"
require "ActionSetLib"
require "AbilityBook"
require "Tooltip"
 
-----------------------------------------------------------------------------------------------
-- IllusionaryBladesHelper Module Definition
-----------------------------------------------------------------------------------------------
local IllusionaryBladesHelper = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function IllusionaryBladesHelper:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function IllusionaryBladesHelper:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- IllusionaryBladesHelper OnLoad
-----------------------------------------------------------------------------------------------

function IllusionaryBladesHelper:OnLoad()
	if GameLib.GetPlayerUnit() == nil then RequestReloadUI() end -- if it couldn't fetch player data, it requests a reloads ui
	if GameLib.GetPlayerUnit():GetClassId() ~= GameLib.CodeEnumClass.Esper then return end -- If you're not esper, do nothing
	-- register handlers
	Apollo.RegisterEventHandler("UnitEnteredCombat", "OnUnitEnteredCombat", self)
	Apollo.RegisterEventHandler("AbilityBookChange", "OnAbilityBookChange", self)
	-- set timer
	self.timerInterval=0.1
	self.timer = ApolloTimer.Create(self.timerInterval, true, "OnRefresh", self)
	self.timer:Stop()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("IllusionaryBladesHelper.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- IllusionaryBladesHelper OnDocLoaded
-----------------------------------------------------------------------------------------------
function IllusionaryBladesHelper:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "IllusionaryBladesHelperForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)
		
		self.wndWidget = Apollo.LoadForm(self.xmlDoc, "IllusionaryBladesWidget", nil, self)
		if self.wndWidget == nil then
			Apollo.AddAddonErrorText(self, "Could not load the widget window for some reason")
			return
		end
		self.wndWidget:Show(false, true)
		self:checkSpellIsPresent()
		
		self.wndWarning = Apollo.LoadForm(self.xmlDoc, "IllusionaryBladesWarnings", nil, self)
		if self.wndWarning == nil then
			Apollo.AddAddonErrorText(self, "Could not load the Warning Window for some reason")
			return
		end
		self.wndWarning:Show(false, true)
		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("ibhelp", "OnIllusionaryBladesHelperOn", self)

		-- initialize a bunch of variables to reduce calls later on
		self.checkBoxes = {}
		self.checkBoxes[1] = self.wndMain:FindChild("buttonWarning")
		self.checkBoxes[2] = self.wndMain:FindChild("buttonFlash")
		self.checkBoxes[3] = self.wndMain:FindChild("buttonSounds")
		
		self.iconSizeBox = self.wndMain:FindChild("iconSizeBox")
		self.timerIntervalBox = self.wndMain:FindChild("timerIntervalBox")
		self.textStack = self.wndWidget:FindChild("textStack")
		self.textCD = self.wndWidget:FindChild("textCD")
		self.warningCD = self.wndWarning:FindChild("warningCD")
		self.warningStack = self.wndWarning:FindChild("warningStack")
		
		self.shouldPlaySound=0
		-- Default settings for various things
		self:setDefaultSettings()

		-- Change settings based on saved data
		self:restoreSettings()

		-- Initialize an useful vector Buttons that holds the value of the checkbox
		self.Buttons = {}
		self.Buttons[1] = self.checkBoxes[1]:IsChecked()
		self.Buttons[2] = self.checkBoxes[2]:IsChecked()
		self.Buttons[3] = self.checkBoxes[3]:IsChecked()
		-- Populate combo box to choose widget icon size

		self.iconSizeBox:AddItem("72", "72")
		self.iconSizeBox:AddItem("64", "64")
		self.iconSizeBox:AddItem("48", "48")
		self.iconSizeBox:AddItem("32", "32")
		-- Populate combo box to choose  timer interval
		self.timerIntervalBox:AddItem("0.5", "0.5")
		self.timerIntervalBox:AddItem("0.33", "0.33")
		self.timerIntervalBox:AddItem("0.2", "0.2")
		self.timerIntervalBox:AddItem("0.1", "0.1")
		--self:fillOptionsWindow()		


		-- Do additional Addon initialization here
	end
end

-----------------------------------------------------------------------------------------------
-- IllusionaryBladesHelper Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/ibhelp"
function IllusionaryBladesHelper:OnIllusionaryBladesHelperOn()
	self.wndMain:Invoke() -- show the options window
end

function IllusionaryBladesHelper:FillOptionsWindow()
	if self.Buttons == nil then 
		self.Buttons = {}
		self.Buttons[1] = self.checkBoxes[1]:IsChecked()
		self.Buttons[2] = self.checkBoxes[2]:IsChecked()
	end
	

	self.checkBoxes[1]:SetCheck(self.Buttons[1])
	self.checkBoxes[2]:SetCheck(self.Buttons[2])
end

function IllusionaryBladesHelper:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	local iLeft, iTop, iRight, iBottom=self.wndWidget:GetAnchorOffsets()
	local wLeft, wTop, wRight, wBottom=self.wndWarning:GetAnchorOffsets()
	local tsave = {}
	tsave.Buttons = {}
	tsave.Buttons[1] = self.Buttons[1]
	tsave.Buttons[2] = self.Buttons[2]
	tsave.Buttons[3] = self.Buttons[3]
	tsave.iconOffsets = {}
	tsave.iconOffsets[1] = iLeft
	tsave.iconOffsets[2] = iTop
	tsave.iconOffsets[3] = iRight
	tsave.iconOffsets[4] = iBottom
	tsave.warningOffsets = {}
	tsave.warningOffsets[1] = wLeft
	tsave.warningOffsets[2] = wTop
	tsave.warningOffsets[3] = wRight
	tsave.warningOffsets[4] = wBottom
	tsave.timerInterval = {}
	tsave.timerInterval[1] =tonumber(self.timerIntervalBox:GetText())
	
	return tsave
end

function IllusionaryBladesHelper:OnRestore(eLevel, saveData)
	-- Just a common restore function
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return end

	self.tSavedData = saveData
end

function IllusionaryBladesHelper:UpdateSettings()
	--I update the value of Buttons after I've pressed OK
	self.Buttons[1] = self.checkBoxes[1]:IsChecked()
	self.Buttons[2] = self.checkBoxes[2]:IsChecked()
	self.Buttons[3] = self.checkBoxes[3]:IsChecked()
	-- Updating iconsize
	local iSize= tonumber(self.iconSizeBox:GetText())
	local iLeft, iTop, iRight, iBottom=self.wndWidget:GetAnchorOffsets()
	iLeft=iRight - iSize -4
	iTop =iBottom - iSize  -4
	self.wndWidget:SetAnchorOffsets(iLeft,iTop,iRight,iBottom)
	self.textStack:SetAnchorOffsets(iSize-12,iSize-18,iSize+2,iSize+2)
	self.timer = ApolloTimer.Create(self.timerInterval, true, "OnRefresh", self)
	self.timer:Stop()
end

function IllusionaryBladesHelper:setDefaultSettings()
	self.checkBoxes[1]:SetCheck(true)
	self.checkBoxes[2]:SetCheck(true)
	self.checkBoxes[3]:SetCheck(true)
	self.wndWidget:SetAnchorOffsets(806,580,882,656)
	self.wndWarning:SetAnchorOffsets(404,43,904,243)
	self.iconSizeBox:SetText("72")
	self.timerIntervalBox:SetText("0.1")
end

function IllusionaryBladesHelper:restoreSettings()
	local iLeft,iTop,iRight,iBottom
	local wLeft,wTop,wRight,wBottom
	if self.tSavedData ~= nil then
		if self.tSavedData["Buttons"] ~= nil and self.tSavedData["Buttons"][1] ~= nil then
			self.checkBoxes[1]:SetCheck(self.tSavedData["Buttons"][1])
			
		end
		if self.tSavedData["Buttons"] ~= nil and self.tSavedData["Buttons"][2] ~= nil then
			self.checkBoxes[2]:SetCheck(self.tSavedData["Buttons"][2])
		end
		if self.tSavedData["Buttons"] ~= nil and self.tSavedData["Buttons"][3] ~= nil then
			self.checkBoxes[3]:SetCheck(self.tSavedData["Buttons"][3])
		end
		if self.tSavedData["iconOffsets"] ~= nil and self.tSavedData["iconOffsets"][1] ~= nil then
			iLeft=self.tSavedData["iconOffsets"][1]
		end
		if self.tSavedData["iconOffsets"] ~= nil and self.tSavedData["iconOffsets"][2] ~= nil then
			iTop=self.tSavedData["iconOffsets"][2]
		end
		if self.tSavedData["iconOffsets"] ~= nil and self.tSavedData["iconOffsets"][3] ~= nil then
			iRight=self.tSavedData["iconOffsets"][3]
		end
		if self.tSavedData["iconOffsets"] ~= nil and self.tSavedData["iconOffsets"][4] ~= nil then
			iBottom=self.tSavedData["iconOffsets"][4]
		end
		if iLeft ~= nil and iTop ~= nil and iRight ~= nil and iBottom ~= nil then
			self.wndWidget:SetAnchorOffsets(iLeft,iTop,iRight,iBottom)
			local iSize = iRight-iLeft -4
			self.iconSizeBox:SetText(tostring(iSize))
			self.textStack:SetAnchorOffsets(iSize-12,iSize-18,iSize+2,iSize+2)
		end
		if self.tSavedData["warningOffsets"] ~= nil and self.tSavedData["warningOffsets"][1] ~= nil then
			wLeft=self.tSavedData["warningOffsets"][1]
		end
		if self.tSavedData["warningOffsets"] ~= nil and self.tSavedData["warningOffsets"][2] ~= nil then
			wTop=self.tSavedData["warningOffsets"][2]
		end
		if self.tSavedData["warningOffsets"] ~= nil and self.tSavedData["warningOffsets"][3] ~= nil then
			wRight=self.tSavedData["warningOffsets"][3]
		end
		if self.tSavedData["warningOffsets"] ~= nil and self.tSavedData["warningOffsets"][4] ~= nil then
			wBottom=self.tSavedData["warningOffsets"][4]
		end
		if wLeft ~= nil and wTop ~= nil and wRight ~= nil and wBottom ~= nil then
			self.wndWarning:SetAnchorOffsets(wLeft,wTop,wRight,wBottom)
		end
		if self.tSavedData["timerInterval"] ~= nil and self.tSavedData["timerInterval"][1] ~= nil then
			self.timerInterval = self.tSavedData["timerInterval"][1]
			self.timer = ApolloTimer.Create(self.timerInterval, true, "OnRefresh", self)
			self.timer:Stop()
			self.timerIntervalBox:SetText(tostring(self.timerInterval))
		end
			
	end
end

function IllusionaryBladesHelper:OnRefresh()
	local player = GameLib.GetPlayerUnit()
	if player ~= nil then
		local buffs=player:GetBuffs()
		if buffs ~= nil then
			self:AnalizeBuffs(buffs)
		end
	end
end

function IllusionaryBladesHelper:OnUnitEnteredCombat(unit, bInCombat)
	if unit and unit:IsValid() and unit:IsThePlayer() then
		if bInCombat and self:checkSpellIsPresent()==1 then
			self.timer:Start()
		else
			self.timer:Stop()
			self.textStack:SetTextColor("white")
			self.textStack:SetText("")
			self.textCD:SetTextColor("white")
			self.textCD:SetText("")
			self.wndWarning:Show(false)
		end
	end
end

function IllusionaryBladesHelper:AnalizeBuffs(buffs)
	local i=0
	local j=0
	for key, buff in ipairs(buffs.arBeneficial) do
		if(buff.splEffect:GetId()==83137) then
			i = 1
			if buff["nCount"]==5 then
				self.textStack:SetTextColor("blue")
			
			elseif buff["nCount"]==1 then
				self.textStack:SetTextColor("red")
			else
				self.textStack:SetTextColor("white")
			end
			self.textStack:SetText(tostring(buff["nCount"]))
		end
		if(buff.splEffect:GetId()==83557) then
			if buff["fTimeRemaining"]<3.8 then
				self.textCD:SetTextColor("red")
				if self.Buttons[1] then
					if self.Buttons[3] and self.shouldPlaySound == 0 then
						Sound.Play(214)
						Sound.Play(216)
						self.shouldPlaySound = 1
					end
					self:ShowWarning(buff["fTimeRemaining"])
				end
			else
				self.shouldPlaySound = 0
				self.textCD:SetTextColor("white")
				self.wndWarning:Show(false)
			end
			self.textCD:SetText(("%.f"):format(buff["fTimeRemaining"]))
		end	
	end
	if(i==0) then
		self.textStack:SetTextColor("red")
		self.textStack:SetText("0")
	end
end

function IllusionaryBladesHelper:ShowWarning(timeRemaining)
	self.warningCD:SetTextColor("white")
	self.warningCD:SetText("Illusions expiring in "..("%.1f"):format(timeRemaining))
	if timeRemaining<0.6 then
		self.warningCD:SetTextColor("red")
		self.warningCD:SetText("Illusions EXPIRING NOW!!!")
	end
	self.wndWarning:Show(true)
end

function IllusionaryBladesHelper:checkSpellIsPresent()
	local abilitiesList = AbilityBook.GetAbilitiesList()
	if abilitiesList ~= nil then
		for key, ability in ipairs(abilitiesList) do
			if ability.bIsActive and ability.strName == "Illusionary Blades" and ability.nCurrentTier > 1 then
				self.wndWidget:Show(true)
				return 1
			end
		end
		self.wndWidget:Show(false)
		return 0
	end
end

function IllusionaryBladesHelper:OnAbilityBookChange()
	self:checkSpellIsPresent()
end
-----------------------------------------------------------------------------------------------
-- IllusionaryBladesHelperForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function IllusionaryBladesHelper:OnOK()
	self.wndMain:Close() --hide the windows
	self:UpdateSettings() -- hide the window
end

-- when the Cancel button is clicked
function IllusionaryBladesHelper:OnCancel()
	self.wndMain:Close()-- hide the window
	self.wndMain:FindChild("buttonMvWarning"):SetText("Done Moving") --resets button setting just in case
	self:buttonWarningClick() -- hides shit
	self:restoreSettings() -- undo settings
end

function IllusionaryBladesHelper:buttonWarningOnCheck()
	--local test = tostring(self.wndMain:FindChild("buttonWarning"):IsChecked())
	--Print(test)
end

function IllusionaryBladesHelper:buttonWarningOnUncheck()
	
end

function IllusionaryBladesHelper:buttonFlashOnCheck()

end

function IllusionaryBladesHelper:buttonFlashOnUncheck()

end
function IllusionaryBladesHelper:buttonSoundsOnCheck()

end

function IllusionaryBladesHelper:buttonSoundsOnUncheck()

end
function IllusionaryBladesHelper:buttonWarningClick()
	if self.wndMain:FindChild("buttonMvWarning"):GetText()=="Move Warnings" then
		
		self.wndWarning:Show(true)
		self.wndWarning:SetStyle("Moveable",1)
		self.wndWarning:SetStyle("Picture",1)
		--self.wndWarning:SetStyle("Sizeable",1)
		self.warningCD:SetTextColor("white")
		self.warningCD:SetText("Remember to save by pressing OK")
		self.warningStack:SetText("Second Warning bar")
		
		self.wndMain:FindChild("buttonMvWarning"):SetText("Done Moving")
		return
	end
	if self.wndMain:FindChild("buttonMvWarning"):GetText()=="Done Moving" then
		self.wndWarning:Show(false)
		self.wndWarning:RemoveStyle("Moveable")
		self.wndWarning:RemoveStyle("Picture")
		--self.wndWarning:RemoveStyle("Sizeable")
		self.warningCD:SetText("")
		self.warningStack:SetText("")
		self.wndMain:FindChild("buttonMvWarning"):SetText("Move Warnings")
		return
	end

end



-----------------------------------------------------------------------------------------------
-- IllusionaryBladesHelper Instance
-----------------------------------------------------------------------------------------------
local IllusionaryBladesHelperInst = IllusionaryBladesHelper:new()
IllusionaryBladesHelperInst:Init()
