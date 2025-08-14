--[[
Author: yogi81 (original), Lena2309 (adaptation and improvements)
Original from `https://github.com/yogi81/screenlock_koreader_plugin/tree/main`
Description: implements a screen lock mechanism for KOReader
using a PIN pad interface. Also adds a menu entry in Settings -> Screen
]]

local ConfirmBox = require("ui/widget/confirmbox")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local PinPadDialog = require("ui/pinpaddialog")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

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

local ScreenLock = WidgetContainer:extend {
    name = "pinpadlock",
    is_doc_only = false,
    locked = false,      -- Tracks the locked state
    hide_content = true, -- Hide screen content before PIN is entered
}

------------------------------------------------------------------------------
-- REGISTER DISPATCHER ACTIONS
------------------------------------------------------------------------------
function ScreenLock:onDispatcherRegisterActions()
    Dispatcher:registerAction("screenlock_pin_pad_lock_screen", {
        category = "none",
        event = "LockScreenPinPad",
        title = _("Lock Screen (PinPad)"),
        filemanager = true,
    })
end

------------------------------------------------------------------------------
-- INIT (including wake-up handling via onResume)
------------------------------------------------------------------------------
function ScreenLock:init()
    -- 1) Register dispatcher action
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
    return self
end

function ScreenLock:onResume()
    if self.pinPadDialog then
        self.pinPadDialog:close()
    end
    if not self.locked and G_reader_settings:isTrue("pinpadlock_activated") then
        self:lockScreen()
    end
    self.locked = false
end

------------------------------------------------------------------------------
-- LOCK SCREEN
------------------------------------------------------------------------------
function ScreenLock:lockScreen()
    self.locked = true
    self.pinPadDialog = PinPadDialog:init()
    self.pinPadDialog:showPinPad()
end

------------------------------------------------------------------------------
-- DISPATCHER HANDLER
------------------------------------------------------------------------------
function ScreenLock:onLockScreen()
    self:lockScreen()
    return true
end

------------------------------------------------------------------------------
-- MAIN MENU ENTRY
------------------------------------------------------------------------------

local function setMessage()
    local lock_message = G_reader_settings:readSetting("pinpadlock_message")
    local input_dialog
    input_dialog = InputDialog:new {
        title = _("PIN pad lock message"),
        description = _("Enter a custom message to be displayed on the PIN pad lock."),
        input = lock_message,
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = _("Set message"),
                    is_enter_default = true,
                    callback = function()
                        G_reader_settings:saveSetting("pinpadlock_message", input_dialog:getInputText())
                        UIManager:close(input_dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

local function showMessageEnabled()
    return G_reader_settings:isTrue("pinpadlock_show_message")
end

local function genRadioMenuItem(text, setting, value)
    return {
        text = text,
        checked_func = function()
            return G_reader_settings:readSetting(setting) == value
        end,
        callback = function()
            G_reader_settings:saveSetting(setting, value)
        end,
        radio = true,
    }
end

local changePinCode = function()
    local confirmCurrentCode = PinPadDialog:new { stage = "confirm_current_code" }
    confirmCurrentCode:showPinPad()
end

local resetPinCode = function()
    local confirmBox
    confirmBox = ConfirmBox:new {
        text = _("Do you really want to reset the PIN code to \"1234\" ?"),
        ok_text = _("Yes"),
        ok_callback = function()
            G_reader_settings:saveSetting("pinpadlock_pin_code", "1234")
            UIManager:close(confirmBox)
            UIManager:show(InfoMessage:new { text = _("PIN Code resetted successfully."), timeout = 1 })
        end,
        cancel_callback = function()
            UIManager:close(confirmBox)
        end
    }
    UIManager:show(confirmBox)
end

function ScreenLock:addToMainMenu(menu_items)
    menu_items.pinpad = {
        text = _("PIN Pad Lock"),
        sorting_hint = "screen",
        sub_item_table = {
            {
                text = _("Activated"),
                checked_func = function()
                    return G_reader_settings:isTrue("pinpadlock_activated")
                end,
                callback = function()
                    G_reader_settings:toggle("pinpadlock_activated")
                end,
                separator = true,
            },
            {
                text = _("Change PIN Code"),
                callback = function()
                    changePinCode()
                end
            },
            {
                text = _("Reset PIN Code"),
                callback = function()
                    resetPinCode()
                end,
                separator = true
            },
            {
                text = _("Add custom message to lock"),
                checked_func = function()
                    return showMessageEnabled()
                end,
                callback = function()
                    G_reader_settings:toggle("pinpadlock_show_message")
                end,
                separator = true,
            },
            {
                text = _("Edit lock message"),
                enabled_func = function()
                    return showMessageEnabled()
                end,
                keep_menu_open = true,
                callback = function()
                    setMessage()
                end,
            },
            {
                text = _("Message position"),
                enabled_func = function()
                    return showMessageEnabled()
                end,
                sub_item_table = {
                    genRadioMenuItem(_("Top"), "pinpadlock_message_position", "top"),
                    genRadioMenuItem(_("Middle"), "pinpadlock_message_position", "middle"),
                    genRadioMenuItem(_("Bottom"), "pinpadlock_message_position", "bottom"),
                },
            },
            {
                text = _("Message alignment"),
                enabled_func = function()
                    return showMessageEnabled()
                end,
                sub_item_table = {
                    genRadioMenuItem(_("Left"), "pinpadlock_message_alignment", "left"),
                    genRadioMenuItem(_("Center"), "pinpadlock_message_alignment", "center"),
                    genRadioMenuItem(_("Right"), "pinpadlock_message_alignment", "right"),
                },
            },
        }
    }
end

return ScreenLock
