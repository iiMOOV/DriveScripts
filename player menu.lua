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
--
--  RULE: every feature block owns its own state, logic and UI.
--  To change one feature, edit only its block.
--=================================================================

math.randomseed(os.time())

--=================================================================
-- [00] CONFIG
--=================================================================
local CFG = {
  -- شعارك: رابط PNG أو مسار ملف. فاضي = كلمة DRIVE.
  LOGO_URL        = "https://i.imgur.com/WOV2nwa.png",
  -- الخط (بدائل مضمونة: "Tahoma;Weight=Bold" / "Arial;Weight=Bold")
  FONT            = "Segoe UI;Weight=Bold",

  PANEL_W         = 600,
  PANEL_H         = 640,
  PANEL_MIN_W     = 440,
  PANEL_MIN_H     = 420,
  NAV_W           = 140,

  MENU_TOGGLE_KEY = 68,    -- D = فتح/غلق القائمة  (لرجوعها للباك سلاش: 220)
  MENU_KEY_LABEL  = "D",   -- الاسم المعروض في الواجهة والتنبيه
  SHOW_OPEN_HINT  = true,  -- شعار "اضغط D لفتح القائمة" فوق الشاشة
  START_CLOSED    = true,  -- ندخل السيرفر والقائمة مقفولة = التنبيه يبان من أول لحظة
  HINT_INTRO_SEC  = 15,    -- أول كم ثانية بعد الدخول يكون التنبيه أكبر وأوضح

  TP_COOLDOWN     = 3,     -- ثواني بين كل انتقال
  GHOST_TIME      = 10,    -- ثواني الحماية بعد الانتقال

  BOOST_TARGET    = 235,   -- كم/س — افتراضي أول مرة فقط (بعدها من تبويب البوست)

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
-- [02] DRAW HELPERS  (كلها بخط FONT العريض)
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

-- منتقي مفتاح موحّد (يستخدمه البوست والريوايند)
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
--   كل المفاتيح هنا. تبي تضيف مفتاح جديد للقائمة؟ زده في KEY_OPTIONS.
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

-- مخزن واحد لكل المفاتيح (نفس أسماء الحقول القديمة = الإعدادات المحفوظة ما تضيع)
local keyStore = ac.storage{ boostKey = 20, rewindKey = 89 }

local function keyName(code)
  for _, o in ipairs(KEY_OPTIONS) do if o.code == code then return o.name end end
  return 'Key #' .. code
end

-- ينقل للمفتاح اللي بعده، ويتخطى المفتاح المحجوز (avoid)
local function nextKey(cur, avoid)
  local idx = 1
  for i, o in ipairs(KEY_OPTIONS) do if o.code == cur then idx = i break end end
  idx = idx % #KEY_OPTIONS + 1
  if avoid and KEY_OPTIONS[idx].code == avoid then idx = idx % #KEY_OPTIONS + 1 end
  return KEY_OPTIONS[idx].code
end

--=================================================================
-- [04] CORE  (حماية الشبح + كولداون الانتقال + أدوات مشتركة)
--=================================================================
local Core = {
  ghostOn = false,
  ghostT  = 0,
  cd      = 0,   -- كولداون الانتقال
  clock   = 0,   -- يتقدّم كل فريم حتى لو النافذة مخفية
}

-- true لو اللاعب يكتب في الشات أو في خانة نص (نمنع المفاتيح وقتها)
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

function Core.placeCarOnGround(x, z, fwd, el)
  el = el or 0.8
  local cH = 5000
  local d = physics.raycastTrack(vec3(x, cH, z), vec3(0, -1, 0), cH + 20)
  local f = vec3(fwd.x, 0, fwd.z)
  if f:length() < 1e-3 then f = vec3(0, 0, 1) else f = f:normalize() end
  if d ~= -1 then
    physics.setCarVelocity(0, vec3(0, 0, 0))
    physics.setCarPosition(0, vec3(x, cH - d + el, z), f)
  else
    physics.setCarVelocity(0, vec3(0, 0, 0))
    physics.setCarPosition(0, vec3(x, ac.getCar(0).position.y + 1, z), f)
  end
end

function Core.update(dt)
  Core.clock = Core.clock + dt
  if Core.cd > 0 then Core.cd = Core.cd - dt end
  if Core.ghostOn then
    Core.ghostT = Core.ghostT - dt
    if Core.ghostT <= 0 then Core.ghostEnd() end
  end
end

--=================================================================
-- [10] FEATURE: TELEPORT  (الانتقال إلى لاعب)
--=================================================================
local tpSel  = -1   -- index اللاعب المختار
local tpMode = 1    -- 1 = واقف ، 2 = بنفس السرعة

local function tpBehindStopped(car)
  local d = car.look
  physics.setCarVelocity(0, vec3(0, 0, 0))
  physics.setCarPosition(0, car.position + vec3(0, 0.1, 0) - d * 8, -d)
  Core.ghostStart()
end

local function tpBehindSameSpeed(car)
  local d = car.look
  physics.setCarPosition(0, car.position + vec3(0, 0.1, 0) - d * 8, -d)
  physics.setCarVelocity(0, car.velocity or vec3(0, 0, 0))
  Core.ghostStart()
end

local function drawTeleport(X, Y, W, H)
  sectionTitle("الانتقال إلى لاعب", "TELEPORT", X, Y, W)
  local btnH  = 40
  local btnY  = Y + H - btnH
  local togH  = 34
  local togY  = btnY - 12 - togH
  local listY = Y + 40
  local listH = (togY - 12) - listY

  ui.setCursor(vec2(X, listY))
  ui.drawRectFilled(vec2(X, listY), vec2(X + W, listY + listH), rgbm(1, 1, 1, 0.028), 12)
  ui.drawRect(vec2(X, listY), vec2(X + W, listY + listH), rgbm(1, 1, 1, 0.06), 12, nil, 1)
  ui.childWindow("##plist", vec2(W, listH), function()
    local ww = ui.windowWidth()
    local k = 0
    for i = 1, ac.getSim().carsCount - 1 do
      local c = ac.getCar(i)
      local n = ac.getDriverName(i)
      if c and c.isConnected and not c.isAIControlled and n ~= "1980" and not string.find(n or "", "Traffic") then
        local ry = k * 46 + 4
        ui.setCursor(vec2(4, ry))
        local cl  = ui.invisibleButton("##pl" .. i, vec2(ww - 14, 42))
        local hov = ui.itemHovered()
        local sel = tpSel == i
        if sel then
          ui.drawRectFilled(vec2(4, ry), vec2(ww - 10, ry + 42), rgbm(ACC.r, ACC.g, ACC.b, 0.16), 8)
          ui.drawRectFilled(vec2(ww - 13, ry + 9), vec2(ww - 10, ry + 33), ACC, 2)
        elseif hov then
          ui.drawRectFilled(vec2(4, ry), vec2(ww - 10, ry + 42), rgbm(1, 1, 1, 0.05), 8)
        end
        ui.drawRectFilled(vec2(10, ry + 10), vec2(64, ry + 32), rgbm(0, 0, 0, 0.4), 6)
        dwMono(tostring(math.floor(c.speedKmh or 0)), 15, 10, ry + 10, 54, 22, CY)
        dwRightBox(n, 16, 70, ry, ww - 82, 42, sel and CW or rgbm(0.86, 0.87, 0.9, 1))
        if cl then tpSel = i end
        k = k + 1
      end
    end
    if k == 0 then dwBox("لا يوجد لاعبين متصلين", 15, 0, 16, ww, 22, CDm) end
    ui.dummy(vec2(1, k * 46 + 8))
  end)

  tpMode = segToggle(X, togY, W, togH, { "واقف", "بنفس السرعة" }, tpMode)

  local can = tpSel >= 1 and Core.ready()
  if can then glowRect(X, btnY, X + W, btnY + btnH, ACC, 10) end
  if bigButton(X, btnY, W, btnH, "انتقال", can and ACC or rgbm(0.24, 0.25, 0.30, 1), "##tpgo") and can then
    local c = ac.getCar(tpSel)
    if c and c.isConnected then
      if tpMode == 2 then tpBehindSameSpeed(c) else tpBehindStopped(c) end
      Core.startCooldown()
    end
  end
end

--=================================================================
-- [11] FEATURE: MAP  (خريطة الحلبة + انتقال بالدبل كليك)
--=================================================================
local mapReady   = false
local mapImage   = nil
local mapIniVals = {}
local mapImgSize, mapOffset
local mapPad   = vec2(60, 60)
local mapOfs   = -mapPad * 0.5
local mapScale, mapCarScale, mapDrawSize
local mapFirst = true
local mapTri   = 8
local mp3, md3 = vec3(), vec3()
local mp2, md2, mdx2 = vec2(), vec2(), vec2()

-- تحميل الخريطة مرة وحدة عند تشغيل السكربت (محمي حتى لا يطيح السكربت لو الحلبة بلا map.ini)
if ac.getPatchVersionCode() >= 2000 then
  pcall(function()
    local trackDir = ac.getFolder(ac.FolderID.ContentTracks) .. '/' .. ac.getTrackFullID('/')
    mapImage = trackDir .. '/map.png'
    ui.decodeImage(mapImage)
    local ini = trackDir .. "/data/map.ini"
    for a, b in ac.INIConfig.load(ini):serialize():gmatch("([_%a]+)=([-%d.]+)") do
      mapIniVals[a] = tonumber(b)
    end
    mapImgSize = ui.imageSize(mapImage)
    if mapIniVals.SCALE_FACTOR and mapIniVals.X_OFFSET and mapIniVals.Z_OFFSET and mapImgSize then
      mapOffset = vec2(mapIniVals.X_OFFSET, mapIniVals.Z_OFFSET)
      mapReady = true
    end
  end)
end

local function drawMap(X, Y, W, H)
  sectionTitle("الخريطة", "MAP", X, Y, W)
  dwRightBox("دبل كليك للانتقال · بكرة للتكبير", 12, X, Y + 26, W - 44, 14, CDm)
  local mY = Y + 44
  local mH = H - 44
  ui.setCursor(vec2(X, mY))
  ui.childWindow("##mapc", vec2(W, mH), function()
    if ac.getPatchVersionCode() < 2000 then
      dwBox("CSP 2000+", 15, 0, 10, ui.windowWidth(), 22, CR); return
    end
    if not mapReady then
      dwBox("لا توجد خريطة لهذه الحلبة", 15, 0, 10, ui.windowWidth(), 22, CR); return
    end

    if mapFirst then
      mapScale = math.min((ui.windowWidth() - mapPad.x) / mapImgSize.x,
                          (ui.windowHeight() - mapPad.y) / mapImgSize.y)
      mapCarScale = mapScale / mapIniVals.SCALE_FACTOR
      mapDrawSize = mapImgSize * mapScale
      if ui.isImageReady(mapImage) then mapFirst = false end
    end

    ui.drawImage(mapImage, -mapOfs, -mapOfs + mapDrawSize)

    -- زوم بالبكرة
    if ui.windowHovered() and ac.getUI().mouseWheel ~= 0 then
      local w = ac.getUI().mouseWheel
      if (w < 0 and mapDrawSize.x + mapPad.x > ui.windowWidth() and mapDrawSize.y + mapPad.y > ui.windowHeight()) or w > 0 then
        local old = mapDrawSize
        mapScale = mapScale * (1 + w * 0.15)
        mapDrawSize = mapImgSize * mapScale
        mapCarScale = mapScale / mapIniVals.SCALE_FACTOR
        mapOfs = mapOfs + (mapDrawSize - old) * (mapOfs + ui.mouseLocalPos()) / old
      else
        mapOfs = -mapPad * 0.5
        mapScale = math.min((ui.windowWidth() - mapPad.x) / mapImgSize.x,
                            (ui.windowHeight() - mapPad.y) / mapImgSize.y)
        mapDrawSize = mapImgSize * mapScale
        mapCarScale = mapScale / mapIniVals.SCALE_FACTOR
      end
    end

    -- بقية اللاعبين
    for i = ac.getSim().carsCount - 1, 1, -1 do
      local c = ac.getCar(i)
      if c and c.isConnected and not c.isHidingLabels then
        mp2:set(c.position.x, c.position.z):add(mapOffset):scale(mapCarScale):add(-mapOfs)
        md2:set(c.look.x, c.look.z); mdx2:set(c.look.z, -c.look.x)
        ui.drawTriangleFilled(mp2 + md2 * mapTri,
                              mp2 - md2 * mapTri - mdx2 * mapTri * 0.75,
                              mp2 - md2 * mapTri + mdx2 * mapTri * 0.75, rgbm(0.95, 0.25, 0.15, 1))
      end
    end

    -- سيارتك
    mp3 = ac.getCameraPosition()
    mp2:set(mp3.x, mp3.z):add(mapOffset):scale(mapCarScale):add(-mapOfs)
    md3 = ac.getCameraForward()
    md2 = vec2(md3.x, md3.z):normalize()
    mdx2:set(md3.z, -md3.x):normalize()
    local sc = Core.ghostOn and rgbm(1.00, 0.84, 0.20, 1) or rgbm(1.00, 0.45, 0.06, 1)
    ui.drawTriangleFilled(mp2 + md2 * mapTri,
                          mp2 - md2 * mapTri - mdx2 * mapTri * 0.75,
                          mp2 - md2 * mapTri + mdx2 * mapTri * 0.75, sc)

    -- دبل كليك = انتقال
    if ui.mouseDoubleClicked(ui.MouseButton.Left) and ui.windowHovered() and Core.ready() then
      local cp = (ui.mouseLocalPos() + mapOfs) / mapCarScale - mapOffset
      Core.placeCarOnGround(cp.x, cp.y, ac.getCameraForward(), 0.8)
      Core.ghostStart()
      Core.startCooldown()
    end

    -- سحب الخريطة
    ui.invisibleButton('###md', ui.windowSize())
    if ui.mouseDown() and ui.itemHovered() then mapOfs = mapOfs - ui.mouseDelta() end
  end)
end

--=================================================================
-- [12] FEATURE: SKINS  (تطبيق بالاسم + مزامنة أونلاين)
--   تنبيه: لا تغيّر شكل syncCarSkin — تغييره يكسر التوافق مع
--   اللاعبين اللي معهم النسخة القديمة من السكربت.
--=================================================================
local skinCarDir   = ac.getFolder(ac.FolderID.ContentCars) .. '/' .. ac.getCarID(0)
local skinList     = {}
local skinCurrent  = ac.getCarSkinID(0)
local skinOriginal = skinCurrent
local skinRemote   = {}

pcall(function()
  io.scanDir(skinCarDir .. '/skins', '*', function(fn)
    if io.dirExists(skinCarDir .. '/skins/' .. fn) then table.insert(skinList, { name = fn }) end
  end)
end)
table.sort(skinList, function(a, b) return a.name < b.name end)

local function skinSanitize(name)
  if type(name) ~= 'string' or name == '' then return nil end
  if name:find('[/\\]') or name:find('%.%.') then return nil end
  if not io.dirExists(skinCarDir .. '/skins/' .. name) then return nil end
  return name
end

local function skinApplyTextures(carNode, folder)
  local mapping = {}
  io.scanDir(folder, '*', function(fn)
    local l = fn:lower()
    if l == 'livery.png' or l == 'livery.jpg' or l == 'preview.jpg' or l == 'preview.png'
       or l == 'ui_skin.json' or l == 'cm_skin.json' then return end
    if l:match('%.dds$') or l:match('%.png$') or l:match('%.jpg$') or l:match('%.jpeg$') then
      mapping[fn] = folder .. '/' .. fn
    end
  end)
  if next(mapping) then carNode:applySkin(mapping) end
end

local function skinApply(skinName, carIndex)
  local carNode = ac.findNodes('carRoot:' .. carIndex)
  if not carNode or #carNode == 0 then return end

  -- امسح السكن الحالي كامل (يرجّع الألوان والانعكاسات الأصلية)
  carNode:resetSkin()

  if skinName ~= skinOriginal then
    -- 1) الطريقة الصحيحة: تطبيق بالاسم (يحمّل السكن كامل بألوانه)
    pcall(function() carNode:applySkin(skinName) end)
    -- 2) تعزيز/بديل: تبديل التكستشرات من مجلد السكن (لو الاسم ما كفى)
    skinApplyTextures(carNode, skinCarDir .. '/skins/' .. skinName)
  end

  ac.refreshCarColor(carIndex)
end

local syncCarSkin = ac.OnlineEvent({
  msgType = ac.StructItem.byte(),
  skin    = ac.StructItem.string(120),
}, function(sender, data)
  if not sender or sender.index == 0 then return end
  if data.msgType == 1 then
    if skinCurrent ~= skinOriginal then
      setTimeout(function() syncCarSkin({ msgType = 0, skin = skinCurrent }) end, math.random() * 1.5)
    end
    return
  end
  local skin = skinSanitize(data.skin)
  if not skin then return end
  if skinRemote[sender.index] == skin then return end
  skinRemote[sender.index] = skin
  skinApply(skin, sender.index)
end)

local function skinAnnounce(skin)
  syncCarSkin({ msgType = 0, skin = skin })
  setTimeout(function() if skinCurrent == skin then syncCarSkin({ msgType = 0, skin = skin }) end end, 1.5)
end

local function skinChange(newSkin)
  if not newSkin or newSkin == skinCurrent then return end
  skinApply(newSkin, 0)
  skinCurrent = newSkin
  skinAnnounce(newSkin)
end

local skinReqSent = 0
local function skinRequestAll()
  if skinReqSent >= 2 then return end
  skinReqSent = skinReqSent + 1
  syncCarSkin({ msgType = 1, skin = '' })
  setTimeout(skinRequestAll, 6.0)
end
setTimeout(skinRequestAll, 3.0)

local function drawSkin(X, Y, W, H)
  sectionTitle("سكنات السيارة", "LIVERY", X, Y, W)
  local byH   = 38
  local byY   = Y + H - byH
  local gridY = Y + 40
  local gridH = (byY - 10) - gridY
  ui.setCursor(vec2(X, gridY))
  ui.childWindow("##skg", vec2(W, gridH), function()
    local ww = ui.windowWidth()
    if #skinList == 0 then dwBox("لا توجد سكنات", 15, 0, 16, ww, 22, CY); return end
    local cols = 2
    local cw = (ww - 8 - (cols - 1) * 6) / cols
    local ch = cw * 0.5
    for i, skin in ipairs(skinList) do
      local col = (i - 1) % cols
      local row = math.floor((i - 1) / cols)
      local cx  = 3 + col * (cw + 6)
      local cyy = row * (ch + 22)
      local sel = skinCurrent == skin.name
      ui.setCursor(vec2(cx, cyy))
      local cl  = ui.invisibleButton("##sk" .. i, vec2(cw, ch + 18))
      local hov = ui.itemHovered()
      local pp  = skinCarDir .. '/skins/' .. skin.name .. '/preview.jpg'
      if ui.isImageReady(pp) then
        ui.setCursor(vec2(cx, cyy)); ui.image(pp, vec2(cw, ch))
      else
        ui.decodeImage(pp)
        ui.drawRectFilled(vec2(cx, cyy), vec2(cx + cw, cyy + ch), rgbm(1, 1, 1, 0.05), 8)
        dwBox("...", 13, cx, cyy, cw, ch, CDm)
      end
      ui.drawRectFilled(vec2(cx, cyy), vec2(cx + cw, cyy + ch * 0.35), rgbm(1, 1, 1, 0.10), 8)
      if sel then ui.drawRect(vec2(cx, cyy), vec2(cx + cw, cyy + ch), ACC, 8, nil, 3)
      elseif hov then ui.drawRect(vec2(cx, cyy), vec2(cx + cw, cyy + ch), rgbm(1, 1, 1, 0.4), 8, nil, 1.5)
      else ui.drawRect(vec2(cx, cyy), vec2(cx + cw, cyy + ch), rgbm(1, 1, 1, 0.12), 8, nil, 1) end
      dwBox(skin.name, 11, cx, cyy + ch + 2, cw, 15, sel and ACC or CDm)
      if cl then skinChange(skin.name) end
    end
    ui.dummy(vec2(1, math.ceil(#skinList / 2) * (ch + 22) + 4))
  end)

  local bw = (W - 8) / 2
  if bigButton(X, byY, bw, byH, "الأصلي", rgbm(0.24, 0.25, 0.30, 1), "##skdef") then
    skinChange(skinOriginal)
  end
  if bigButton(X + bw + 8, byY, bw, byH, "عشوائي", ACC, "##skrnd") then
    if #skinList > 0 then
      local r = skinList[math.random(#skinList)]
      if r then skinChange(r.name) end
    end
  end
end

--=================================================================
-- [13] FEATURE: GRIP  (التماسك: gripVal ∈ [-1,1] يمين خشن / يسار ناعم)
--=================================================================
local gripVal = 0.0

local function gripApply()
  pcall(function() physics.setGripDecrease(0, ac.Wheel.All, -gripVal * 0.7) end)
end

local function drawGrip(X, Y, W, H)
  local stackH = 34 + 64 + 40 + 48 + 40
  local sy = Y + math.max(0, (H - stackH) * 0.5)
  sectionTitle("التماسك", "TRACTION", X, sy, W); sy = sy + 50

  local lbl, lc = "عادي", CDm
  if gripVal > 0.02 then lbl, lc = "خشن / تماسك", CGR
  elseif gripVal < -0.02 then lbl, lc = "ناعم / زلق", COR end
  dwMono(string.format("%+.2f", gripVal), 52, X, sy, W, 52, lc); sy = sy + 54
  dwBox(lbl, 15, X, sy, W, 18, lc); sy = sy + 28

  dwLeftBox("ناعم ←", 13, X, sy - 2, 80, 18, CDm)
  dwRightBox("→ خشن", 13, X + W - 80, sy - 2, 80, 18, CDm)
  ui.setCursor(vec2(X, sy)); ui.setNextItemWidth(W)
  local nv, changed = ui.slider("##grp", gripVal, -1.0, 1.0, "")
  if changed then gripVal = math.clamp(nv, -1, 1); gripApply() end
  ui.drawRectFilled(vec2(X + W * 0.5 - 1, sy - 3), vec2(X + W * 0.5 + 1, sy + 22), rgbm(1, 1, 1, 0.3), 1)
  sy = sy + 46

  local presets = { { "زلق", -1.0 }, { "عادي", 0.0 }, { "خشن", 1.0 } }
  local bw = (W - 16) / 3
  for i = 1, 3 do
    local bx = X + (i - 1) * (bw + 8)
    ui.setCursor(vec2(bx, sy))
    local cl = ui.invisibleButton("##gp" .. i, vec2(bw, 38))
    local on = math.abs(gripVal - presets[i][2]) < 0.001
    ui.drawRectFilled(vec2(bx, sy), vec2(bx + bw, sy + 38),
      on and rgbm(ACC.r, ACC.g, ACC.b, 0.85) or rgbm(1, 1, 1, 0.05), 10)
    dwBox(presets[i][1], 15, bx, sy, bw, 38, on and DK or CW)
    if cl then gripVal = presets[i][2]; gripApply() end
  end
end

--=================================================================
-- [14] FEATURE: BOOST  (toggle · anti-fly · adjustable speed/smoothing)
--   Press once = ON, press again = OFF. Braking cancels it.
--   Target speed slider 185-320. Instant or Gradual acceleration.
--   Only the settings UI was restyled to match the panel — the
--   behavior is identical to the tuned version.
--=================================================================
local BOOST_MIN_KMH = 5

-- persisted so settings survive a rejoin
local boostStore = ac.storage{
  mode        = 1,      -- 1 = Instant , 2 = Gradual
  accelPower  = 15.0,   -- smoothing (Gradual only)
  cooldown    = 5.0,    -- seconds
  targetSpeed = 230.0,  -- km/h
}

local boostCd       = 0
local boostPrevKey  = false
local boostPulse    = 0
local boostBtnLatch = false
local isBoostActive = false

local function getFlatDirection(car)
  local f = vec3(car.look.x, 0, car.look.z)
  if f:length() < 1e-3 then return vec3(0, 0, 1) end
  return f:normalize()
end

local function stopBoost()
  if not isBoostActive then return end
  isBoostActive = false
  boostCd = boostStore.cooldown
  ui.toast(ui.Icons.Warning, "DT Drive: Boost Deactivated - Cooldown Started")
end

local function startBoost()
  local car = ac.getCar(0)
  if not car then return false end
  if car.speedKmh < BOOST_MIN_KMH then
    ui.toast(ui.Icons.Warning, "DT Drive: Speed must be over 5 km/h!")
    return false
  end
  isBoostActive = true
  Core.ghostStart()
  ui.toast(ui.Icons.Confirm, "DT Drive: Boost Activated!")
  return true
end

local function toggleBoost()
  if isBoostActive then stopBoost()
  elseif boostCd <= 0 then startBoost() end
end

local function boostUpdate(dt)
  boostPulse = boostPulse + dt
  local car = ac.getCar(0)

  if boostCd > 0 and not isBoostActive then boostCd = boostCd - dt end

  if isBoostActive and car then
    if car.brake > 0.05 then
      stopBoost()
    else
      local target_ms = boostStore.targetSpeed / 3.6
      local flatLook  = getFlatDirection(car)
      local currentVel = car.velocity
      local targetVel  = flatLook * target_ms
      targetVel.y = currentVel.y
      if boostStore.mode == 1 then
        physics.setCarVelocity(0, targetVel)
      else
        local newVel = math.lerp(currentVel, targetVel, math.min(1, dt * boostStore.accelPower))
        newVel.y = currentVel.y
        physics.setCarVelocity(0, newVel)
      end
    end
  end

  local down = (not isTyping()) and ui.keyboardButtonDown(keyStore.boostKey)
  if down and not boostPrevKey then toggleBoost() end
  boostPrevKey = down
end

-- panel-styled labelled slider (same look as the rest of the panel)
local function boostSlider(label, x, y, w, id, val, mn, mx, fmt)
  dwLeftBox(label, 13, x, y, 260, 16, ACC)
  ui.setCursor(vec2(x, y + 18))
  ui.setNextItemWidth(w)
  ui.pushStyleColor(ui.StyleColor.SliderGrab, ACC)
  ui.pushStyleColor(ui.StyleColor.FrameBg, rgbm(1, 1, 1, 0.05))
  local nv = ui.slider(id, val, mn, mx, fmt)
  ui.popStyleColor(2)
  return nv
end

local function drawBoost(X, Y, W, H)
  local car = ac.getCar(0)
  local spd = car and math.floor(car.speedKmh) or 0

  sectionTitle("BOOST", "BOOST", X, Y, W)

  -- ===== speed card =====
  local cardH = 84
  local sy    = Y + 46
  ui.drawRectFilled(vec2(X, sy), vec2(X + W, sy + cardH), rgbm(1, 1, 1, 0.05), 14)
  ui.drawRectFilled(vec2(X, sy), vec2(X + W, sy + cardH * 0.5), rgbm(1, 1, 1, 0.03), 14)
  ui.drawRect(vec2(X, sy), vec2(X + W, sy + cardH), rgbm(ACC.r, ACC.g, ACC.b, 0.28), 14, nil, 1)
  dwBox("Current Speed", 12, X, sy + 8, W, 14, CDm)
  dwMono(tostring(spd), 42, X, sy + 22, W, 42, CC)
  dwBox(string.format("km/h   ·   Target %d", math.floor(boostStore.targetSpeed)), 11, X, sy + 62, W, 12, CDm)
  local pct = math.min(spd / math.max(boostStore.targetSpeed, 1), 1)
  local by  = sy + cardH - 9
  ui.drawRectFilled(vec2(X + 16, by), vec2(X + W - 16, by + 3), rgbm(0, 0, 0, 0.45), 2)
  if pct > 0 then
    ui.drawRectFilled(vec2(X + 16, by), vec2(X + 16 + (W - 32) * pct, by + 3), pct >= 1 and CGR or COR, 2)
  end

  -- ===== square button =====
  local BS  = 118
  local bx  = X + (W - BS) * 0.5
  local byy = sy + cardH + 16
  ui.setCursor(vec2(bx, byy))
  local cl  = ui.invisibleButton("##bst", vec2(BS, BS))
  local act = ui.itemActive()
  local hov = ui.itemHovered()

  local clicked = false
  if (cl or act) and not boostBtnLatch then
    boostBtnLatch = true
    clicked = true
  elseif not act and not cl then
    boostBtnLatch = false
  end

  if isBoostActive then
    glowRect(bx, byy, bx + BS, byy + BS, CGR, 18)
    local pulse = 0.90 + 0.10 * math.sin(boostPulse * 10)
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(CGR.r * pulse, CGR.g * pulse, CGR.b * pulse, 1), 18)
    ui.drawRect(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(1, 1, 1, 0.6), 18, nil, 2)
    dwBox("ACTIVE", 24, bx, byy + BS * 0.5 - 16, BS, 32, CW)
    if clicked then stopBoost() end

  elseif boostCd > 0 then
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(1, 1, 1, 0.06), 18)
    local pr = 1 - boostCd / math.max(boostStore.cooldown, 0.01)
    ui.drawRectFilled(vec2(bx, byy + BS * (1 - pr)), vec2(bx + BS, byy + BS), rgbm(CPU.r, CPU.g, CPU.b, 0.22), 18)
    ui.drawRect(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(1, 1, 1, 0.14), 18, nil, 1)
    dwMono(string.format("%.1f", boostCd), 34, bx, byy + BS * 0.5 - 26, BS, 38, CW)
    dwBox("SEC", 12, bx, byy + BS * 0.5 + 14, BS, 16, CDm)

  else
    glowRect(bx, byy, bx + BS, byy + BS, COR, 18)
    local pulse = 0.90 + 0.10 * math.sin(boostPulse * 4)
    local col = hov and rgbm(1, 0.58, 0.20, 1) or rgbm(COR.r * pulse + 0.05, COR.g * pulse, COR.b * pulse, 1)
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS), col, 18)
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS * 0.5), rgbm(1, 1, 1, 0.16), 18)
    ui.drawRect(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(1, 1, 1, 0.32), 18, nil, 2)
    local ln = 12
    for _, cc in ipairs({ { bx + 10, byy + 10, 1, 1 }, { bx + BS - 10, byy + 10, -1, 1 },
                          { bx + 10, byy + BS - 10, 1, -1 }, { bx + BS - 10, byy + BS - 10, -1, -1 } }) do
      ui.drawLine(vec2(cc[1], cc[2]), vec2(cc[1] + ln * cc[3], cc[2]), rgbm(0, 0, 0, 0.5), 2)
      ui.drawLine(vec2(cc[1], cc[2]), vec2(cc[1], cc[2] + ln * cc[4]), rgbm(0, 0, 0, 0.5), 2)
    end
    dwBox("BOOST", 24, bx, byy + BS * 0.5 - 16, BS, 32, DK)
    if clicked then startBoost() end
  end

  -- status line
  if spd < BOOST_MIN_KMH and boostCd <= 0 and not isBoostActive then
    dwBox("Speed must be over 5 km/h", 13, X, byy + BS + 8, W, 18, CR)
  else
    local statusText = isBoostActive and "Brake to stop"
      or string.format("Ready  ·  %d km/h", math.floor(boostStore.targetSpeed))
    dwBox(statusText, 13, X, byy + BS + 8, W, 18, CC)
  end

  -- ===== settings panel (scrolls if window is short) =====
  local gy   = byy + BS + 30
  local setH = math.max((Y + H - 38) - gy, 70)
  ui.setCursor(vec2(X, gy))
  ui.drawRectFilled(vec2(X, gy), vec2(X + W, gy + setH), rgbm(1, 1, 1, 0.028), 12)
  ui.drawRect(vec2(X, gy), vec2(X + W, gy + setH), rgbm(1, 1, 1, 0.06), 12, nil, 1)
  ui.childWindow("##bset", vec2(W, setH), function()
    local ww = ui.windowWidth() - 20
    local ly = 8

    -- acceleration mode
    dwLeftBox("Acceleration", 13, 10, ly, 200, 16, ACC)
    ly = ly + 20
    local ns = segToggle(10, ly, ww, 32, { "Instant", "Gradual" }, boostStore.mode)
    if ns ~= boostStore.mode then boostStore.mode = ns end
    ly = ly + 44

    -- target speed
    local nv = boostSlider("Target Speed", 10, ly, ww, "##btgt",
      boostStore.targetSpeed, 185, 320, "  %.0f km/h")
    if math.abs(nv - boostStore.targetSpeed) > 0.01 then boostStore.targetSpeed = nv end
    ly = ly + 48

    -- smoothing (Gradual only)
    if boostStore.mode == 2 then
      nv = boostSlider("Smoothing  (higher = snappier)", 10, ly, ww, "##baccel",
        boostStore.accelPower, 1, 50, "  %.0f")
      if math.abs(nv - boostStore.accelPower) > 0.01 then boostStore.accelPower = nv end
      ly = ly + 48
    end

    -- cooldown
    nv = boostSlider("Cooldown", 10, ly, ww, "##bcd",
      boostStore.cooldown, 1, 120, "  %.0f s")
    if math.abs(nv - boostStore.cooldown) > 0.01 then boostStore.cooldown = nv end
    ly = ly + 48

    -- reset
    if bigButton(10, ly, ww, 32, "Reset to defaults", rgbm(0.30, 0.31, 0.36, 1), "##brst") then
      boostStore.mode        = 1
      boostStore.accelPower  = 15.0
      boostStore.cooldown    = 5.0
      boostStore.targetSpeed = 230.0
    end
    ly = ly + 40

    dwBox("Press to toggle · brake to cancel", 12, 10, ly, ww, 16, CDm)
    ui.dummy(vec2(1, ly + 24))
  end)

  -- ===== key =====
  keyPicker(X, Y + H - 30, W, "Boost Key", keyName(keyStore.boostKey), function()
    keyStore.boostKey = nextKey(keyStore.boostKey, keyStore.rewindKey)
    boostPrevKey = false
  end)
end

--=================================================================
-- [15] FEATURE: EXTRAS  (الأكسترا: تثبيت مفاتيح السيارة)
--=================================================================
local extraKeys   = { "extraA","extraB","extraC","extraD","extraE","extraF","extraG","extraH","extraI" }
local extraLocked = {}
local extraAvail  = {}
local extraInit   = false
for i = 1, #extraKeys do extraLocked[i] = false end

local function extrasUpdate()
  local car = ac.getCar(0)
  if not car then return end
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
  local listY = Y + 40
  local listH = H - 40
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
        ui.drawRectFilled(vec2(4, ry), vec2(ww - 10, ry + 44),
          locked and rgbm(ACC.r, ACC.g, ACC.b, 0.14) or rgbm(1, 1, 1, 0.03), 10)
        -- اسم الإضافة موسّط في المساحة بين الزر واليمين
        dwBox("EXTRA " .. string.upper(string.sub(key, 6)), 16, 100, ry, ww - 114, 44, locked and CW or CDm)
        -- زر التبديل (يسار)
        local pw, ph, px, py = 76, 28, 14, ry + 8
        ui.setCursor(vec2(px, py))
        local cl = ui.invisibleButton("##ex" .. i, vec2(pw, ph))
        ui.drawRectFilled(vec2(px, py), vec2(px + pw, py + ph), locked and ACC or rgbm(0.28, 0.29, 0.33, 1), 14)
        dwBox(locked and "ON" or "OFF", 14, px, py, pw, ph, locked and DK or CW)
        if cl then
          extraLocked[i] = not locked
          pcall(function() ac.setExtraSwitch(i - 1, extraLocked[i]) end)
        end
        k = k + 1
      end
    end
    if k == 0 then dwBox("لا توجد إضافات لهذه السيارة", 15, 0, 16, ww, 22, CDm) end
    ui.dummy(vec2(1, k * 50 + 8))
  end)
end

--=================================================================
-- [16] FEATURE: REWIND  (الرجوع بالزمن)
--=================================================================
local REWIND_MAX_FRAMES = math.floor(CFG.REWIND_MAX_SEC / CFG.REWIND_INTERVAL)
local rHistory      = {}
local rRecordTimer  = 0
local rIsRewinding  = false
local rWasRewinding = false
local rLastState    = nil

local function rewindUpdate(dt)
  local car = ac.getCar(0)
  if not car then return end

  local down = (not isTyping()) and ui.keyboardButtonDown(keyStore.rewindKey)

  if down and #rHistory > 0 then
    rIsRewinding = true; rWasRewinding = true
    local popN = math.floor((dt * CFG.REWIND_SPEED) / CFG.REWIND_INTERVAL)
    if popN < 1 then popN = 1 end
    for _ = 1, popN do if #rHistory > 0 then rLastState = table.remove(rHistory) end end
    if rLastState then
      physics.setCarVelocity(0, vec3(0, 0, 0))
      physics.setCarPosition(0, rLastState.pos, -rLastState.look, rLastState.up)
    end
  else
    rIsRewinding = false
    if rWasRewinding then
      rWasRewinding = false
      if rLastState then physics.setCarVelocity(0, rLastState.vel) end
      Core.ghostStart()
    end
    rRecordTimer = rRecordTimer + dt
    if rRecordTimer >= CFG.REWIND_INTERVAL then
      rRecordTimer = rRecordTimer % CFG.REWIND_INTERVAL
      table.insert(rHistory, {
        pos  = vec3(car.position.x, car.position.y, car.position.z),
        look = vec3(car.look.x, car.look.y, car.look.z),
        up   = vec3(car.up.x, car.up.y, car.up.z),
        vel  = vec3(car.velocity.x, car.velocity.y, car.velocity.z),
      })
      if #rHistory > REWIND_MAX_FRAMES then table.remove(rHistory, 1) end
    end
  end
end

local function drawRewind(X, Y, W, H)
  local histSec = #rHistory * CFG.REWIND_INTERVAL
  local ready = histSec > 2.0
  sectionTitle("الرجوع بالزمن", "REWIND", X, Y, W)

  local cardH  = 92
  local BS     = 148
  local stackH = cardH + 30 + BS + 44
  local sy     = Y + math.max(0, (H - stackH) * 0.5)

  -- بطاقة الذاكرة المسجّلة
  ui.drawRectFilled(vec2(X, sy), vec2(X + W, sy + cardH), rgbm(1, 1, 1, 0.05), 14)
  ui.drawRectFilled(vec2(X, sy), vec2(X + W, sy + cardH * 0.5), rgbm(1, 1, 1, 0.03), 14)
  ui.drawRect(vec2(X, sy), vec2(X + W, sy + cardH), rgbm(ACC.r, ACC.g, ACC.b, 0.28), 14, nil, 1)
  dwBox("الذاكرة المسجّلة", 12, X, sy + 10, W, 14, CDm)
  dwMono(string.format("%.1f / %.0f", histSec, CFG.REWIND_MAX_SEC), 40, X, sy + 26, W, 44, ready and CGR or CC)
  dwBox("ثانية", 11, X, sy + 70, W, 12, CDm)
  local pct = math.min(histSec / CFG.REWIND_MAX_SEC, 1)
  local by = sy + cardH - 10
  ui.drawRectFilled(vec2(X + 16, by), vec2(X + W - 16, by + 3), rgbm(0, 0, 0, 0.45), 2)
  if pct > 0 then ui.drawRectFilled(vec2(X + 16, by), vec2(X + 16 + (W - 32) * pct, by + 3), ACC, 2) end

  -- زر مربّع (مؤشر — الفعل بمسك المفتاح)
  local bx  = X + (W - BS) * 0.5
  local byy = sy + cardH + 30
  if rIsRewinding then
    glowRect(bx, byy, bx + BS, byy + BS, COR, 20)
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(1, 0.5, 0.12, 1), 20)
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS * 0.5), rgbm(1, 1, 1, 0.16), 20)
    ui.drawRect(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(1, 1, 1, 0.32), 20, nil, 2)
    dwBox("REWIND", 26, bx, byy + BS * 0.5 - 20, BS, 34, DK)
    dwBox("جارٍ الرجوع...", 14, bx, byy + BS * 0.5 + 16, BS, 18, DK)
  else
    local base = ready and rgbm(0.16, 0.5, 0.2, 1) or rgbm(0.22, 0.23, 0.27, 1)
    if ready then glowRect(bx, byy, bx + BS, byy + BS, CGR, 20) end
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS), base, 20)
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS * 0.5), rgbm(1, 1, 1, 0.10), 20)
    ui.drawRect(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(1, 1, 1, 0.28), 20, nil, 2)
    dwBox("امسك", 22, bx, byy + 24, BS, 26, CW)
    dwMono(keyName(keyStore.rewindKey), 40, bx, byy + BS * 0.5 - 6, BS, 46, CW)
    dwBox(ready and "جاهز للرجوع" or "يسجّل...", 13, bx, byy + BS - 34, BS, 18, ready and CGR or CDm)
  end
  dwBox("امسك المفتاح للرجوع بالزمن · حماية 10 ثواني بعده", 12, X, byy + BS + 12, W, 16, CC)

  -- منتقي المفتاح (يتجنّب مفتاح البوست تلقائياً)
  keyPicker(X, Y + H - 30, W, "مفتاح الرجوع", keyName(keyStore.rewindKey), function()
    keyStore.rewindKey = nextKey(keyStore.rewindKey, keyStore.boostKey)
  end)
end

--=================================================================
-- [17] FEATURE: WEATHER  (جو ووقت شخصي)
--   شرط السيرفر: EnableClientMessages: true في extra_cfg.yml
--=================================================================
local driveWeatherEvent = ac.OnlineEvent({
  ac.StructItem.key("driveWeather"),
  command     = ac.StructItem.int32(),   -- 1=weather 2=time 3=reset
  weatherType = ac.StructItem.int32(),   -- قيمة WeatherFxType الخام
  hour        = ac.StructItem.int32(),
  minute      = ac.StructItem.int32(),
}, function(sender, data) end)

-- كل أنواع الجو من CSP تلقائيًا (نفس اجواء comfy)
local wList = {}
for name, id in pairs(ac.WeatherType) do
  if type(id) == "number" and name ~= "None" then
    wList[#wList + 1] = { id = id, name = name }
  end
end
table.sort(wList, function(a, b) return a.name < b.name end)

local wTime     = 720   -- 12:00
local wSel      = -1
local wDirty    = false
local wLastSent = -1

local function wSendWeather(id)
  driveWeatherEvent{ command = 1, weatherType = id, hour = 0, minute = 0 }
  wSel = id
end

local function wSendTime()
  driveWeatherEvent{ command = 2, weatherType = 0, hour = math.floor(wTime / 60), minute = wTime % 60 }
  wLastSent = os.clock()
end

local function wSendReset()
  driveWeatherEvent{ command = 3, weatherType = 0, hour = 0, minute = 0 }
  wSel = -1
end

local function drawWeather(X, Y, W, H)
  sectionTitle("الجو والوقت", "WEATHER", X, Y, W)
  local topY = Y + 46

  -- ===== الوقت (سلايدر: ساعة/دقيقة) =====
  dwLeftBox("الوقت", 13, X, topY, 120, 18, ACC)
  ui.setCursor(vec2(X, topY + 22))
  ui.setNextItemWidth(W)
  ui.pushStyleColor(ui.StyleColor.SliderGrab, ACC)
  ui.pushStyleColor(ui.StyleColor.FrameBg, rgbm(1, 1, 1, 0.05))
  local nv = ui.slider("##wtime", wTime, 0, 1439,
    string.format("  %02d:%02d", math.floor(wTime / 60), wTime % 60))
  ui.popStyleColor(2)
  -- يُرسل فقط عند التحريك الفعلي (ما يرسل عند مجرد فتح التبويب)
  local newT = math.floor(nv)
  if newT ~= wTime then wTime = newT; wDirty = true end
  if wDirty and (os.clock() - wLastSent) > 0.15 then wSendTime(); wDirty = false end

  -- ===== قائمة الأجواء (عمودين، تضغط تختار) =====
  local btnH   = 42
  local resetY = Y + H - btnH
  local listY  = topY + 58
  local listH  = (resetY - 14) - listY
  ui.drawRectFilled(vec2(X, listY), vec2(X + W, listY + listH), rgbm(1, 1, 1, 0.028), 12)
  ui.drawRect(vec2(X, listY), vec2(X + W, listY + listH), rgbm(1, 1, 1, 0.06), 12, nil, 1)
  ui.setCursor(vec2(X, listY))
  ui.childWindow("##wlist", vec2(W, listH), function()
    local ww   = ui.windowWidth()
    local colW = (ww - 12) / 2
    for i = 1, #wList do
      local coln = (i - 1) % 2
      local rown = math.floor((i - 1) / 2)
      local bx = 4 + coln * (colW + 4)
      local by = 4 + rown * 40
      ui.setCursor(vec2(bx, by))
      local cl  = ui.invisibleButton("##w" .. wList[i].id, vec2(colW, 36))
      local hov = ui.itemHovered()
      local sel = wSel == wList[i].id
      local bg  = sel and rgbm(ACC.r, ACC.g, ACC.b, 0.9)
                  or (hov and rgbm(1, 1, 1, 0.10) or rgbm(1, 1, 1, 0.04))
      ui.drawRectFilled(vec2(bx, by), vec2(bx + colW, by + 36), bg, 8)
      dwBox(wList[i].name, 14, bx, by, colW, 36, sel and DK or CW)
      if cl then wSendWeather(wList[i].id) end
    end
    ui.dummy(vec2(1, math.ceil(#wList / 2) * 40 + 8))
  end)

  -- ===== رجوع لجو السيرفر =====
  if bigButton(X, resetY, W, btnH, "رجوع لجو السيرفر", ACC, "##wreset") then wSendReset() end
end

--=================================================================
-- [18] FEATURE: SHADDA POINTS  (شدّات ثابتة خاصة باللاعب)
--   اللاعب يوقف بالمكان اللي يبيه، يحفظه في حرف، وبعدها يضغط
--   الحرف في أي وقت فيرسبن عليه. محفوظة محلياً وتبقى بعد الخروج.
--
--   ⚠ لا تستخدم هذي الحروف: T U O K F B (محجوزة لشدّات السيرفر)
--     ولا D (مفتاح القائمة) ولا W A S D (القيادة بالكيبورد).
--=================================================================
local SHADDA_SLOTS = {
  { letter = "H", code = 72 },
  { letter = "V", code = 86 },
  { letter = "L", code = 76 },
  { letter = "J", code = 74 },
}

local shaddaDefaults = {}
for _, s in ipairs(SHADDA_SLOTS) do shaddaDefaults["shadda_" .. s.letter] = "" end
local shaddaStore = ac.storage(shaddaDefaults)
local shaddaPrev  = {}
local shaddaMsg, shaddaMsgT = "", 0

-- الحرف معطّل لو محجوز لمفتاح ثاني في نفس البلقن
local function shaddaBusy(code)
  return code == CFG.MENU_TOGGLE_KEY
      or code == keyStore.boostKey
      or code == keyStore.rewindKey
end

local function shaddaRead(slot)
  local raw = shaddaStore["shadda_" .. slot.letter]
  if not raw or raw == "" then return nil end
  local n = {}
  for v in raw:gmatch("[^,]+") do n[#n + 1] = tonumber(v) end
  if #n < 9 then return nil end
  return vec3(n[1], n[2], n[3]), vec3(n[4], n[5], n[6]), vec3(n[7], n[8], n[9])
end

local function shaddaSave(slot)
  local car = ac.getCar(0)
  if not car then return end
  shaddaStore["shadda_" .. slot.letter] = string.format(
    "%.3f,%.3f,%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f",
    car.position.x, car.position.y, car.position.z,
    car.look.x, car.look.y, car.look.z,
    car.up.x, car.up.y, car.up.z)
  shaddaMsg, shaddaMsgT = "تم حفظ المكان في حرف " .. slot.letter, 3
end

local function shaddaClear(slot)
  shaddaStore["shadda_" .. slot.letter] = ""
  shaddaMsg, shaddaMsgT = "تم مسح حرف " .. slot.letter, 3
end

-- نفس طريقة الريوايند بالضبط (مجرّبة وشغّالة): -look مع up
local function shaddaGo(slot)
  if not Core.ready() then return end
  local pos, look, up = shaddaRead(slot)
  if not pos then return end
  physics.setCarVelocity(0, vec3(0, 0, 0))
  physics.setCarPosition(0, pos, -look, up)
  Core.ghostStart()
  Core.startCooldown()
end

local function shaddaUpdate(dt)
  if shaddaMsgT > 0 then shaddaMsgT = shaddaMsgT - dt end
  local typing = isTyping()
  for i, s in ipairs(SHADDA_SLOTS) do
    local down = (not typing) and (not shaddaBusy(s.code)) and ui.keyboardButtonDown(s.code)
    if down and not shaddaPrev[i] then shaddaGo(s) end
    shaddaPrev[i] = down
  end
end

local function drawShadda(X, Y, W, H)
  sectionTitle("الشدّات الثابتة", "SHADDA", X, Y, W)
  dwRightBox("قف بالمكان → احفظ في حرف → اضغط الحرف ترجع له", 12, X, Y + 26, W - 44, 14, CDm)

  local car  = ac.getCar(0)
  local rowH = 58
  local sy   = Y + 52

  for i, s in ipairs(SHADDA_SLOTS) do
    local ry   = sy + (i - 1) * (rowH + 8)
    local pos  = shaddaRead(s)
    local busy = shaddaBusy(s.code)

    ui.drawRectFilled(vec2(X, ry), vec2(X + W, ry + rowH),
      pos and rgbm(ACC.r, ACC.g, ACC.b, 0.10) or rgbm(1, 1, 1, 0.035), 12)
    ui.drawRect(vec2(X, ry), vec2(X + W, ry + rowH), rgbm(1, 1, 1, 0.07), 12, nil, 1)

    -- شارة الحرف
    ui.drawRectFilled(vec2(X + 8, ry + 9), vec2(X + 56, ry + rowH - 9),
      pos and rgbm(ACC.r, ACC.g, ACC.b, 0.85) or rgbm(1, 1, 1, 0.07), 10)
    dwBox(s.letter, 24, X + 8, ry + 9, 48, rowH - 18, pos and DK or CDm)

    -- الأزرار (يمين الصف)
    local bw, bh = 74, 34
    local by = ry + (rowH - bh) * 0.5
    local b3 = X + W - 8 - bw
    local b2 = b3 - bw - 6
    local b1 = b2 - bw - 6

    local canGo = pos ~= nil and Core.ready()
    if bigButton(b1, by, bw, bh, "انتقال", canGo and ACC or rgbm(0.24, 0.25, 0.30, 1), "##shg" .. s.letter) and canGo then
      shaddaGo(s)
    end
    if bigButton(b2, by, bw, bh, "حفظ هنا", rgbm(0.30, 0.31, 0.36, 1), "##shs" .. s.letter) then
      shaddaSave(s)
    end
    if bigButton(b3, by, bw, bh, "مسح", rgbm(0.30, 0.20, 0.20, 1), "##shc" .. s.letter) then
      shaddaClear(s)
    end

    -- الحالة (بين الشارة والأزرار)
    local tx, tw = X + 64, b1 - (X + 64) - 8
    local st, sc
    if busy then
      st, sc = "الحرف محجوز لمفتاح ثاني", CR
    elseif pos then
      local d = car and (car.position:distance(pos)) or 0
      st, sc = string.format("محفوظة · %.0f م", d), CGR
    else
      st, sc = "فارغة", CDm
    end
    dwBox(st, 14, tx, ry, tw, rowH, sc)
  end

  -- رسالة تأكيد قصيرة
  if shaddaMsgT > 0 then
    local my = Y + H - 26
    ui.drawRectFilled(vec2(X, my), vec2(X + W, my + 24), rgbm(ACC.r, ACC.g, ACC.b, 0.14), 7)
    dwBox(shaddaMsg, 13, X, my, W, 24, CC)
  end
end

--=================================================================
-- [20] NAV ICONS  (كل أيقونة دالة مستقلة — نضيفها للتبويب في [21])
--   التوقيع: fn(cx, cy, r, t, c)
--=================================================================
local ICONS = {}

function ICONS.crosshair(cx, cy, r, t, c)
  ui.drawCircle(vec2(cx, cy), r, c, 32, t)
  ui.drawLine(vec2(cx - r - 3, cy), vec2(cx - r * 0.45, cy), c, t)
  ui.drawLine(vec2(cx + r * 0.45, cy), vec2(cx + r + 3, cy), c, t)
  ui.drawLine(vec2(cx, cy - r - 3), vec2(cx, cy - r * 0.45), c, t)
  ui.drawLine(vec2(cx, cy + r * 0.45), vec2(cx, cy + r + 3), c, t)
  ui.drawCircleFilled(vec2(cx, cy), 2.4, c)
end

function ICONS.map(cx, cy, r, t, c)
  local s = r / 0.34
  local w = s * 0.22
  local h = s * 0.62
  local y1 = cy - h * 0.5
  ui.drawLine(vec2(cx - w * 1.5, y1 + 2), vec2(cx - w * 0.5, y1), c, t)
  ui.drawLine(vec2(cx - w * 0.5, y1), vec2(cx + w * 0.5, y1 + 2), c, t)
  ui.drawLine(vec2(cx + w * 0.5, y1 + 2), vec2(cx + w * 1.5, y1), c, t)
  ui.drawLine(vec2(cx - w * 1.5, y1 + 2), vec2(cx - w * 1.5, y1 + h), c, t)
  ui.drawLine(vec2(cx - w * 0.5, y1), vec2(cx - w * 0.5, y1 + h - 2), c, t)
  ui.drawLine(vec2(cx + w * 0.5, y1 + 2), vec2(cx + w * 0.5, y1 + h), c, t)
  ui.drawLine(vec2(cx + w * 1.5, y1), vec2(cx + w * 1.5, y1 + h - 2), c, t)
  ui.drawLine(vec2(cx - w * 1.5, y1 + h), vec2(cx - w * 0.5, y1 + h - 2), c, t)
  ui.drawLine(vec2(cx - w * 0.5, y1 + h - 2), vec2(cx + w * 0.5, y1 + h), c, t)
  ui.drawLine(vec2(cx + w * 0.5, y1 + h), vec2(cx + w * 1.5, y1 + h - 2), c, t)
end

function ICONS.palette(cx, cy, r, t, c)
  ui.drawCircle(vec2(cx, cy), r, c, 36, t)
  ui.drawCircleFilled(vec2(cx - 7, cy - 5), 2.3, c)
  ui.drawCircleFilled(vec2(cx + 5, cy - 7), 2.3, c)
  ui.drawCircleFilled(vec2(cx + 8, cy + 2), 2.3, c)
  ui.drawCircleFilled(vec2(cx - 3, cy + 8), 2.3, c)
end

function ICONS.tire(cx, cy, r, t, c)
  ui.drawCircle(vec2(cx, cy), r, c, 36, t)
  ui.drawCircle(vec2(cx, cy), r * 0.45, c, 24, t)
  for i = 0, 5 do
    local a = math.rad(i * 60)
    ui.drawLine(vec2(cx + math.cos(a) * r * 0.45, cy + math.sin(a) * r * 0.45),
                vec2(cx + math.cos(a) * r * 0.88, cy + math.sin(a) * r * 0.88), c, t)
  end
end

function ICONS.bolt(cx, cy, r, t, c)
  local p1 = vec2(cx - 5, cy - 10)
  local p2 = vec2(cx + 1, cy - 2)
  local p3 = vec2(cx - 2, cy - 2)
  local p4 = vec2(cx + 6, cy + 10)
  local p5 = vec2(cx, cy + 2)
  local p6 = vec2(cx + 3, cy + 2)
  ui.drawLine(p1, p2, c, t)
  ui.drawLine(p2, p3, c, t)
  ui.drawLine(p3, p4, c, t)
  ui.drawLine(p4, p5, c, t)
  ui.drawLine(p5, p6, c, t)
end

function ICONS.gear(cx, cy, r, t, c)
  ui.drawCircle(vec2(cx, cy), r * 0.75, c, 32, t)
  ui.drawCircle(vec2(cx, cy), r * 0.28, c, 16, t)
  for i = 0, 7 do
    local a = math.rad(i * 45)
    ui.drawLine(vec2(cx + math.cos(a) * r * 0.78, cy + math.sin(a) * r * 0.78),
                vec2(cx + math.cos(a) * r * 1.05, cy + math.sin(a) * r * 1.05), c, t)
  end
end

function ICONS.rewind(cx, cy, r, t, c)
  ui.drawCircle(vec2(cx, cy), r * 0.95, c, 32, t)
  ui.drawLine(vec2(cx + 5, cy - 6), vec2(cx - 3, cy - 6), c, t)
  ui.drawLine(vec2(cx - 3, cy - 6), vec2(cx - 8, cy), c, t)
  ui.drawLine(vec2(cx - 8, cy), vec2(cx - 3, cy + 6), c, t)
end

function ICONS.pin(cx, cy, r, t, c)
  local top = cy - r * 0.30
  ui.drawCircle(vec2(cx, top), r * 0.58, c, 24, t)
  ui.drawCircleFilled(vec2(cx, top), r * 0.20, c)
  ui.drawLine(vec2(cx - r * 0.42, top + r * 0.40), vec2(cx, cy + r * 0.95), c, t)
  ui.drawLine(vec2(cx + r * 0.42, top + r * 0.40), vec2(cx, cy + r * 0.95), c, t)
end

function ICONS.sun(cx, cy, r, t, c)
  ui.drawCircle(vec2(cx, cy), r * 0.55, c, 24, t)
  for i = 0, 7 do
    local a = math.rad(i * 45)
    ui.drawLine(vec2(cx + math.cos(a) * r * 0.75, cy + math.sin(a) * r * 0.75),
                vec2(cx + math.cos(a) * r * 1.05, cy + math.sin(a) * r * 1.05), c, t)
  end
end

--=================================================================
-- [21] TAB REGISTRY
--   تبي تضيف تبويب؟ سوّ بلوك ميزة فوق، وزد سطر واحد هنا.
--   تبي تشيل تبويب؟ احذف سطره — بدون أي تعديل ثاني.
--=================================================================
local TABS = {
  { key = "teleport", label = "الانتقال", icon = ICONS.crosshair, draw = drawTeleport },
  { key = "shadda",   label = "الشدّات",  icon = ICONS.pin,       draw = drawShadda   },
  { key = "map",      label = "الخريطة",  icon = ICONS.map,       draw = drawMap      },
  { key = "skins",    label = "السكنات",  icon = ICONS.palette,   draw = drawSkin     },
  { key = "grip",     label = "التماسك",  icon = ICONS.tire,      draw = drawGrip     },
  { key = "boost",    label = "البوست",   icon = ICONS.bolt,      draw = drawBoost    },
  { key = "extras",   label = "الأكسترا", icon = ICONS.gear,      draw = drawExtras   },
  { key = "rewind",   label = "الرجوع",   icon = ICONS.rewind,    draw = drawRewind   },
  { key = "weather",  label = "الجو",     icon = ICONS.sun,       draw = drawWeather  },
}

--=================================================================
-- [22] PANEL SHELL  (اللوقو + عمود التبويبات + الهيدر + التوزيع)
--=================================================================
local activeTab     = 1
local panelOpen     = not CFG.START_CLOSED
local lastDrawClock = 0
local firstDraw     = true

local function drawLogo(x0, y0, x1, y1)
  local boxW, boxH = x1 - x0, y1 - y0
  if CFG.LOGO_URL ~= "" then
    local sz = ui.imageSize(CFG.LOGO_URL)
    if sz and sz.x > 1 and sz.y > 1 then
      local sc = math.min(boxW / sz.x, boxH / sz.y)
      local dw, dh = sz.x * sc, sz.y * sc
      local ix, iy = x0 + (boxW - dw) * 0.5, y0 + (boxH - dh) * 0.5
      ui.drawImage(CFG.LOGO_URL, vec2(ix, iy), vec2(ix + dw, iy + dh))
      return
    else
      ui.decodeImage(CFG.LOGO_URL)
    end
  end
  dwBox("DRIVE", 26, x0, y0, boxW, boxH, CW)
end

local function mainUI()
  -- إذا توقفت اللعبة عن رسم النافذة (أُغلقت من قائمة التطبيقات) ثم أعادت إظهارها،
  -- نعيد فتح البانل تلقائياً حتى لا يطلع "شبح" فاضي ويظنّه اللاعب معلّقاً.
  -- نتخطى هذا في أول فريم فقط، عشان الدخول يكون بقائمة مقفولة وتنبيه D يبان.
  if firstDraw then
    firstDraw = false
  elseif Core.clock - lastDrawClock > 0.3 then
    panelOpen = true
  end
  lastDrawClock = Core.clock

  -- حالة الإغلاق: مخفية تماماً (تُفتح بزر  D )
  if not panelOpen then
    pcall(function() ui.setWindowSize(vec2(1, 1)) end)
    ui.setCursor(vec2(0, 0)); ui.dummy(vec2(1, 1))
    return
  end

  -- الحجم الفعلي للنافذة (تتحجّم بالسحب الطبيعي من الزاوية/الحواف)
  local ws = ui.windowSize()
  local W = math.max(ws.x, CFG.PANEL_MIN_W)
  local H = math.max(ws.y, CFG.PANEL_MIN_H)

  -- خلفية + توهج علوي
  ui.drawRectFilled(vec2(0, 0), vec2(W, H), BGD, 14)
  for s = 1, 3 do
    ui.drawRectFilled(vec2(0, 0), vec2(W, 80 + s * 22), rgbm(ACC.r, ACC.g, ACC.b, 0.015), 14)
  end
  ui.drawRect(vec2(0, 0), vec2(W, H), rgbm(1, 1, 1, 0.09), 14, nil, 1)

  -- ===== العمود الأيسر =====
  local NAV = CFG.NAV_W
  drawLogo(14, 16, NAV - 14, 62)
  ui.drawLine(vec2(NAV, 16), vec2(NAV, H - 16), rgbm(1, 1, 1, 0.07), 1)

  local itemH = 48
  local ny0 = 84
  for i, tab in ipairs(TABS) do
    local iy = ny0 + (i - 1) * (itemH + 6)
    ui.setCursor(vec2(10, iy))
    local cl  = ui.invisibleButton("##nv" .. tab.key, vec2(NAV - 20, itemH))
    local hov = ui.itemHovered()
    local sel = activeTab == i
    if sel then
      ui.drawRectFilled(vec2(10, iy), vec2(NAV - 10, iy + itemH), rgbm(ACC.r, ACC.g, ACC.b, 0.18), 12)
      ui.drawRectFilled(vec2(10, iy), vec2(NAV - 10, iy + itemH), rgbm(ACC.r, ACC.g, ACC.b, 0.06), 12)
      ui.drawRectFilled(vec2(NAV - 13, iy + 10), vec2(NAV - 10, iy + itemH - 10), ACC, 2)
    elseif hov then
      ui.drawRectFilled(vec2(10, iy), vec2(NAV - 10, iy + itemH), rgbm(1, 1, 1, 0.05), 12)
    end
    -- الأيقونة أقصى اليمين، والنص يسارها مع مسافة واضحة (ما يتداخلون)
    local ix = NAV - 40
    local iyy = iy + (itemH - 22) * 0.5
    tab.icon(ix + 11, iyy + 11, 22 * 0.34, math.max(1.5, 22 * 0.08), sel and ACC or CDm)
    dwRightBox(tab.label, 16, 8, iy, NAV - 58, itemH, sel and CW or CDm)
    if cl then activeTab = i end
  end
  dwBox("غلق: زر  " .. CFG.MENU_KEY_LABEL, 11, 0, H - 40, NAV, 14, CDm)
  dwBox("DRIVE ©", 10, 0, H - 22, NAV, 12, CDm)

  -- ===== الشريط العلوي: حالة + إغلاق =====
  local CX = NAV + 16
  local CWid = W - CX - 16
  dwBox("● ONLINE", 11, CX, 14, 100, 16, CGR)

  ui.setCursor(vec2(W - 42, 12))
  local xcl = ui.invisibleButton("##close", vec2(30, 30))
  local xhov = ui.itemHovered()
  ui.drawRectFilled(vec2(W - 42, 12), vec2(W - 12, 42), xhov and rgbm(0.9, 0.25, 0.2, 0.95) or rgbm(1, 1, 1, 0.06), 8)
  ui.drawRect(vec2(W - 42, 12), vec2(W - 12, 42), rgbm(1, 1, 1, 0.12), 8, nil, 1)
  ui.drawLine(vec2(W - 36, 18), vec2(W - 18, 36), xhov and CW or CDm, 2)
  ui.drawLine(vec2(W - 18, 18), vec2(W - 36, 36), xhov and CW or CDm, 2)
  if xcl then panelOpen = false end

  -- ===== شريط الحالة (حماية / انتظار) =====
  local CY0 = 46
  if Core.ghostOn then
    ui.drawRectFilled(vec2(CX, CY0), vec2(CX + CWid, CY0 + 22), rgbm(ACC.r, ACC.g, ACC.b, 0.12), 7)
    dwBox(string.format("● حماية  %.1f", Core.ghostT), 13, CX, CY0, CWid, 22, CC)
    CY0 = CY0 + 26
  end
  if Core.cd > 0 then
    ui.drawRectFilled(vec2(CX, CY0), vec2(CX + CWid, CY0 + 22), rgbm(CY.r, CY.g, CY.b, 0.12), 7)
    dwBox(string.format("● انتظار  %.1f", Core.cd), 13, CX, CY0, CWid, 22, CY)
    CY0 = CY0 + 26
  end
  local CHt = H - CY0 - 18

  -- ===== محتوى التبويب النشط =====
  local tab = TABS[activeTab]
  if tab and tab.draw then tab.draw(CX, CY0, CWid, CHt) end

  -- علامة زاوية التحجيم (اسحب الزاوية لتكبير/تصغير النافذة)
  local gc = CDm
  ui.drawLine(vec2(W - 7, H - 24), vec2(W - 24, H - 7), gc, 1.6)
  ui.drawLine(vec2(W - 7, H - 17), vec2(W - 17, H - 7), gc, 1.6)
  ui.drawLine(vec2(W - 7, H - 10), vec2(W - 10, H - 7), gc, 1.6)

  ui.setCursor(vec2(0, 0))
  ui.dummy(vec2(W, H))
end

--=================================================================
-- [23] REGISTER APP
--   بلا تايتل بار وبلا تحكّم CSP (الإغلاق من الزر الداخلي)
--=================================================================
local winFlags = ui.WindowFlags.NoTitleBar
               + ui.WindowFlags.NoBackground
               + ui.WindowFlags.NoScrollbar
               + ui.WindowFlags.NoCollapse

ui.registerOnlineExtra(
  ui.Icons.Navigation,
  "DRIVE | MENU",
  nil,
  mainUI,
  nil,
  ui.OnlineExtraFlags.Tool,
  winFlags,
  vec2(CFG.PANEL_W, CFG.PANEL_H)
)

--=================================================================
-- [24] UPDATE LOOP
--   كل ميزة لها دالة update خاصة — ننادي عليها من هنا فقط.
--=================================================================
local menuPrevKey = false

function script.update(dt)
  Core.update(dt)

  -- فتح/غلق القائمة
  local mk = (not isTyping()) and ui.keyboardButtonDown(CFG.MENU_TOGGLE_KEY)
  if mk and not menuPrevKey then panelOpen = not panelOpen end
  menuPrevKey = mk

  boostUpdate(dt)
  extrasUpdate()
  rewindUpdate(dt)
  shaddaUpdate(dt)
end

--=================================================================
-- [25] SCREEN HUD  (الطبقات فوق الشاشة)
--=================================================================

-- شعار "اضغط D لفتح القائمة" — يطلع فقط لما تكون القائمة مقفولة
-- ويختفي لو التطبيق نفسه مقفول من قائمة تطبيقات CSP.
local function drawOpenHint()
  if not CFG.SHOW_OPEN_HINT then return end
  if panelOpen then return end
  if Core.clock - lastDrawClock > 0.5 then return end

  local screen = ac.getUI().windowSize
  -- أول ثواني بعد الدخول: تنبيه أكبر وأوضح، بعدها يرجع صغير وهادي
  local intro = Core.clock < CFG.HINT_INTRO_SEC
  local k = intro and 1.5 or 1.0
  local w, h = 300 * k, 56 * k
  local x = (screen.x - w) * 0.5
  ui.transparentWindow("driveOpenHint", vec2(x, 18), vec2(w, h), false, function()
    local pulse = 0.55 + 0.45 * math.abs(math.sin(Core.clock * 2))
    ui.drawRectFilled(vec2(0, 0), vec2(w, h), rgbm(0.035, 0.035, 0.042, intro and 0.93 or 0.88), 12 * k)
    ui.drawRect(vec2(0, 0), vec2(w, h), rgbm(ACC.r, ACC.g, ACC.b, 0.25 + 0.45 * pulse), 12 * k, nil, 1.5 * k)
    drawLogo(12 * k, 10 * k, 82 * k, h - 10 * k)
    ui.drawLine(vec2(92 * k, 12 * k), vec2(92 * k, h - 12 * k), rgbm(1, 1, 1, 0.12), 1)
    dwBox("اضغط  " .. CFG.MENU_KEY_LABEL .. "  لفتح القائمة", 16 * k,
      100 * k, 0, w - 112 * k, h, rgbm(CW.r, CW.g, CW.b, intro and 1.0 or (0.70 + 0.30 * pulse)))
  end, ui.WindowFlags.NoInputs + ui.WindowFlags.NoMouseInputs)
end

function script.drawUI()
  drawOpenHint()

  -- حماية الشبح
  if Core.ghostOn then
    ui.transparentWindow("ghostHUD", vec2(10, 10), vec2(320, 50), false, function()
      ui.drawRectFilled(vec2(0, 0), vec2(320, 50), rgbm(0, 0, 0, 0.6), 8)
      ui.pushDWriteFont(FONT)
      ui.dwriteTextAligned(string.format("وضع الحماية: %.1f ثانية", Core.ghostT),
        17, ui.Alignment.Center, ui.Alignment.Center, vec2(300, 40), false, CC)
      ui.popDWriteFont()
    end)
  end

  -- الرجوع بالزمن
  if rIsRewinding then
    local ws = ac.getUI().windowSize
    ui.transparentWindow("RewindHUD", vec2(0, 0), ws, false, function()
      ui.drawRectFilled(vec2(0, 0), ws, rgbm(0, 0, 0, 0.2), 0)
      ui.pushDWriteFont(FONT)
      ui.dwriteTextAligned("REWINDING TIME...", 50, ui.Alignment.Center, ui.Alignment.Center, ws, false, ACC)
      ui.dwriteTextAligned("ارفع المفتاح للمتابعة", 22, ui.Alignment.Center, ui.Alignment.Center, ws + vec2(0, 90), false, rgbm(1, 1, 1, 0.85))
      ui.popDWriteFont()
    end, ui.WindowFlags.NoInputs + ui.WindowFlags.NoMouseInputs)
  end
end

ac.log("DRIVE Panel loaded")
