--[[
* Japanese glyphs for ImGui.
* Ashita boot is_jp already bakes CJK into the default face. Do not PushFont
* over it (a Latin-only Meiryo load turns working UI into ???).
* If the default face has no CJK, merge Meiryo into it (FancyChat approach).
]]--

local imgui = require('imgui');

local M = {
    face = nil,
    size = 18,
    depth = 0,
    merged = false,
    tries = 0,
};

local RANGE_TABLE = {
    0x0020, 0x00FF,
    0x2000, 0x206F,
    0x3000, 0x30FF,
    0x31F0, 0x31FF,
    0x4E00, 0x9FFF,
    0xFF00, 0xFFEF,
    0xFFFD, 0xFFFD,
    0,
};

local function pack_u16le(vals)
    local bytes = {};
    for i, v in ipairs(vals) do
        local n = tonumber(v) or 0;
        bytes[i] = string.char(n % 256, math.floor(n / 256) % 256);
    end
    return table.concat(bytes);
end

local RANGE_BLOB = pack_u16le(RANGE_TABLE);
local HIRAGANA_A = '\227\129\130';

local function file_exists(path)
    local f = io.open(path, 'rb');
    if not f then return false; end
    f:close();
    return true;
end

local function text_width(s)
    local ok, a = pcall(function()
        local x = imgui.CalcTextSize(s);
        if type(x) == 'number' then return x; end
        if type(x) == 'table' and x.x then return x.x; end
        return 0;
    end);
    if ok and type(a) == 'number' then return a; end
    return 0;
end

local function current_has_cjk()
    local wJp = text_width(HIRAGANA_A);
    local wQ = text_width('?');
    return wJp > 0 and wQ > 0 and wJp > wQ * 1.15;
end

local function io_fonts()
    local ok, fonts = pcall(function() return imgui.GetIO().Fonts; end);
    if ok then return fonts; end
    return nil;
end

function M.ranges()
    local fonts = io_fonts();
    if fonts then
        local ok, ptr = pcall(function()
            if fonts.GetGlyphRangesJapanese then
                return fonts:GetGlyphRangesJapanese();
            end
            return fonts.GetGlyphRangesJapanese(fonts);
        end);
        if ok and ptr then return ptr; end
    end
    return RANGE_BLOB;
end

function M.cjk_font_path()
    local install = '';
    pcall(function() install = AshitaCore:GetInstallPath() or ''; end);
    local cands = {
        install .. '\\resources\\fonts\\meiryo.ttc',
        install .. '/resources/fonts/meiryo.ttc',
        'C:\\Windows\\Fonts\\meiryo.ttc',
        'C:\\Windows\\Fonts\\msgothic.ttc',
        'C:\\Windows\\Fonts\\YuGothR.ttc',
        'C:\\Windows\\Fonts\\msyh.ttc',
        'C:\\Windows\\Fonts\\meiryo.ttf',
    };
    for _, path in ipairs(cands) do
        if file_exists(path) then
            return path;
        end
    end
    return nil;
end

local function try_add(path, size, ranges, merge)
    local fonts = io_fonts();
    local cfg = merge and { MergeMode = true, PixelSnapH = true } or nil;
    local attempts = {
        function() return imgui.AddFontFromFileTTF(path, size, cfg, ranges); end,
        function() return imgui.AddFontFromFileTTF(path, size, nil, ranges); end,
    };
    if fonts then
        table.insert(attempts, 1, function()
            return fonts:AddFontFromFileTTF(path, size, cfg, ranges);
        end);
    end
    for _, fn in ipairs(attempts) do
        local ok, result = pcall(fn);
        if ok and result then
            return result;
        end
    end
    return nil;
end

function M.has_cjk()
    return M.merged or current_has_cjk();
end

-- Separate CJK face.  Nil when Japanese is already on the default font.
function M.font()
    return M.face;
end

function M.bake()
    if current_has_cjk() then
        M.merged = true;
        M.face = nil;
        return true;
    end
    if M.merged then
        return true;
    end
    local path = M.cjk_font_path();
    if not path then
        return false;
    end
    local size = 18;
    pcall(function()
        local s = imgui.GetFontSize();
        if type(s) == 'number' and s >= 12 then size = s; end
    end);
    M.size = size;
    -- Own face, not MergeMode. Hotbar labels draw this font at a small
    -- size; a merged face shares Agave's atlas and those glyphs come out wrong.
    local added = try_add(path, size, M.ranges(), false);
    if added then
        -- ImGui 1.92 rasterises the new face on use.  A same-frame
        -- width probe still sees '?' and must not drop the face.
        if current_has_cjk() then
            M.merged = true;
            M.face = nil;
        else
            M.face = added;
        end
        return true;
    end
    return false;
end

-- load may run before ImGui will accept a font.  present retries once.
-- A face we already loaded stays: HUD text asks for it by handle.
function M.ensure()
    if M.face then
        return;
    end
    if M.merged or current_has_cjk() then
        M.merged = true;
        return;
    end
    if M.tries >= 2 then
        return;
    end
    M.tries = M.tries + 1;
    M.bake();
end

function M.merge(size)
    return try_add(M.cjk_font_path(), size or 20.0, M.ranges(), true);
end

function M.push()
    if not M.face then
        if M.merged or current_has_cjk() then
            M.merged = true;
        end
        return false;
    end
    local ok = pcall(function()
        imgui.PushFont(M.face, M.size);
    end);
    if not ok then
        ok = pcall(function() imgui.PushFont(M.face); end);
    end
    if ok then
        M.depth = M.depth + 1;
        return true;
    end
    return false;
end

function M.pop()
    if M.depth <= 0 then return; end
    pcall(function() imgui.PopFont(); end);
    M.depth = M.depth - 1;
end

return M;
