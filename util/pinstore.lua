local sha2 = require("ffi/sha2")

local PinStore = {}

function PinStore.set(pin)
    G_reader_settings:saveSetting("pinpadlock_pin_code", pin)
end

function PinStore.check(pin)
    return pin == G_reader_settings:readSetting("pinpadlock_pin_code")
end

-- call once at load: converts an old plain-text PIN, or creates the default
function PinStore.migrate()
    PinStore.set(G_reader_settings:readSetting("pinpadlock_pin_code") or "1234")
end

return PinStore
