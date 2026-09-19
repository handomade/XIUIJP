--[[
* XIUI Japanese overlay
*
* English source strings stay in upstream files. Visible ImGui text is
* rewritten from locale/ja.lua. Missing keys fall back to English, so
* an upstream update still works until the dictionary is topped up.
*
* locale/ja.lua is UTF-8 with readable Japanese. It is loaded as binary
* (not require) so a CP932 Lua file loader cannot turn it into '?'.
*
* Do not translate saved setting keys, profile names, or slash-command syntax.
]]--

local M = {};

local strings = {};
local commands = {};
local installed = false;

function M.T(s)
    if type(s) ~= 'string' or s == '' then
        return s;
    end
    return strings[s] or s;
end

function M.cmd(usage, desc)
    return commands[usage] or M.T(desc) or desc or '';
end

local function split_id(s)
    local vis, suf = s:match('^(.-)(###.*)$');
    if vis then
        return vis, suf;
    end
    vis, suf = s:match('^(.-)(##.*)$');
    if vis then
        return vis, suf;
    end
    return s, nil;
end

function M.label(s)
    if type(s) ~= 'string' then
        return s;
    end
    local vis, suf = split_id(s);
    vis = M.T(vis);
    if suf then
        return vis .. suf;
    end
    return vis;
end

-- Window / popup titles: keep the original string as ImGui ID.
function M.title(s)
    if type(s) ~= 'string' then
        return s;
    end
    local vis, suf = split_id(s);
    vis = M.T(vis);
    if suf then
        return vis .. suf;
    end
    return vis .. '###' .. s;
end

function M.install(imgui)
    if installed or not imgui then
        return;
    end
    installed = true;

    local orig = {};
    local function wrap_label(name)
        orig[name] = imgui[name];
        if not orig[name] then
            return;
        end
        imgui[name] = function(first, ...)
            return orig[name](M.label(first), ...);
        end
    end

    wrap_label('Text');
    wrap_label('TextDisabled');
    wrap_label('BulletText');
    wrap_label('Button');
    wrap_label('SmallButton');
    wrap_label('Checkbox');
    wrap_label('CollapsingHeader');
    wrap_label('Selectable');
    wrap_label('SetTooltip');
    wrap_label('MenuItem');
    wrap_label('RadioButton');
    wrap_label('InputText');
    wrap_label('TextWrapped');
    wrap_label('Combo');

    if imgui.ShowHelp then
        orig.ShowHelp = imgui.ShowHelp;
        imgui.ShowHelp = function(first, ...)
            return orig.ShowHelp(M.T(first), ...);
        end
    end

    if imgui.TextColored then
        orig.TextColored = imgui.TextColored;
        imgui.TextColored = function(color, text, ...)
            return orig.TextColored(color, M.label(text), ...);
        end
    end

    if imgui.BeginCombo then
        orig.BeginCombo = imgui.BeginCombo;
        imgui.BeginCombo = function(label, preview, ...)
            return orig.BeginCombo(M.label(label), M.T(preview), ...);
        end
    end

    if imgui.Begin then
        orig.Begin = imgui.Begin;
        imgui.Begin = function(name, ...)
            return orig.Begin(M.title(name), ...);
        end
    end

    if imgui.BeginPopupModal then
        orig.BeginPopupModal = imgui.BeginPopupModal;
        imgui.BeginPopupModal = function(name, ...)
            return orig.BeginPopupModal(M.title(name), ...);
        end
    end

    if imgui.SliderInt then
        orig.SliderInt = imgui.SliderInt;
        imgui.SliderInt = function(label, ...)
            return orig.SliderInt(M.label(label), ...);
        end
    end

    if imgui.SliderFloat then
        orig.SliderFloat = imgui.SliderFloat;
        imgui.SliderFloat = function(label, ...)
            return orig.SliderFloat(M.label(label), ...);
        end
    end

    if imgui.InputInt then
        orig.InputInt = imgui.InputInt;
        imgui.InputInt = function(label, ...)
            return orig.InputInt(M.label(label), ...);
        end
    end

    if imgui.InputFloat then
        orig.InputFloat = imgui.InputFloat;
        imgui.InputFloat = function(label, ...)
            return orig.InputFloat(M.label(label), ...);
        end
    end

    if imgui.ColorEdit3 then
        orig.ColorEdit3 = imgui.ColorEdit3;
        imgui.ColorEdit3 = function(label, ...)
            return orig.ColorEdit3(M.label(label), ...);
        end
    end

    if imgui.ColorEdit4 then
        orig.ColorEdit4 = imgui.ColorEdit4;
        imgui.ColorEdit4 = function(label, ...)
            return orig.ColorEdit4(M.label(label), ...);
        end
    end

    if imgui.CalcTextSize then
        orig.CalcTextSize = imgui.CalcTextSize;
        imgui.CalcTextSize = function(text, ...)
            return orig.CalcTextSize(M.label(text), ...);
        end
    end
end

local function locale_path()
    local src = debug.getinfo(1, 'S').source or '';
    src = src:gsub('^@', '');
    local dir = src:match('^(.*)[/\\]libs[/\\]i18n%.lua$');
    if dir then
        return dir .. '\\locale\\ja.lua';
    end
    if addon and addon.path then
        return addon.path .. 'locale\\ja.lua';
    end
    return nil;
end

local function load_locale()
    local path = locale_path();
    if not path then
        return nil;
    end
    local f = io.open(path, 'rb');
    if not f then
        return nil;
    end
    local chunk = f:read('*a');
    f:close();
    if not chunk or chunk == '' then
        return nil;
    end
    -- UTF-8 BOM
    if chunk:sub(1, 3) == '\239\187\191' then
        chunk = chunk:sub(4);
    end
    local loader = loadstring or load;
    local fn, err = loader(chunk, '@' .. path);
    if not fn then
        return nil, err;
    end
    local ok, locale = pcall(fn);
    if ok and type(locale) == 'table' then
        return locale;
    end
    return nil;
end

local locale = load_locale();
if locale then
    strings = locale.strings or strings;
    commands = locale.commands or commands;
end

return M;
