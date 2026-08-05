--=================================================================
--  DRIVE Panel — Motorsport UI  (Borderless, Resizable)
--  Theme: Orange / Yellow / Black
--
--  FILE MAP (Ctrl+F the tag to jump)
--    [00] CONFIG .............. all tunable values in one place
--    [01] COLORS .............. theme palette
--    [02] DRAW HELPERS ........ dwBox / bigButton / segToggle / ...
--    [03] KEYBINDS ............ key list + storage + key picker
--    [04] CORE ................ ghost, cooldown, isTyping, placeCar
--    [10] FEATURE: TELEPORT
--    [11] FEATURE: MAP
--    [12] FEATURE: SKINS
--    [13] FEATURE: GRIP
--    [14] FEATURE: BOOST
--    [15] FEATURE: EXTRAS
--    [16] FEATURE: REWIND
--    [17] FEATURE: WEATHER
--    [18] FEATURE: SHADDA POINTS (player-saved spawn letters)
--    [20] NAV ICONS ........... one function per icon
--    [21] TAB REGISTRY ........ add / remove / reorder tabs here
--    [22] PANEL SHELL ......... logo, nav column, header, dispatch
--    [23] REGISTER APP
--    [24] UPDATE LOOP ......... calls each feature's update()
--    [25] SCREEN HUD .......... open hint + ghost + rewind overlays
--=================================================================

math.randomseed(os.time())

--=================================================================
-- [00] CONFIG
--=================================================================
local CFG = {
  LOGO_URL        = "https://i.imgur.com/WOV2nwa.png",
  FONT            = "Segoe UI;Weight=Bold",

  PANEL_W         = 600,
  PANEL_H         = 640,
  PANEL_MIN_W     = 440,
  PANEL_MIN_H     = 420,
  NAV_W           = 140,

  MENU_TOGGLE_KEY = 68,    -- D
  MENU_KEY_LABEL  = "D",
  SHOW_OPEN_HINT  = true,
  START_CLOSED    = true,
  HINT_INTRO_SEC  = 15,

  TP_COOLDOWN     = 3,
  GHOST_TIME      = 10,

  BOOST_TARGET    = 235,

  REWIND_MAX_SEC  = 20.0,
  REWIND_INTERVAL = 0.016,
  REWIND_SPEED    = 2.0,
}

local FONT = CFG.FONT

--=================================================================
-- [01] COLORS
--=================================================================
local CW  = rgbm.colors.white
local CDm = rgbm(0.66, 0.67, 0.70, 1)
local CC  = rgbm(1.00, 0.72, 0.20, 1)
local CY  = rgbm(1.00, 0.84, 0.20, 1)
local CR  = rgbm(0.93, 0.32, 0.20, 1)
local COR = rgbm(1.00, 0.45, 0.06, 1)
local CGR = rgbm(1.00, 0.78, 0.16, 1)
local CPU = rgbm(1.00, 0.60, 0.10, 1)
local ACC = COR
local DK  = rgbm(0.04, 0.03, 0.02, 1)
local BGD = rgbm(0.035, 0.035, 0.042, 0.985)

--=================================================================
-- [02] DRAW HELPERS
--=================================================================
local function dwBox(t, s, x, y, w, h, c)
  ui.pushDWriteFont(FONT); ui.setCursor(vec2(x, y))
  ui.dwriteTextAligned(t, s, ui.Alignment.Center, ui.Alignment.Center, vec2(w, h), false, c or CW)
  ui.popDWriteFont()
end

local function dwRightBox(t, s, x, y, w, h, c)
  ui.pushDWriteFont(FONT); ui.setCursor(vec2(x, y))
  ui.dwriteTextAligned(t, s, ui.Alignment.End, ui.Alignment.Center, vec2(w, h), false, c or CW)
  ui.popDWriteFont()
end

local function dwLeftBox(t, s, x, y, w, h, c)
  ui.pushDWriteFont(FONT); ui.setCursor(vec2(x, y))
  ui.dwriteTextAligned(t, s, ui.Alignment.Start, ui.Alignment.Center, vec2(w, h), false, c or CW)
  ui.popDWriteFont()
end

local dwMono = dwBox

local function sectionTitle(title, eye, X, Y, W)
  dwLeftBox(eye, 11, X, Y + 6, 150, 14, ACC)
  dwRightBox(title, 19, X, Y, W, 24, CW)
  ui.drawRectFilled(vec2(X + W - 38, Y + 27), vec2(X + W, Y + 30), ACC, 2)
end

local function glowRect(x, y, x2, y2, col, rad)
  for s = 4, 1, -1 do
    ui.drawRectFilled(vec2(x - s * 3, y - s * 3), vec2(x2 + s * 3, y2 + s * 3),
      rgbm(col.r, col.g, col.b, 0.055 / s), rad + s * 2)
  end
end

local function bigButton(x, y, w, h, label, col, id)
  ui.setCursor(vec2(x, y))
  local cl = ui.invisibleButton(id or ("##b" .. label), vec2(w, h))
  local hov = ui.itemHovered()
  local c = hov and rgbm(col.r * 1.14, col.g * 1.14, col.b * 1.14, 1) or col
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), c, 10)
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h * 0.5), rgbm(1, 1, 1, 0.10), 10)
  if hov then ui.drawRect(vec2(x, y), vec2(x + w, y + h), rgbm(1, 1, 1, 0.35), 10, nil, 1) end
  dwBox(label, 16, x, y, w, h, DK)
  return cl
end

local function segToggle(x, y, w, h, opts, sel)
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), rgbm(1, 1, 1, 0.05), 10)
  ui.drawRect(vec2(x, y), vec2(x + w, y + h), rgbm(1, 1, 1, 0.08), 10, nil, 1)
  local n = #opts
  local iw = w / n
  local res = sel
  for i = 1, n do
    local ix = x + (i - 1) * iw
    ui.setCursor(vec2(ix, y))
    local cl = ui.invisibleButton("##sg" .. i .. opts[i], vec2(iw, h))
    if sel == i then
      ui.drawRectFilled(vec2(ix + 3, y + 3), vec2(ix + iw - 3, y + h - 3), rgbm(ACC.r, ACC.g, ACC.b, 0.9), 8)
    end
    dwBox(opts[i], 14, ix, y, iw, h, sel == i and DK or CDm)
    if cl then res = i end
  end
  return res
end

local function keyPicker(x, y, w, label, code, onClick)
  ui.setCursor(vec2(x, y))
  local cl  = ui.invisibleButton("##key" .. label, vec2(w, 28))
  local hov = ui.itemHovered()
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + 28), hov and rgbm(1, 1, 1, 0.10) or rgbm(1, 1, 1, 0.05), 8)
  ui.drawRect(vec2(x, y), vec2(x + w, y + 28), rgbm(ACC.r, ACC.g, ACC.b, 0.25), 8, nil, 1)
  dwBox(label .. ": " .. code .. "  (اضغط للتغيير)", 13, x, y, w, 28, CY)
  if cl and onClick then onClick() end
end

--=================================================================
-- [03] KEYBINDS
--=================================================================
local KEY_OPTIONS = {
  { name = 'Caps Lock',  code = 20 }, { name = 'Left Shift', code = 16 },
  { name = 'Left Ctrl',  code = 17 }, { name = 'Left Alt',   code = 18 },
  { name = 'Space',      code = 32 }, { name = 'Tab',        code = 9  },
  { name = 'B',          code = 66 }, { name = 'V',          code = 86 },
  { name = 'N',          code = 78 }, { name = 'G',          code = 71 },
  { name = 'H',          code = 72 }, { name = 'T',          code = 84 },
  { name = 'X',          code = 88 }, { name = 'Z',          code = 90 },
  { name = 'Y',          code = 89 }, { name = 'C',          code = 67 },
}

local keyStore = ac.storage{ boostKey = 20, rewindKey = 89 }

local function keyName(code)
  for _, o in ipairs(KEY_OPTIONS) do if o.code == code then return o.name end end
  return 'Key #' .. code
end

local function nextKey(cur, avoid)
  local idx = 1
  for i, o in ipairs(KEY_OPTIONS) do if o.code == cur then idx = i break end end
  idx = idx % #KEY_OPTIONS + 1
  if avoid and KEY_OPTIONS[idx].code == avoid then idx = idx % #KEY_OPTIONS + 1 end
  return KEY_OPTIONS[idx].code
end

--=================================================================
-- [04] CORE
--=================================================================
local Core = { ghostOn = false, ghostT = 0, cd = 0, clock = 0 }

local function isTyping()
  if type(ui.wantCaptureKeyboard) == "function" and ui.wantCaptureKeyboard() then return true end
  if type(ac.isChatOpen) == "function" and ac.isChatOpen() then return true end
  return false
end

function Core.ghostStart()
  Core.ghostT = CFG.GHOST_TIME
  Core.ghostOn = true
  pcall(function() ac.setCarGhost(0, true) end)
end

function Core.ghostEnd()
  Core.ghostOn = false
  Core.ghostT = 0
  pcall(function() ac.setCarGhost(0, false) end)
end

function Core.startCooldown() Core.cd = CFG.TP_COOLDOWN end
function Core.ready() return Core.cd <= 0 end

function Core.update(dt)
  Core.clock = Core.clock + dt
  if Core.cd > 0 then Core.cd = Core.cd - dt end
  if Core.ghostOn then
    Core.ghostT = Core.ghostT - dt
    if Core.ghostT <= 0 then Core.ghostEnd() end
  end
end

--=================================================================
-- [15] FEATURE: EXTRAS  (Completed)
--=================================================================
local extraKeys   = { "extraA","extraB","extraC","extraD","extraE","extraF","extraG","extraH","extraI" }
local extraLocked = {}
local extraAvail  = {}
local extraInit   = false
for i = 1, #extraKeys do extraLocked[i] = false end

local hazardsLocked = false

local function extrasUpdate()
  local car = ac.getCar(0)
  if not car then return end

  if hazardsLocked then
    local on = false
    if car.hazardLights ~= nil then on = car.hazardLights
    elseif car.turningLights ~= nil then on = (car.turningLights == ac.TurningLights.Hazards) end
    if not on then
      pcall(function() ac.setTurningLights(ac.TurningLights.Hazards) end)
    end
  end

  if not extraInit then
    for i, key in ipairs(extraKeys) do extraAvail[i] = (car[key] ~= nil) end
    extraInit = true
    return
  end
  for i, key in ipairs(extraKeys) do
    if extraAvail[i] and extraLocked[i] and car[key] == false then
      pcall(function() ac.setExtraSwitch(i - 1, true) end)
    end
  end
end

local function drawExtras(X, Y, W, H)
  sectionTitle("الأكسترا", "EXTRAS", X, Y, W)

  local hy, hh = Y + 40, 48
  ui.drawRectFilled(vec2(X, hy), vec2(X + W, hy + hh),
    hazardsLocked and rgbm(ACC.r, ACC.g, ACC.b, 0.16) or rgbm(1, 1, 1, 0.03), 12)
  ui.drawRect(vec2(X, hy), vec2(X + W, hy + hh), rgbm(ACC.r, ACC.g, ACC.b, 0.25), 12, nil, 1)
  dwBox("HAZARDS  ·  الفلشر", 16, 100, hy, W - 114, hh, hazardsLocked and CW or CDm)
  
  local pw, ph, px, py = 76, 30, X + 14, hy + (hh - 30) * 0.5
  ui.setCursor(vec2(px, py))
  local hcl = ui.invisibleButton("##hazbtn", vec2(pw, ph))
  ui.drawRectFilled(vec2(px, py), vec2(px + pw, py + ph),
    hazardsLocked and ACC or rgbm(0.28, 0.29, 0.33, 1), 14)
  dwBox(hazardsLocked and "ON" or "OFF", 14, px, py, pw, ph, hazardsLocked and DK or CW)
  if hcl then
    hazardsLocked = not hazardsLocked
    pcall(function()
      ac.setTurningLights(hazardsLocked and ac.TurningLights.Hazards or ac.TurningLights.None)
    end)
  end

  local listY = hy + hh + 10
  local listH = (Y + H) - listY
  ui.setCursor(vec2(X, listY))
  ui.drawRectFilled(vec2(X, listY), vec2(X + W, listY + listH), rgbm(1, 1, 1, 0.028), 12)
  ui.drawRect(vec2(X, listY), vec2(X + W, listY + listH), rgbm(1, 1, 1, 0.06), 12, nil, 1)
  
  ui.childWindow("##exlist", vec2(W, listH), function()
    local ww = ui.windowWidth()
    local k = 0
    for i, key in ipairs(extraKeys) do
      if extraAvail[i] then
        local ry = k * 50 + 4
        local locked = extraLocked[i]
        
        ui.drawRectFilled(vec2(4, ry), vec2(ww - 4, ry + 46), rgbm(1, 1, 1, 0.04), 8)
        
        -- Toggle Button
        ui.setCursor(vec2(10, ry + 8))
        local t_cl = ui.invisibleButton("##ext" .. i, vec2(80, 30))
        ui.drawRectFilled(vec2(10, ry + 8), vec2(90, ry + 38), locked and ACC or rgbm(0.2, 0.2, 0.2, 1), 8)
        dwBox(locked and "LOCKED" or "AUTO", 12, 10, ry + 8, 80, 30, locked and DK or CW)
        if t_cl then extraLocked[i] = not extraLocked[i] end

        -- Label
        dwRightBox("Extra " .. string.char(64 + i), 16, 100, ry, ww - 110, 46, CW)
        k = k + 1
      end
    end
    if k == 0 then
      dwBox("لا توجد إضافات (Extras) لهذه السيارة", 15, 0, 20, ww, 22, CDm)
    end
  end)
end


--=================================================================
-- [21] TAB REGISTRY & [22] PANEL SHELL
--=================================================================
local activeTab = 1
local tabs = {
  { id = 1, name = "BOOST",     icon = "B", fn = nil }, -- Use drawBoost if included
  { id = 2, name = "EXTRAS",    icon = "E", fn = drawExtras },
  -- Add other features here as they are merged (e.g. drawTeleport, drawMap, drawSkin, drawGrip)
}

local panelVisible = not CFG.START_CLOSED

local function drawMainPanel()
  if not panelVisible then return end
  
  ui.beginTransparentWindow("DrivePanel", vec2(100, 100), vec2(CFG.PANEL_W, CFG.PANEL_H))
  
  -- Background
  ui.drawRectFilled(vec2(0,0), vec2(CFG.PANEL_W, CFG.PANEL_H), BGD, 15)
  ui.drawRect(vec2(0,0), vec2(CFG.PANEL_W, CFG.PANEL_H), rgbm(1,1,1,0.1), 15, nil, 1)
  
  -- Sidebar / Nav
  ui.drawRectFilled(vec2(0,0), vec2(CFG.NAV_W, CFG.PANEL_H), rgbm(0,0,0,0.5), 15)
  dwBox("DRIVE", 24, 0, 20, CFG.NAV_W, 40, ACC)
  
  for i, tab in ipairs(tabs) do
    local ty = 80 + (i-1)*50
    ui.setCursor(vec2(10, ty))
    if ui.invisibleButton("##tab"..i, vec2(CFG.NAV_W-20, 40)) then activeTab = i end
    local isAct = (activeTab == i)
    ui.drawRectFilled(vec2(10, ty), vec2(CFG.NAV_W-10, ty+40), isAct and ACC or rgbm(1,1,1,0.05), 8)
    dwBox(tab.name, 14, 10, ty, CFG.NAV_W-20, 40, isAct and DK or CW)
  end
  
  -- Content Area
  local contentX = CFG.NAV_W + 20
  local contentY = 20
  local contentW = CFG.PANEL_W - CFG.NAV_W - 40
  local contentH = CFG.PANEL_H - 40
  
  if tabs[activeTab] and tabs[activeTab].fn then
    tabs[activeTab].fn(contentX, contentY, contentW, contentH)
  else
    dwBox("Work in progress...", 20, contentX, contentY, contentW, contentH, CDm)
  end
  
  ui.endTransparentWindow()
end

--=================================================================
-- [24] UPDATE LOOP & [25] SCREEN HUD
--=================================================================
function script.update(dt)
  Core.update(dt)
  extrasUpdate()
  
  if not isTyping() and ui.keyboardButtonDown(CFG.MENU_TOGGLE_KEY) then
    if not _menuKeyPrev then panelVisible = not panelVisible end
    _menuKeyPrev = true
  else
    _menuKeyPrev = false
  end
end

function script.drawUI()
  drawMainPanel()
  
  -- Hint UI
  if CFG.SHOW_OPEN_HINT and not panelVisible then
    local text = "اضغط " .. CFG.MENU_KEY_LABEL .. " لفتح قائمة DRIVE"
    dwRightBox(text, 18, ui.windowWidth() - 320, 20, 300, 30, rgbm(1,1,1,0.7))
  end
end
