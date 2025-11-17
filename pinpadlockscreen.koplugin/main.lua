--[[
Author: Lena2309 (better lock management, boot hooking, event listening, ...), yogi81 (original inspiration and main skeleton)
Inspiration and original skeleton from `https://github.com/yogi81/screenlock_koreader_plugin/tree/main`
Description: implements a screen lock mechanism for KOReader
using a PIN pad interface. Also adds a menu entry in Settings -> Screen
]]

local Dispatcher = require("dispatcher")
local PinPadDialog = require("ui/pinpaddialog")
local EventListener = require("ui/widget/eventlistener")
local _ = require("gettext")
local UIManager = require("ui/uimanager")
local MenuEntryItems = require("menu/menuentryitems")

local LoggerFactory = require("logger")
local log = (type(LoggerFactory) == "function" and LoggerFactory("FolderCover"))
    or (LoggerFactory and LoggerFactory.new and LoggerFactory:new("FolderCover"))
    or { dbg = function() end, info = print, warn = print, err = print }

-- Default settings
if G_reader_settings:hasNot("pinpadlock_pin_code") then
    G_reader_settings:saveSetting("pinpadlock_pin_code", "1234")
end
if G_reader_settings:hasNot("pinpadlock_activated") then
    G_reader_settings:makeFalse("pinpadlock_activated")
end
if G_reader_settings:hasNot("pinpadlock_correct_pin_message_activated") then
    G_reader_settings:makeTrue("pinpadlock_correct_pin_message_activated")
end
if G_reader_settings:hasNot("pinpadlock_timeout_time") then
    G_reader_settings:saveSetting("pinpadlock_timeout_time", "30")
end
if G_reader_settings:hasNot("pinpadlock_max_tries") then
    G_reader_settings:saveSetting("pinpadlock_max_tries", "3")
end
if G_reader_settings:hasNot("pinpadlock_show_message") then
    G_reader_settings:makeFalse("pinpadlock_show_message")
end
if G_reader_settings:hasNot("pinpadlock_message") then
    G_reader_settings:saveSetting("pinpadlock_message", "Locked")
end
if G_reader_settings:hasNot("pinpadlock_message_position") then
    G_reader_settings:saveSetting("pinpadlock_message_position", "top")
end
if G_reader_settings:hasNot("pinpadlock_message_alignment") then
    G_reader_settings:saveSetting("pinpadlock_message_alignment", "center")
end
if G_reader_settings:hasNot("suspended_device") then
    G_reader_settings:makeTrue("suspended_device")
end

local ScreenLock = EventListener:extend {}

------------------------------------------------------------------------------
--- REGISTER DISPATCHER ACTIONS
------------------------------------------------------------------------------
function ScreenLock:onDispatcherRegisterActions()
    Dispatcher:registerAction("screenlock_pin_pad_lock_screen", {
        category    = "none",
        event       = "LockScreenPinPad",
        title       = _("Lock Screen (PinPad)"),
        filemanager = true,
        device      = true,
    })
end

------------------------------------------------------------------------------
--- EVENT LISTENING
------------------------------------------------------------------------------
---KOReader exit and restart
function ScreenLock:onExit()
    G_reader_settings:makeTrue("suspended_device")
end

function ScreenLock:onRestart()
    G_reader_settings:makeTrue("suspended_device")
end

--- Device suspension, reboot or power off
function ScreenLock:onRequestSuspend()
    G_reader_settings:makeTrue("suspended_device")
end

function ScreenLock:onRequestReboot()
    G_reader_settings:makeTrue("suspended_device")
end

function ScreenLock:onRequestPowerOff()
    G_reader_settings:makeTrue("suspended_device")
end

------------------------------------------------------------------------------
--- INIT & WAKE-UP HANDLING
------------------------------------------------------------------------------
function ScreenLock:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)

    local self_ref = self
    if G_reader_settings:isTrue("pinpadlock_activated") and G_reader_settings:isTrue("suspended_device") then
        self_ref:lockScreen()
    end

    return self
end

function ScreenLock:onResume()
    if self.pinPadDialog then
        self.pinPadDialog:close()
        self.pinPadDialog = nil
    end

    if G_reader_settings:isTrue("pinpadlock_activated") then
        self:lockScreen()
    end
end

------------------------------------------------------------------------------
--- DISPATCHER HANDLER
------------------------------------------------------------------------------
function ScreenLock:onLockScreen()
    self:lockScreen()
    return true
end

------------------------------------------------------------------------------
--- LOCK SCREEN
------------------------------------------------------------------------------
function ScreenLock:lockScreen()
    UIManager:nextTick(function()
        if not self.pinPadDialog then
            self.pinPadDialog = PinPadDialog:init()
            self.pinPadDialog:showPinPad()
        end
    end)
end

------------------------------------------------------------------------------
--- MAIN MENU ENTRY
------------------------------------------------------------------------------
function ScreenLock:addToMainMenu(menu_items)
    menu_items.pinpad = MenuEntryItems
end

return ScreenLock
