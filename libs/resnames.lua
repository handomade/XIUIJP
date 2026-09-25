--[[
* Resource names for macros / UI.
* Ashita Name array (Lua 1-based): [1] default, [2] Japanese, [3] English.
* Prefer the Japanese DAT name for /ma /ja when it exists (JP client style).
]]--

local encoding = require('libs.encoding');

local M = {};

local function is_ascii(s)
    if type(s) ~= 'string' or s == '' then return true; end
    for i = 1, #s do
        if s:byte(i) >= 128 then return false; end
    end
    return true;
end

local function is_valid_utf8(s)
    local i, n = 1, #s;
    while i <= n do
        local c = s:byte(i);
        if c < 0x80 then
            i = i + 1;
        elseif c >= 0xC2 and c <= 0xDF then
            local n1 = s:byte(i + 1);
            if not n1 or n1 < 0x80 or n1 > 0xBF then return false; end
            i = i + 2;
        elseif c >= 0xE0 and c <= 0xEF then
            local n1, n2 = s:byte(i + 1), s:byte(i + 2);
            if not n1 or not n2 or n1 < 0x80 or n1 > 0xBF or n2 < 0x80 or n2 > 0xBF then
                return false;
            end
            i = i + 3;
        elseif c >= 0xF0 and c <= 0xF4 then
            local n1, n2, n3 = s:byte(i + 1), s:byte(i + 2), s:byte(i + 3);
            if not n1 or not n2 or not n3 then return false; end
            if n1 < 0x80 or n1 > 0xBF or n2 < 0x80 or n2 > 0xBF or n3 < 0x80 or n3 > 0xBF then
                return false;
            end
            i = i + 4;
        else
            return false;
        end
    end
    return true;
end

function M.ToUtf8(s)
    if type(s) ~= 'string' or s == '' then
        return s or '';
    end
    if is_ascii(s) or is_valid_utf8(s) then
        return s;
    end
    local ok, converted = pcall(function()
        return encoding:ShiftJIS_To_UTF8(s, true);
    end);
    if ok and type(converted) == 'string' and converted ~= '' then
        return converted;
    end
    return s;
end

-- Chat manager wants Shift-JIS for Japanese FFXI commands.
function M.ForCommand(s)
    if type(s) ~= 'string' or s == '' or is_ascii(s) then
        return s or '';
    end
    if is_valid_utf8(s) then
        local ok, converted = pcall(function()
            return encoding:UTF8_To_ShiftJIS(s, true);
        end);
        if ok and type(converted) == 'string' and converted ~= '' then
            return converted;
        end
    end
    return s;
end

local function try_get_string(tableName, id, lang)
    if not id then return nil; end
    local rm = AshitaCore:GetResourceManager();
    if not rm then return nil; end
    local ok, s = pcall(function()
        if lang then
            return rm:GetString(tableName, id, lang);
        end
        return rm:GetString(tableName, id);
    end);
    if ok and type(s) == 'string' and s ~= '' then
        return s;
    end
    return nil;
end

-- LanguageId: 1 = Japanese in Ashita.
local function japanese_from_table(tableName, id)
    return try_get_string(tableName, id, 1) or try_get_string(tableName, id, 0);
end

local function first_non_ascii(...)
    for i = 1, select('#', ...) do
        local s = select(i, ...);
        if type(s) == 'string' and s ~= '' and not is_ascii(s) then
            return s;
        end
    end
    return nil;
end

function M.FromArray(names, stringTable, id)
    if not names then
        names = {};
    end
    local defaultName = names[1] or names[0] or '';
    local slotJa = names[2] or names[1];
    -- Probe every slot; English DAT still stores JP in a language index.
    local fromSlots = nil;
    for i = 0, 4 do
        local s = names[i];
        if type(s) == 'string' and s ~= '' and not is_ascii(s) then
            fromSlots = s;
            break;
        end
    end
    local slotEn = names[3];
    local tableJa = stringTable and japanese_from_table(stringTable, id) or nil;
    local japanese = first_non_ascii(fromSlots, slotJa, tableJa, defaultName);
    local command = japanese or defaultName;
    if command == '' and slotEn then
        command = slotEn;
    end
    return command, M.ToUtf8(japanese or command);
end

function M.FromSpell(spell)
    if not spell then return '', ''; end
    local id = spell.Index or spell.Id;
    return M.FromArray(spell.Name, 'spells.names', id);
end

function M.FromAbility(ability)
    if not ability then return '', ''; end
    local id = ability.Id or ability.Index;
    return M.FromArray(ability.Name, 'abilities.names', id);
end

function M.FromItem(item)
    if not item then return '', ''; end
    local id = item.Id or item.Index;
    return M.FromArray(item.Name, 'items.names', id);
end

function M.FromKeyItem(keyItem)
    if not keyItem then return '', ''; end
    local id = keyItem.Id or keyItem.Index;
    return M.FromArray(keyItem.Name, 'keyitems.names', id);
end

function M.IsAscii(s)
    return is_ascii(s);
end

local function first_ascii(...)
    for i = 1, select('#', ...) do
        local s = select(i, ...);
        if type(s) == 'string' and s ~= '' and is_ascii(s) then
            return s;
        end
    end
    return nil;
end

-- English DAT / icon / horizonspells keys (Name[3] English, Name[1] default).
function M.EnglishFromArray(names, stringTable, id)
    if not names then
        names = {};
    end
    local tableEn = stringTable and (try_get_string(stringTable, id, 2) or try_get_string(stringTable, id, 3)) or nil;
    return first_ascii(names[3], names[1], names[0], tableEn) or names[1] or '';
end

function M.EnglishFromSpell(spell)
    if not spell then return ''; end
    return M.EnglishFromArray(spell.Name, 'spells.names', spell.Index or spell.Id);
end

function M.EnglishFromAbility(ability)
    if not ability then return ''; end
    return M.EnglishFromArray(ability.Name, 'abilities.names', ability.Id or ability.Index);
end

function M.EnglishFromItem(item)
    if not item then return ''; end
    return M.EnglishFromArray(item.Name, 'items.names', item.Id or item.Index);
end

-- Icon files and horizonspells are keyed in English. Resolve JP action names.
function M.EnglishForLookup(kind, name)
    if type(name) ~= 'string' or name == '' or is_ascii(name) then
        return name;
    end
    local rm = AshitaCore:GetResourceManager();
    if not rm then
        return name;
    end
    local actiondb = require('modules.hotbar.actiondb');
    if kind == 'ma' then
        local id = actiondb.GetSpellId(name);
        if id then
            local en = M.EnglishFromSpell(rm:GetSpellById(id));
            if en ~= '' then return en; end
        end
    elseif kind == 'ja' or kind == 'ws' or kind == 'pet' then
        local id = (kind == 'pet') and actiondb.GetPetAbilityId(name) or actiondb.GetAbilityId(name);
        if id then
            local en = M.EnglishFromAbility(rm:GetAbilityById(id));
            if en ~= '' then return en; end
        end
    elseif kind == 'item' or kind == 'equip' then
        local id = actiondb.GetItemId(name);
        if id then
            local en = M.EnglishFromItem(rm:GetItemById(id));
            if en ~= '' then return en; end
        end
    end
    return name;
end

-- If a saved bind still has the English DAT name, swap in Japanese when present.
function M.PreferJapanese(kind, name)
    if type(name) ~= 'string' or name == '' or not is_ascii(name) then
        return name;
    end
    local rm = AshitaCore:GetResourceManager();
    if not rm then
        return name;
    end
    local actiondb = require('modules.hotbar.actiondb');
    if kind == 'ma' then
        local id = actiondb.GetSpellId(name);
        if id then
            local cmd = M.FromSpell(rm:GetSpellById(id));
            if cmd ~= '' then return cmd; end
        end
    elseif kind == 'ja' or kind == 'ws' or kind == 'pet' then
        local id = (kind == 'pet') and actiondb.GetPetAbilityId(name) or actiondb.GetAbilityId(name);
        if id then
            local cmd = M.FromAbility(rm:GetAbilityById(id));
            if cmd ~= '' then return cmd; end
        end
    elseif kind == 'item' or kind == 'equip' then
        local id = actiondb.GetItemId(name);
        if id then
            local cmd = M.FromItem(rm:GetItemById(id));
            if cmd ~= '' then return cmd; end
        end
    end
    return name;
end

return M;
