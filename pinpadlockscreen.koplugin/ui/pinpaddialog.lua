--[[
Author: Lena2309
Description: represents a PIN pad interface and its behavior within KOReader.
It handles user input, PIN validation, and UI interactions.
]]

local Button = require("ui/widget/button")
local PinPadButtonDialog = require("ui/pinpadbuttondialog")
local FrameContainer = require("ui/widget/container/framecontainer")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local LOCKED_TEXT = _("Enter your PIN")
local CONFIRM_CURRENT_CODE_TEXT = _("Enter the current PIN Code")
local NEW_CODE_TEXT = _("Enter the new PIN Code")

local PinPadDialog = FrameContainer:extend {
    icon = "lock",
    stage = "locked", -- "confirm_current_code" or "enter_new_code"
}

function PinPadDialog:init()
    self:setDialogText()
    self.pin = ""
    self.buttons = self:initializeButtons()
    return self
end

function PinPadDialog:setDialogText()
    if self.stage == "locked" then
        self.dialog_text = LOCKED_TEXT
    elseif self.stage == "confirm_current_code" then
        self.dialog_text = CONFIRM_CURRENT_CODE_TEXT
    else
        self.dialog_text = NEW_CODE_TEXT
    end
end

function PinPadDialog:initializeButtons()
    local ref_self = self
    local buttons = {
        {
            self:createButton("1", function() ref_self:appendToPin("1") end),
            self:createButton("2", function() ref_self:appendToPin("2") end),
            self:createButton("3", function() ref_self:appendToPin("3") end),
        },
        {
            self:createButton("4", function() ref_self:appendToPin("4") end),
            self:createButton("5", function() ref_self:appendToPin("5") end),
            self:createButton("6", function() ref_self:appendToPin("6") end),
        },
        {
            self:createButton("7", function() ref_self:appendToPin("7") end),
            self:createButton("8", function() ref_self:appendToPin("8") end),
            self:createButton("9", function() ref_self:appendToPin("9") end),
        },
        {
            self:createButton("Cancel", function() ref_self:onCancel() end),
            self:createButton("0", function() ref_self:appendToPin("0") end),
            self:createButton("OK", function() ref_self:onOk() end),
        },
    }
    return buttons
end

function PinPadDialog:showPinPad()
    if self.stage == "locked" then
        self.dialog = PinPadButtonDialog:new {
            icon = self.icon,
            title = self.dialog_text,
            title_align = "center",
            use_info_style = false,
            buttons = self.buttons,
            dismissable = false,
        }
    else
        self.dialog = PinPadButtonDialog:new {
            icon = self.icon,
            title = self.dialog_text,
            title_align = "center",
            use_info_style = false,
            buttons = self.buttons,
            dismissable = true,
            override_show_message = true,
        }
    end


    UIManager:show(self.dialog)
end

function PinPadDialog:refreshUI()
    if self.dialog then
        UIManager:close(self.dialog)
    end
    self:showPinPad()
end

function PinPadDialog:createButton(text, callback)
    local button = Button:new {
        text = text,
        callback = callback,
    }
    return button
end

function PinPadDialog:appendToPin(digit)
    if self.dialog_text == LOCKED_TEXT or self.dialog_text == CONFIRM_CURRENT_CODE_TEXT or self.dialog_text == NEW_CODE_TEXT then
        self.dialog_text = ""
    end
    self.dialog_text = self.dialog_text .. "*"
    self.pin = self.pin .. digit
    self:refreshUI()
end

function PinPadDialog:onOk()
    if self.stage == "locked" then
        if self.pin == G_reader_settings:readSetting("pinpadlock_pin_code") then
            self:close()
            UIManager:show(InfoMessage:new { text = _("Correct PIN, have fun !"), timeout = 1 })
        else
            UIManager:show(InfoMessage:new { text = _("Wrong PIN, try again."), timeout = 1 })
            self:onCancel()
        end
    elseif self.stage == "confirm_current_code" then
        if self.pin == G_reader_settings:readSetting("pinpadlock_pin_code") then
            self:close()
            UIManager:show(InfoMessage:new { text = _("Correct PIN, you may change your PIN Code !"), timeout = 1 })
            local enterNewCode = PinPadDialog:new { stage = "enter_new_code" }
            enterNewCode:showPinPad()
        else
            UIManager:show(InfoMessage:new { text = _("Wrong PIN, try again."), timeout = 1 })
            self:onCancel()
        end
    else
        G_reader_settings:saveSetting("pinpadlock_pin_code", self.pin)
        self:close()
        UIManager:show(InfoMessage:new { text = _("PIN Code changed successfully !"), timeout = 1 })
    end
end

function PinPadDialog:onCancel()
    self.pin = ""
    self:setDialogText()
    self:refreshUI()
end

function PinPadDialog:close()
    self.pin = ""
    self:setDialogText()
    UIManager:close(self.dialog)
end

return PinPadDialog
