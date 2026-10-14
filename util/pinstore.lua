local sha2 = require("ffi/sha2")

local PinStore = {}

local function digest(pin, salt)
    return sha2.sha256(salt .. ":" .. pin)
end

function PinStore.set(pin)
    math.randomseed(os.time() + math.floor(os.clock() * 1e6))
    local salt = string.format("%08x%08x", math.random(0, 0x7fffffff), math.random(0, 0x7fffffff))
    G_reader_settings:saveSetting("pinpadlock_pin_salt", salt)
    G_reader_settings:saveSetting("pinpadlock_pin_hash", digest(pin, salt))
    G_reader_settings:delSetting("pinpadlock_pin_code")
end

function PinStore.check(pin)
    if G_reader_settings:has("pinpadlock_pin_code") then
        local correct_pin = G_reader_settings:readSetting("pinpadlock_pin_code")
        PinStore.set(correct_pin)
    end
    local salt = G_reader_settings:readSetting("pinpadlock_pin_salt")
    local hash = G_reader_settings:readSetting("pinpadlock_pin_hash")
    return salt ~= nil and hash ~= nil and digest(pin, salt) == hash
end

-- call once at load: converts an old plain-text PIN, or creates the default
function PinStore.migrate()
    if G_reader_settings:has("pinpadlock_pin_hash") then
        return
    end
    PinStore.set(G_reader_settings:readSetting("pinpadlock_pin_code") or "1234")
end

return PinStore
