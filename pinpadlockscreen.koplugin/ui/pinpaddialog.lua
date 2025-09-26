--[[
Author: Lena2309
Description: represents a PIN pad interface and its behavior within KOReader.
It handles user input, PIN validation, and UI interactions.
]]

local Blitbuffer = require("ffi/blitbuffer")
local BookStatusWidget = require("ui/widget/bookstatuswidget")
local Button = require("ui/widget/button")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local InfoMessage = require("ui/widget/infomessage")
local ImageWidget = require("ui/widget/imagewidget")
local PinPadButtonDialog = require("ui/pinpadbuttondialog")
local RenderImage = require("ui/renderimage")
local Screensaver = require("ui/screensaver")
local ScreenSaverWidget = require("ui/widget/screensaverwidget")
local UIManager = require("ui/uimanager")
local ffiUtil = require("ffi/util")
local util = require("util")
local _ = require("gettext")
local Screen = Device.screen

local LOCKED_TEXT = _("Enter your PIN")
local CONFIRM_CURRENT_CODE_TEXT = _("Enter the current PIN Code")
local NEW_CODE_TEXT = _("Enter the new PIN Code")

local MAX_TRIES_LIMIT = 3
local TIMEOUT_TIME = 30

if G_reader_settings:hasNot("current_tries_number") then
    G_reader_settings:saveSetting("current_tries_number", 0)
end
if G_reader_settings:hasNot("block_start_time") then
    G_reader_settings:saveSetting("block_start_time", 0)
end
if G_reader_settings:hasNot("currently_blocked") then
    G_reader_settings:makeFalse("currently_blocked")
end

local PinPadDialog = FrameContainer:extend {
    icon = "lock",
    stage = "locked", -- "confirm_current_code" or "enter_new_code"
}

function PinPadDialog:init()
    self:setDialogText()
    self.pin = ""
    self.buttons = self:initializeButtons()
    Screensaver:setup()
    self:initializeScreensaverBackground()
    if self.screensaver_widget then
        UIManager:show(self.screensaver_widget)
    end
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

function PinPadDialog:createButton(text, callback, hold_callback)
    local button = Button:new {
        text = text,
        callback = callback,
        hold_callback = hold_callback,
    }
    return button
end

function PinPadDialog:initializeButtons()
    local ref_self = self
    local buttons = {
        {
            self:createButton("1", function() ref_self:onAppendToPin("1") end),
            self:createButton("2", function() ref_self:onAppendToPin("2") end),
            self:createButton("3", function() ref_self:onAppendToPin("3") end),
        },
        {
            self:createButton("4", function() ref_self:onAppendToPin("4") end),
            self:createButton("5", function() ref_self:onAppendToPin("5") end),
            self:createButton("6", function() ref_self:onAppendToPin("6") end),
        },
        {
            self:createButton("7", function() ref_self:onAppendToPin("7") end),
            self:createButton("8", function() ref_self:onAppendToPin("8") end),
            self:createButton("9", function() ref_self:onAppendToPin("9") end),
        },
        {
            self:createButton("Cancel", function() ref_self:onDelete() end, function() ref_self:onCancel() end),
            self:createButton("0", function() ref_self:onAppendToPin("0") end),
            self:createButton("OK", function() ref_self:onOk() end),
        }
    }
    return buttons
end

function PinPadDialog:initializeScreensaverBackground()
    if Screensaver.screensaver_type == "disable" and not Screensaver.show_message and not Screensaver.overlay_message then
        return
    end

    local rotation_mode = Screen:getRotationMode()

    if Screensaver:modeExpectsPortrait() then
        Device.orig_rotation_mode = rotation_mode
        -- Leave Portrait & Inverted Portrait alone, that works just fine.
        if bit.band(Device.orig_rotation_mode, 1) == 1 then
            -- i.e., only switch to Portrait if we're currently in *any* Landscape orientation (odd number)
            Screen:setRotationMode(Screen.DEVICE_ROTATED_UPRIGHT)
        else
            Device.orig_rotation_mode = nil
        end

        -- On eInk, if we're using a screensaver mode that shows an image,
        -- flash the screen to white first, to eliminate ghosting.
        if Device:hasEinkScreen() and Screensaver:modeIsImage() then
            if Screensaver:withBackground() then
                Screen:clear()
            end
            Screen:refreshFull(0, 0, Screen:getWidth(), Screen:getHeight())

            -- On Kobo, on sunxi SoCs with a recent kernel, wait a tiny bit more to avoid weird refresh glitches...
            if Device:isKobo() and Device:isSunxi() then
                ffiUtil.usleep(150 * 1000)
            end
        end
    else
        -- nil it, in case user switched ScreenSaver modes during our lifetime.
        Device.orig_rotation_mode = nil
    end

    local widget = nil
    if Screensaver.screensaver_type == "cover" or Screensaver.screensaver_type == "random_image" then
        local widget_settings = {
            width = Screen:getWidth(),
            height = Screen:getHeight(),
            scale_factor = G_reader_settings:isFalse("screensaver_stretch_images") and 0 or nil,
            stretch_limit_percentage = G_reader_settings:readSetting("screensaver_stretch_limit_percentage"),
        }
        if Screensaver.image then
            widget_settings.image = Screensaver.image
            widget_settings.image_disposable = true
        elseif Screensaver.image_file then
            if G_reader_settings:isTrue("screensaver_rotate_auto_for_best_fit") then
                -- We need to load the image here to determine whether to rotate
                if util.getFileNameSuffix(Screensaver.image_file) == "svg" then
                    widget_settings.image = RenderImage:renderSVGImageFile(Screensaver.image_file, nil, nil, 1)
                else
                    widget_settings.image = RenderImage:renderImageFile(Screensaver.image_file, false, nil, nil)
                end
                if not widget_settings.image then
                    widget_settings.image = RenderImage:renderCheckerboard(Screen:getWidth(), Screen:getHeight(),
                        Screen.bb:getType())
                end
                widget_settings.image_disposable = true
            else
                widget_settings.file = Screensaver.image_file
                widget_settings.file_do_cache = false
            end
            widget_settings.alpha = true
        end                                               -- set cover or file
        if G_reader_settings:isTrue("screensaver_rotate_auto_for_best_fit") then
            local angle = rotation_mode == 3 and 180 or 0 -- match mode if possible
            if (widget_settings.image:getWidth() < widget_settings.image:getHeight()) ~= (widget_settings.width < widget_settings.height) then
                angle = angle + (G_reader_settings:isTrue("imageviewer_rotation_landscape_invert") and -90 or 90)
            end
            widget_settings.rotation_angle = angle
        end
        widget = ImageWidget:new(widget_settings)
    elseif Screensaver.screensaver_type == "bookstatus" then
        local ReaderUI = require("apps/reader/readerui")
        widget = BookStatusWidget:new {
            ui = ReaderUI.instance,
            readonly = true,
        }
    elseif Screensaver.screensaver_type == "readingprogress" then
        widget = Screensaver.getReaderProgress()
    end

    -- Assume that we'll be covering the full-screen by default (either because of a widget, or a background fill).
    local covers_fullscreen = true
    -- Speaking of, set that background fill up...
    local background
    if Screensaver.screensaver_background == "black" then
        background = Blitbuffer.COLOR_BLACK
    elseif Screensaver.screensaver_background == "white" then
        background = Blitbuffer.COLOR_WHITE
    elseif Screensaver.screensaver_background == "none" then
        background = nil
    end

    UIManager:setIgnoreTouchInput(false)

    if widget then
        self.screensaver_widget = ScreenSaverWidget:new {
            widget = widget,
            background = background,
            covers_fullscreen = covers_fullscreen,
        }
        self.screensaver_widget.dithered = true
    end
end

function PinPadDialog:isBlocked()
    local block_start = G_reader_settings:readSetting("block_start_time") or 0
    if block_start == 0 then
        return false
    end

    local elapsed = os.time() - block_start
    if elapsed >= TIMEOUT_TIME then
        -- Timeout expired, unblockS
        G_reader_settings:makeFalse("currently_blocked")
        G_reader_settings:saveSetting("block_start_time", 0)
        G_reader_settings:saveSetting("current_tries_number", 0)
        return false
    else
        self.remaining_block_time = TIMEOUT_TIME - elapsed
        return true
    end
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

    -- overlay the blocking message if needed
    if self.stage == "locked" and self:isBlocked() then
        self.blocking_dialog = InfoMessage:new {
            text = _("Too many failed attempts. Wait " .. self.remaining_block_time .. " seconds."),
            timeout = self.remaining_block_time,
            dismissable = false,
        }
        UIManager:show(self.blocking_dialog)
    end
end

function PinPadDialog:firstShowPinPad()
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
    UIManager:scheduleIn(1, self.dialog)
    
    -- overlay the blocking message if needed
    if self.stage == "locked" and self:isBlocked() then
        self.blocking_dialog = InfoMessage:new {
            text = _("Too many failed attempts. Wait " .. self.remaining_block_time .. " seconds."),
            timeout = self.remaining_block_time,
            dismissable = false,
        }
        UIManager:scheduleIn(1, self.blocking_dialog)
    end
end

function PinPadDialog:reset()
    self.pin = ""
    self:setDialogText()
end

function PinPadDialog:closeDialogs()
    if self.blocking_dialog then
        UIManager:close(self.blocking_dialog)
    end
    if self.dialog then
        UIManager:close(self.dialog)
    end
end

function PinPadDialog:refreshUI()
    self:closeDialogs()
    self:showPinPad()
end

function PinPadDialog:close()
    self:reset()
    self:closeDialogs()
    if self.screensaver_widget then
        UIManager:close(self.screensaver_widget)
        self.screensaver_widget = nil
    end
end

function PinPadDialog:onAppendToPin(digit)
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
            UIManager:show(InfoMessage:new { text = _("Correct PIN, have fun !"), timeout = 2 })
            G_reader_settings:saveSetting("current_tries_number", 0)
            G_reader_settings:saveSetting("block_start_time", 0)
        else
            if self.pin == "" then
                return -- ignore button press if pin is empty
            end
            local current_tries = G_reader_settings:readSetting("current_tries_number")
            if (current_tries + 1) >= MAX_TRIES_LIMIT then
                G_reader_settings:saveSetting("block_start_time", os.time())
            else
                G_reader_settings:saveSetting("current_tries_number", current_tries + 1)
                UIManager:show(InfoMessage:new { text = _("Wrong PIN, try again."), timeout = 2 })
            end
            self:onCancel()
        end
    elseif self.stage == "confirm_current_code" then
        if self.pin == G_reader_settings:readSetting("pinpadlock_pin_code") then
            self:close()
            UIManager:show(InfoMessage:new { text = _("Correct PIN, you may change your PIN Code !"), timeout = 2 })
            local enterNewCode = PinPadDialog:new { stage = "enter_new_code" }
            enterNewCode:showPinPad()
        else
            UIManager:show(InfoMessage:new { text = _("Wrong PIN, try again."), timeout = 2 })
            self:onCancel()
        end
    else
        G_reader_settings:saveSetting("pinpadlock_pin_code", self.pin)
        self:close()
        UIManager:show(InfoMessage:new { text = _("PIN Code changed successfully !"), timeout = 2 })
    end
end

function PinPadDialog:onDelete()
    if self.pin == "" then
        return -- ignore button press if pin is empty
    elseif #self.pin == 1 then
        self.pin = ""
    else
        self.pin = self.pin:sub(1, #self.pin - 1)
    end

    if #self.dialog_text == 1 then -- display default text back
        self:setDialogText()
    elseif not (self.dialog_text == LOCKED_TEXT or self.dialog_text == CONFIRM_CURRENT_CODE_TEXT or self.dialog_text == NEW_CODE_TEXT) then
        self.dialog_text = self.dialog_text:sub(1, #self.dialog_text - 1)
    end
    self:refreshUI()
end

function PinPadDialog:onCancel()
    if self.pin == "" then
        return -- ignore button press if pin is empty
    end
    self:reset()
    self:refreshUI()
end

return PinPadDialog
