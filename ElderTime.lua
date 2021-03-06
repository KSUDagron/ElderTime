-----------------------------------------------------------------------------------------------
-- Client Lua Script for ElderTime
-- Copyright (c) KSUDagron on Curse.com
-----------------------------------------------------------------------------------------------
 
require "Window"
require "Apollo"
require "GameLib"
 
local ElderTime = {}
local ElderTimeInst = nil
local tTimeLoc_Default = {
	["left"] = 50,
	["top"] = -20,
	["right"] = 93,
	["bottom"] = 0
}
local tTimeLoc_Shifted = {
	["left"] = 50,
	["top"] = -20,
	["right"] = 110,
	["bottom"] = 0
}
local tButtonLoc_Default = {
	["left"] = 93,
	["top"] = -26,
	["right"] = -81,
	["bottom"] = 12
}
local tButtonLoc_Shifted = {
	["left"] = 110,
	["top"] = -26,
	["right"] = -81,
	["bottom"] = 12
}
local aInterfaceMenuList = nil
local fOnUpdateTime = nil
 
function ElderTime:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	self.source = 1
	self.format = 1
	self.showAMPM = false
	self.location = { 200, 200, 565, 450 }

    return o
end

function ElderTime:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = { "InterfaceMenuList" }
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 
function ElderTime:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ElderTime.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

function ElderTime:OnSave(saveDepth)
	if saveDepth ~= GameLib.CodeEnumAddonSaveLevel.Character then return nil end
	
	local savedVariables = {}
	savedVariables.source = self.source
	savedVariables.format = self.format
	savedVariables.showAMPM = self.showAMPM
	
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	savedVariables.location = { nLeft, nTop, nRight, nBottom }
		
	return savedVariables
end

function ElderTime:OnRestore(saveDepth, savedVariables)
	if saveDepth ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	if savedVariables == {} or savedVariables == nil then return end
	
	if savedVariables.source ~= nil then self.source = savedVariables.source end
	if savedVariables.format ~= nil then self.format = savedVariables.format end
	if savedVariables.showAMPM ~= nil then self.showAMPM = savedVariables.showAMPM end
	if savedVariables.location ~= nil then self.location = savedVariables.location end
end

function ElderTime:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "ElderTimeForm", nil, self)
		self.wndContext = Apollo.LoadForm(self.xmlDoc, "ElderTimeContextMenu", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "[ElderTime]: Could not load the main window for some reason.")
			return
		end
		if self.wndContext == nil then
			Apollo.AddAddonErrorText(self, "[ElderTime]: Could not load the context menu window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)
		self.wndContext:Show(false, true)
	
		Apollo.RegisterSlashCommand("eldertime", "OnElderTimeOn", self)

		aInterfaceMenuList = Apollo.GetAddon("InterfaceMenuList")
		if not aInterfaceMenuList then
			Print("[ElderTime]: Could not find Carbine InterfaceMenuList. ElderTime will be disabled!")
			return
		end
		
		if not aInterfaceMenuList.wndMain then RequestReloadUI() end
		
		fOnUpdateTimer = aInterfaceMenuList.OnUpdateTimer
		aInterfaceMenuList.OnUpdateTimer = ElderTime.OnUpdateTimerHook
		aInterfaceMenuList.wndMain:FindChild("Time"):AddEventHandler("MouseButtonDown", "ElderTime_OnTimeClick")
		aInterfaceMenuList.ElderTime_OnTimeClick = ElderTime.OnTimeClick
		
		self.wndMain:FindChild("SourceOptions"):SetRadioSel("ElderTime_Source", self.source)
		self.wndMain:FindChild("FormatOptions"):SetRadioSel("ElderTime_Format", self.format)
		if self.showAMPM then
			self.wndMain:FindChild("FormatOptions"):SetRadioSel("ElderTime_Format_AMPM", 1)
		end
		self.wndMain:SetAnchorOffsets(unpack(self.location))
		
		self.wndContext:SetRadioSel("ElderTime_ContextMenu", self.source)
	end
end

function ElderTime:OnElderTimeOn()
	self.wndMain:Invoke()
end

-----------------------------------------------------------------------------------------------
-- ElderTimeForm Functions
-----------------------------------------------------------------------------------------------
function ElderTime.OnUpdateTimerHook(self)
	--Call original OnUpdateTimer in InterfaceMenuList
	fOnUpdateTimer(self)
	
	--ElderTime code to modify time display
	local tTimeLoc = tTimeLoc_Default
	local tButtonLoc = tButtonLoc_Default

	local tTime = nil
	if ElderTimeInst.source == 1 then
		tTime = GameLib.GetLocalTime()
	elseif ElderTimeInst.source == 2 then
		tTime = GameLib.GetServerTime()
	elseif ElderTimeInst.source == 3 then
		local nTime = GameLib.GetWorldTimeOfDay()
		local nHour = math.floor(nTime / 3600)
		local nMinute = math.floor((nTime % 3600) / 60)
		tTime = {
			["nHour"] = nHour,
			["nMinute"] = nMinute
		}
	else
		tTime = nil
	end
	
	local sTime = "--"
	if tTime then
		if ElderTimeInst.format == 1 then
			sTime = string.format("%02d:%02d", tostring(tTime.nHour), tostring(tTime.nMinute))
		elseif ElderTimeInst.format == 2 then
			local nHour = tTime.nHour
			if nHour == 0 then
				nHour = 12
			elseif nHour > 12 then
				nHour = nHour - 12
			end
			sTime = string.format("%2d:%02d", tostring(nHour), tostring(tTime.nMinute))
		else
			sTime = "--"
		end
	end
	
	local sAMPM = ""
	if tTime and ElderTimeInst.showAMPM then
		if tTime.nHour > 12 then
			sAMPM = " PM"
		else
			sAMPM = " AM"
		end
		tTimeLoc = tTimeLoc_Shifted
		tButtonLoc = tButtonLoc_Shifted
	else
		sAMPM = ""
		tTimeLoc = tTimeLoc_Default
		tButtonLoc = tButtonLoc_Default
	end
	
	self.wndMain:FindChild("Time"):SetText(string.format("%s%s", sTime, sAMPM))
	self.wndMain:FindChild("Time"):SetAnchorOffsets(tTimeLoc["left"], tTimeLoc["top"], tTimeLoc["right"], tTimeLoc["bottom"])
	self.wndMain:FindChild("ButtonList"):SetAnchorOffsets(tButtonLoc["left"], tButtonLoc["top"], tButtonLoc["right"], tButtonLoc["bottom"])
end

function ElderTime:OnChangeSource(wndHandler, wndControl, eMouseButton)
	if wndHandler:GetParent() == self.wndMain:FindChild("SourceOptions") then
		self.source = wndHandler:GetParent():GetRadioSel("ElderTime_Source")
		self.wndContext:SetRadioSel("ElderTime_ContextMenu", self.source)
	elseif wndHandler:GetParent() == self.wndContext then
		self.source = wndHandler:GetParent():GetRadioSel("ElderTime_ContextMenu")
		self.wndMain:FindChild("SourceOptions"):SetRadioSel("ElderTime_Source", self.source)
		self.wndContext:Close()
	end
	aInterfaceMenuList.OnUpdateTimer(aInterfaceMenuList)
end

function ElderTime:OnChangeFormat(wndHandler, wndControl, eMouseButton)
	local wAMPM = wndHandler:GetParent():FindChild("Format_AMPM")
	self.format = wndHandler:GetParent():GetRadioSel("ElderTime_Format")
	
	if self.format == 2 then
		wAMPM:Enable(true)
		wAMPM:SetTextColor(CColor.new(1, 1, 1, 1))
	else
		wAMPM:SetTextColor(CColor.new(168/255, 168/255, 168/255, 1))
		wAMPM:Enable(false)
	end
	
	if wAMPM:IsEnabled() then
		local nAMPM = wndHandler:GetParent():GetRadioSel("ElderTime_Format_AMPM")
		if nAMPM == 1 then
			self.showAMPM = true
		else
			self.showAMPM = false
		end
	else
		self.showAMPM = false
	end
	
	aInterfaceMenuList.OnUpdateTimer(aInterfaceMenuList)
end

function ElderTime.OnTimeClick(self, wndHandler, wndControl, eMouseButton)
	if eMouseButton == 1 then
		local tMousePos = Apollo.GetMouse()
		local tWndPos = { tMousePos.x, tMousePos.y - 116, tMousePos.x + 115, tMousePos.y }
		ElderTimeInst.wndContext:SetAnchorOffsets(unpack(tWndPos))
		ElderTimeInst.wndContext:Invoke()
	end
end

function ElderTime:OnConfiguationSave(wndHandler, wndControl, eMouseButton)
	self.wndMain:Close()
end

function ElderTime:OnOpenConfiguration(wndHandler, wndControl, eMouseButton)
	self.wndMain:Invoke()
	self.wndContext:Close()
end

ElderTimeInst = ElderTime:new()
ElderTimeInst:Init()

