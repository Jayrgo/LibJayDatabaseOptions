local MAJOR = "LibJayDatabaseOptions"
local MINOR = 1

assert(LibStub, format("%s requires LibStub.", MAJOR))

local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

local L = {}

L.PROFILES = "Profiles"
L.COPY_FROM = "Copy From"
L.CURRENT = "Current"
L.DELETE = DELETE
L.LAST_CONFIGURATION_CHANGE = "Last configuration change at"
L.NEW = NEW

if GetLocale() == "deDE" then
    L.PROFILES = "Profile"
    L.COPY_FROM = "Kopiere von"
    L.CURRENT = "Aktuell"
    L.LAST_CONFIGURATION_CHANGE = "Letzte Konfigurationsänderung um"
end

local OptionHandlerMixin = {}

---@param info table
---@return string profile
function OptionHandlerMixin:GetProfile(info) return self.db:GetProfile() end

---@param info table
---@param value string
function OptionHandlerMixin:SetProfile(info, value) if value then self.db:SetProfile(value) end end

local DEFAULT_PROFILES = {
    UnitName("player") .. " - " .. GetRealmName(), GetRealmName(), select(2, UnitFactionGroup("player")),
    UnitRace("player"), (UnitClass("player")),
}
---@param info table
---@return table profiles
function OptionHandlerMixin:GetCurrentProfiles(info)
    local profiles = self.db:GetProfiles()
    for i = 1, #profiles do
        local profile = profiles[i]
        profiles[profile] = profile
        profiles[i] = nil
    end
    for i = 1, #DEFAULT_PROFILES do
        local profile = DEFAULT_PROFILES[i]
        profiles[profile] = profile
    end
    return profiles
end

---@param info table
---@return table profiles
function OptionHandlerMixin:GetProfiles(info)
    local profiles, currentProfile = self.db:GetProfiles(), self.db:GetProfile()
    for i = 1, #profiles do
        local profile = profiles[i]
        profiles[profile] = profile ~= currentProfile and profile or nil
        profiles[i] = nil
    end
    return profiles
end

---@param info table
---@param value string
function OptionHandlerMixin:CopyProfile(info, value) if value then self.db:CopyProfile(value) end end

---@param info table
---@param value string
function OptionHandlerMixin:DeleteProfile(info, value) if value then self.db:DeleteProfile(value) end end

---@param info table
function OptionHandlerMixin:ResetProfile(info) self.db:ResetProfile(self.db:GetProfile()) end

---@param info table
function OptionHandlerMixin:LastChange(info) return "|cffffffff" .. self.db:GetLastChange() .. "|r" end

lib.handlers = lib.handlers or {}
local handlers = lib.handlers

local LJMixin = LibStub("LibJayMixin")
for k, v in pairs(handlers) do LJMixin:Mixin(v, OptionHandlerMixin) end -- upgrade

---@param db table
---@return table handler
local function getOptionHandler(db)
    local handler = handlers[db] or LJMixin:Mixin({db = db}, OptionHandlerMixin)
    handlers[db] = handler
    return handler
end

local strtrim = strtrim
local function onSet(arg, value) return strtrim(value) end

local strlen = strlen
local function validate(arg, value) return strlen(value) > 0 end

local OPTION_LIST = {
    {type = "select", text = L.CURRENT, get = "GetProfile", set = "SetProfile", values = "GetCurrentProfiles"},
    {type = "string", text = L.NEW, set = "SetProfile", onSet = onSet, validate = validate},
    {type = "select", text = L.COPY_FROM, set = "CopyProfile", values = "GetProfiles"},
    {type = "select", text = L.DELETE, set = "DeleteProfile", values = "GetProfiles"} --[[ ,
    {
        type = "function",
        text = L.RESET,
        func = "ResetProfile"
    } ]] ,
    {type = "string", text = L.LAST_CONFIGURATION_CHANGE, get = "LastChange", isReadOnly = true, justifyH = "RIGHT"},
}

local error = error
local format = format
local type = type
local LJOptions = LibStub("LibJayOptions")
---@param db table
---@param parent string
function lib:New(db, parent)
    if type(db) ~= "table" then
        error(format("Usage: %s:New(db[, parent]): 'db' - table expected got %s", MAJOR, type(db)), 2)
    end
    if parent then
        if type(parent) ~= "string" then
            error(format("Usage: %s:New(db[, parent]): 'parent' - string expected got %s", MAJOR, type(parent)), 2)
        end
        local optionList = {handler = getOptionHandler(db)}
        for i = 1, #OPTION_LIST do optionList[i] = OPTION_LIST[i] end
        LJOptions:New(L.PROFILES, parent, optionList)
    else
        return {type = "header", text = L.PROFILES, handler = getOptionHandler(db), optionList = OPTION_LIST}
    end
end
setmetatable(lib, {__call = lib.New})

lib.optionsFuncs = lib.optionsFuncs or {}
local optionsFuncs = lib.optionsFuncs

local select = select
local unpack = unpack
---@param db table
---@return function set
---@return function get
---@return function default
function lib:GetOptionFunctions(db)
    if type(db) ~= "table" then
        error(format("Usage: %s:GetOptionFunctions(db): 'db' - table expected got %s", MAJOR, type(db)), 2)
    end

    if not optionsFuncs[db] then
        optionsFuncs[db] = {
            function(info, ...)
                if info.type == "select" and info.isMulti then
                    info[#info + 1] = ...
                elseif info.type == "color" then
                    local color = db:Get(unpack(info, 1, #info))

                    return color.r, color.g, color.b, info.hasAlpha and color.a
                end
                return db:Get(unpack(info, 1, #info))
            end, function(info, ...)
                if info.type == "select" and info.isMulti then
                    info[#info + 1] = ...
                    db:Set(select(2, ...), unpack(info, 1, #info))
                elseif info.type == "color" then
                    local r, g, b, a = ...
                    info[#info + 1] = "r"
                    db:Set(r, unpack(info, 1, #info))
                    info[#info] = "g"
                    db:Set(g, unpack(info, 1, #info))
                    info[#info] = "b"
                    db:Set(b, unpack(info, 1, #info))
                    if info.hasAlpha then
                        info[#info] = "a"
                        db:Set(a, unpack(info, 1, #info))
                    end
                else
                    db:Set(..., unpack(info, 1, #info))
                end
            end, function(info, ...)
                if info.type == "select" and info.isMulti then -- luacheck: ignore 542

                elseif info.type == "color" then
                    local color = db:GetDefault(unpack(info, 1, #info))
                    if info.hasAlpha then
                        return color.r, color.g, color.b, color.a
                    else
                        return color.r, color.g, color.b
                    end
                else
                    return db:GetDefault(unpack(info, 1, #info))
                end
            end,
        }
    end

    return unpack(optionsFuncs[db])
end

lib.globalOptionsFuncs = lib.globalOptionsFuncs or {}
local globalOptionsFuncs = lib.globalOptionsFuncs

function lib:GetGlobalOptionFunctions(db)
    if type(db) ~= "table" then
        error(format("Usage: %s:GetGlobalOptionFunctions(db): 'db' - table expected got %s", MAJOR, type(db)), 2)
    end

    if not globalOptionsFuncs[db] then
        globalOptionsFuncs[db] = {
            function(info, ...)
                if info.type == "select" and info.isMulti then
                    info[#info + 1] = ...
                elseif info.type == "color" then
                    local color = db:GetGlobal(unpack(info, 1, #info))

                    return color.r, color.g, color.b, info.hasAlpha and color.a
                end
                return db:GetGlobal(unpack(info, 1, #info))
            end, function(info, ...)
                if info.type == "select" and info.isMulti then
                    info[#info + 1] = ...
                    db:SetGlobal(select(2, ...), unpack(info, 1, #info))
                elseif info.type == "color" then
                    local r, g, b, a = ...
                    info[#info + 1] = "r"
                    db:SetGlobal(r, unpack(info, 1, #info))
                    info[#info] = "g"
                    db:SetGlobal(g, unpack(info, 1, #info))
                    info[#info] = "b"
                    db:SetGlobal(b, unpack(info, 1, #info))
                    if info.hasAlpha then
                        info[#info] = "a"
                        db:SetGlobal(a, unpack(info, 1, #info))
                    end
                else
                    db:SetGlobal(..., unpack(info, 1, #info))
                end
            end, function(info, ...)
                if info.type == "select" and info.isMulti then -- luacheck: ignore 542

                elseif info.type == "color" then
                    local color = db:GetGlobalDefault(unpack(info, 1, #info))
                    if info.hasAlpha then
                        return color.r, color.g, color.b, color.a
                    else
                        return color.r, color.g, color.b
                    end
                else
                    return db:GetGlobalDefault(unpack(info, 1, #info))
                end
            end,
        }
    end

    return unpack(globalOptionsFuncs[db])
end
