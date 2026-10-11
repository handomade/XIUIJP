--[[
    ImGui Text Rendering Library
    Shared text drawing and measurement for modules migrated from GDI fonts.
    Uses Ashita's imgui.AddFontFromFileTTF() for custom font loading and
    ImGui's drawList:AddText API for outlined/plain text rendering.

    Usage:
        local imtext = require('libs.imtext');
        imtext.SetConfigFromSettings(settings.font_settings);
        local w, h = imtext.Measure('Hello', 14);
        imtext.Draw(drawList, 'Hello', x, y, 0xFFFFFFFF, 14);
]]

require('common');
local imgui = require('imgui');
local imguiCjk = require('libs.imgui_cjk');
local resnames = require('libs.resnames');
local bit = require('bit');

local M = {};

-- ImGui fonts render visibly smaller than GDI at the same size; the +2
-- compensates so existing font_height settings (carried over from the GDI
-- era) keep matching their on-screen look. Outline width is taken literally.
local SIZE_OFFSET = 2;

-- Font cache: fontKey -> font handle (loaded once, reused across modules)
local fontCache = {};
local activeFont = nil;
local activeFontKey = '';
local outlineWidth = 2;

local cachedLineHeight = 0;
local lineHeightFrame = -1;
local cachedOutlineCol = nil;

-- Multi-entry color cache keyed by ARGB integer
local colorCache = {};

local pos = {0, 0};

local fontFamilyToFile = {
    arial                    = { regular = 'arial.ttf',    bold = 'arialbd.ttf' },
    calibri                  = { regular = 'calibri.ttf',  bold = 'calibrib.ttf' },
    consolas                 = { regular = 'consola.ttf',  bold = 'consolab.ttf' },
    ['courier new']          = { regular = 'cour.ttf',     bold = 'courbd.ttf' },
    georgia                  = { regular = 'georgia.ttf',  bold = 'georgiab.ttf' },
    ['lucida console']       = { regular = 'lucon.ttf',    bold = 'lucon.ttf' },
    ['microsoft sans serif'] = { regular = 'micross.ttf',  bold = 'micross.ttf' },
    ['segoe ui']             = { regular = 'segoeui.ttf',  bold = 'segoeuib.ttf' },
    tahoma                   = { regular = 'tahoma.ttf',   bold = 'tahomabd.ttf' },
    ['times new roman']      = { regular = 'times.ttf',    bold = 'timesbd.ttf' },
    ['trebuchet ms']         = { regular = 'trebuc.ttf',   bold = 'trebucbd.ttf' },
    verdana                  = { regular = 'verdana.ttf',  bold = 'verdanab.ttf' },
};

local function resolveFontPath(fontFamily, isBold)
    local key = fontFamily:lower():gsub('^%s+', ''):gsub('%s+$', '');
    local variant = isBold and 'bold' or 'regular';
    local mapping = fontFamilyToFile[key];
    local fileName = mapping and mapping[variant] or (key .. '.ttf');
    return 'C:\\Windows\\Fonts\\' .. fileName;
end

--- Resolve a Windows font-file path for a family/weight. Public so other
--- modules (e.g. satchel tooltip fonts) reuse the shared map instead of duplicating it.
function M.ResolveFontPath(fontFamily, isBold)
    return resolveFontPath(fontFamily or 'Tahoma', isBold == true);
end

-- quiet: suppress the failure print (used by prewarm, which probes fonts the
-- user never selected — a missing Windows font there shouldn't spam the console).
local function loadFont(fontFamily, isBold, quiet)
    local fontKey = (fontFamily or 'Tahoma') .. (isBold and ':bold' or ':regular');
    if fontKey == activeFontKey then return; end

    -- Check cache first (font already loaded in a previous call)
    local cached = fontCache[fontKey];
    if cached then
        activeFont = cached;
        activeFontKey = fontKey;
        return;
    end

    -- Not cached — try loading from disk (only attempted once per key)
    if fontCache[fontKey] == false then
        activeFont = nil;
        activeFontKey = fontKey;
        return;
    end

    local path = resolveFontPath(fontFamily or 'Tahoma', isBold);
    local ok, result = pcall(function()
        return imgui.AddFontFromFileTTF(path, 20.0);
    end);
    if ok and result then
        fontCache[fontKey] = result;
        activeFont = result;
        activeFontKey = fontKey;
    else
        fontCache[fontKey] = false;
        activeFont = nil;
        activeFontKey = fontKey;
        if not quiet then
            print(string.format('[XIUI] Failed to load font: %s (%s)', fontKey, path));
        end
    end
end

local function getLineHeight()
    local now = os.clock();
    if now - lineHeightFrame < 0.001 then return cachedLineHeight; end
    lineHeightFrame = now;
    cachedLineHeight = imgui.GetTextLineHeight();
    return cachedLineHeight;
end

local function getOutlineCol()
    if cachedOutlineCol then return cachedOutlineCol; end
    cachedOutlineCol = imgui.GetColorU32({0, 0, 0, 1});
    return cachedOutlineCol;
end

local function argbToU32(argb)
    if not argb then return 0xFFFFFFFF; end
    local cached = colorCache[argb];
    if cached then return cached; end
    cached = imgui.GetColorU32(ARGBToImGui(argb));
    colorCache[argb] = cached;
    return cached;
end

-- Tahoma/Arial have no CJK.  Use the Meiryo face when the default
-- ImGui font does not already contain Japanese glyphs.
local function font_for_text(text)
    if type(text) == 'string' and text:find('[\128-\255]') then
        local cjk = imguiCjk.font();
        if cjk then
            return cjk;
        end
    end
    return activeFont or imgui.GetFont();
end

function M.GetFont(text)
    return font_for_text(text);
end

--- Identity of the active font, for callers that memoize measurements.
function M.GetFontKey()
    return activeFontKey;
end

M.BAKE_PIXEL_SIZE = 20.0;

--- Configure the text renderer from individual parameters.
--- @param fontFamily string Font family name (e.g. 'Tahoma')
--- @param isBold boolean Whether to use bold variant
--- @param ow number Outline width in pixels
function M.SetConfig(fontFamily, isBold, ow)
    loadFont(fontFamily, isBold);
    -- Clamp to [0, 2]. Past 2 the 4-cardinal outline renders as 4 ghosted
    -- copies because the offsets exceed glyph stroke width.
    outlineWidth = math.max(0, math.min(2, ow or 2));
end

--- Apply font settings from a font_settings table (as used by gAdjustedSettings).
--- @param fontSettings table with font_family, font_flags, outline_width
function M.SetConfigFromSettings(fontSettings)
    if not fontSettings then return; end
    local family = fontSettings.font_family or 'Tahoma';
    local flags = fontSettings.font_flags or 0;
    local isBold = bit.band(flags, 1) ~= 0;
    local ow = fontSettings.outline_width or 2;
    M.SetConfig(family, isBold, ow);
end

--- Pre-load every font family/weight pair the user can pick. Call from
--- the addon's `load` event so AddFontFromFileTTF runs once, outside any
--- d3d_present frame. After this, loadFont() becomes a pure cache lookup
--- and the font atlas is never mutated mid-frame. Required for Ashita
--- v4.16 (main lineage), which lacks the Q3 binary patches that let
--- 4.3.x tolerate mid-frame atlas mutation.
--- @param families string[] family names the user can select (e.g. config.components.available_fonts)
function M.PrewarmFonts(families)
    if type(families) ~= 'table' then return; end
    for _, family in ipairs(families) do
        if type(family) == 'string' then
            loadFont(family, false, true);
            loadFont(family, true, true);
        end
    end
    activeFont = nil;
    activeFontKey = '';
end

--- Reset transient frame caches (call on settings change).
--- NOTE: fontCache and activeFont are intentionally NOT cleared. ImFont
--- pointers are owned by ImGui's atlas and remain valid for the addon's
--- lifetime; re-calling AddFontFromFileTTF mid-frame from d3d_present
--- mutates the atlas while drawList entries are pending render, which
--- causes EXCEPTION_ACCESS_VIOLATION. The (family, isBold) cache key
--- already routes new selections without needing a reload.
function M.Reset()
    cachedOutlineCol = nil;
    lineHeightFrame = -1;
    colorCache = {};
end

-- ImGui 1.92 mis-draws AddText(font, size, ...) for a face loaded at another
-- size: Latin survives, Japanese comes out as the wrong glyphs. PushFont
-- is the path the settings window already uses successfully.
local function push_sized(font, fontSize)
    if not font or not fontSize then
        return false;
    end
    local ok = pcall(function() imgui.PushFont(font, fontSize); end);
    if not ok then
        ok = pcall(function() imgui.PushFont(font); end);
    end
    return ok;
end

local widget_utf8 = nil;

local function use_widget_text()
    if widget_utf8 ~= nil then
        return widget_utf8;
    end
    local ver = 0;
    pcall(function()
        ver = AshitaCore:GetPluginManager():Get('addons'):GetInterfaceVersion() or 0;
    end);
    widget_utf8 = ver >= 4.3;
    return widget_utf8;
end

function M.UsesWidgetText()
    return use_widget_text();
end

local function argb_vec(argb)
    argb = argb or 0xFFFFFFFF;
    return {
        bit.band(bit.rshift(argb, 16), 0xFF) / 255,
        bit.band(bit.rshift(argb, 8), 0xFF) / 255,
        bit.band(argb, 0xFF) / 255,
        bit.band(bit.rshift(argb, 24), 0xFF) / 255,
    };
end

-- VanaCore's draw-list text reinterprets Japanese. Widget text keeps the
-- real characters, but it must not be added to the party window: that
-- window auto-sizes, so the list jumps while someone is casting.
-- A separate window leaves the party layout alone and stays in front of
-- the frame. CatsEye stays on the draw list below.
local function try_widget(text, x, y, argbColor, fontSize, outlined)
    if not use_widget_text() or not text:find('[\128-\255]') then
        return false;
    end
    local utf = resnames.ToUtf8(text);
    if fontSize then fontSize = fontSize + SIZE_OFFSET; end
    local font = font_for_text(utf);
    local dw, dh = 3840, 2160;
    pcall(function()
        local disp = imgui.GetIO().DisplaySize;
        if disp and disp.x and disp.x > 0 then
            dw, dh = disp.x, disp.y;
        end
    end);
    local flags = bit.bor(
        ImGuiWindowFlags_NoDecoration,
        ImGuiWindowFlags_NoInputs,
        ImGuiWindowFlags_NoBackground,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoNav
    );
    imgui.SetNextWindowPos({0, 0}, ImGuiCond_Always);
    imgui.SetNextWindowSize({dw, dh}, ImGuiCond_Always);
    imgui.SetNextWindowFocus();
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, {0, 0});
    local beginOk, opened = pcall(function()
        return imgui.Begin('##XIUI_CjkText', true, flags);
    end);
    if not beginOk then
        pcall(function() imgui.PopStyleVar(); end);
        return false;
    end
    local paintOk = false;
    if opened then
        local pushed = push_sized(font, fontSize);
        imgui.PushStyleVar(ImGuiStyleVar_Alpha, 1);
        local col = argb_vec(argbColor);
        local function paint(px, py, c)
            imgui.PushStyleColor(ImGuiCol_Text, c);
            imgui.SetCursorScreenPos({px, py});
            imgui.TextUnformatted(utf);
            imgui.PopStyleColor();
        end
        paintOk = pcall(function()
            if outlined and outlineWidth > 0 then
                local a = col[4];
                local ow = outlineWidth;
                paint(x - ow, y, {0, 0, 0, a});
                paint(x + ow, y, {0, 0, 0, a});
                paint(x, y - ow, {0, 0, 0, a});
                paint(x, y + ow, {0, 0, 0, a});
            end
            paint(x, y, col);
        end);
        pcall(function() imgui.PopStyleVar(); end);
        if pushed then imgui.PopFont(); end
    end
    pcall(imgui.End);
    pcall(function() imgui.PopStyleVar(); end);
    return paintOk;
end

local function draw_text(drawList, font, fontSize, x, y, col, text, pushed)
    pos[1] = x;
    pos[2] = y;
    if pushed then
        drawList:AddText(pos, col, text);
    elseif font and fontSize then
        drawList:AddText(font, fontSize, pos, col, text);
    else
        drawList:AddText(pos, col, text);
    end
end

--- Measure text width and height at the given font size.
--- @param text string
--- @param fontSize number|nil Pixel size (nil uses ImGui default)
--- @return number width, number height
function M.Measure(text, fontSize)
    if not text or text == '' then return 0, 0; end
    -- Width is taken through CalcTextSize, which keeps UTF-8 (same as the
    -- settings widgets). ForDrawList is only for AddText, which still
    -- decodes Shift-JIS and would make this width the garbled one.
    text = resnames.ToUtf8(text);
    if fontSize then fontSize = fontSize + SIZE_OFFSET; end

    local font = font_for_text(text);
    if font and fontSize then
        local pushOk = pcall(function() imgui.PushFont(font, fontSize); end);
        if not pushOk then
            pushOk = pcall(imgui.PushFont, font);
        end
        if pushOk then
            local w = imgui.CalcTextSize(text);
            imgui.PopFont();
            return w, fontSize;
        end
    end

    local defaultHeight = getLineHeight();
    if fontSize and defaultHeight > 0 then
        local scale = fontSize / defaultHeight;
        return imgui.CalcTextSize(text) * scale, fontSize;
    end
    return imgui.CalcTextSize(text), defaultHeight;
end

--- Draw outlined text on an ImGui draw list.
--- @param drawList userdata ImGui draw list
--- @param text string
--- @param x number Screen X position
--- @param y number Screen Y position
--- @param argbColor number ARGB color (e.g. 0xFFFFFFFF)
--- @param fontSize number|nil Pixel size (nil uses ImGui default)
function M.Draw(drawList, text, x, y, argbColor, fontSize)
    if not drawList or not text or text == '' then return; end
    if try_widget(text, x, y, argbColor, fontSize, true) then return; end
    text = resnames.ForDrawList(text);
    if fontSize then fontSize = fontSize + SIZE_OFFSET; end
    local font = font_for_text(text);
    local col = argbToU32(argbColor);
    local ow = outlineWidth;
    local pushed = push_sized(font, fontSize);
    if ow > 0 then
        local outlineCol = getOutlineCol();
        draw_text(drawList, font, fontSize, x - ow, y, outlineCol, text, pushed);
        draw_text(drawList, font, fontSize, x + ow, y, outlineCol, text, pushed);
        draw_text(drawList, font, fontSize, x, y - ow, outlineCol, text, pushed);
        draw_text(drawList, font, fontSize, x, y + ow, outlineCol, text, pushed);
    end
    draw_text(drawList, font, fontSize, x, y, col, text, pushed);
    if pushed then imgui.PopFont(); end
end

--- Draw text without outline.
--- @param drawList userdata
--- @param text string
--- @param x number
--- @param y number
--- @param argbColor number ARGB color
--- @param fontSize number|nil
function M.DrawSimple(drawList, text, x, y, argbColor, fontSize)
    if not drawList or not text or text == '' then return; end
    if try_widget(text, x, y, argbColor, fontSize, false) then return; end
    text = resnames.ForDrawList(text);
    if fontSize then fontSize = fontSize + SIZE_OFFSET; end
    local font = font_for_text(text);
    local col = argbToU32(argbColor);
    local pushed = push_sized(font, fontSize);
    draw_text(drawList, font, fontSize, x, y, col, text, pushed);
    if pushed then imgui.PopFont(); end
end

--- Draw text with a single drop-shadow (2 AddText calls vs Draw's 5).
--- Used by hot per-frame paths (hotbar slots) where the full 4-cardinal
--- outline is too expensive when stacked with another addon also issuing
--- many ImGui primitives. Visually a bottom-right shadow; legibility on
--- bright backgrounds is close to a full outline at a fraction of the cost.
function M.DrawShadow(drawList, text, x, y, argbColor, fontSize)
    if not drawList or not text or text == '' then return; end
    if try_widget(text, x, y, argbColor, fontSize, true) then return; end
    text = resnames.ForDrawList(text);
    if fontSize then fontSize = fontSize + SIZE_OFFSET; end
    local font = font_for_text(text);
    local col = argbToU32(argbColor);
    local ow = outlineWidth;
    local pushed = push_sized(font, fontSize);
    if ow > 0 then
        draw_text(drawList, font, fontSize, x + ow, y + ow, getOutlineCol(), text, pushed);
    end
    draw_text(drawList, font, fontSize, x, y, col, text, pushed);
    if pushed then imgui.PopFont(); end
end

return M;
