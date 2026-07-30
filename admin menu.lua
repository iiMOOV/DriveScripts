---------------------------------------------------------------
-- DRIVE Admin Master Panel (Traffic, Shadda, Radar & Alerts)
-- Theme: Orange / Yellow / Black
-- 100% Arabic UI & Admin Only Access
---------------------------------------------------------------
local mySteamID = tostring(ac.getUserSteamID(0))
local allowedAdmins = {
    ["76561198238092614"] = true, -- Moov
    ["76561199514389130"] = true, -- Abo khaled
    ["76561198964066927"] = true, -- 8NOOZ
    ["76561199526337690"] = true, -- GOBA
    ["76561199549744707"] = true, -- Moov secnod account
    ["76561199263273952"] = true, -- vBrns
    ["76561199163191039"] = true, -- Abo S3D secnod account
}
-- السكربت يشتغل للجميع؛ اللوحة تُحجب على الأدمن لاحقاً، ومفاتيح الشدة تشتغل للكل
local isAdmin = allowedAdmins[mySteamID] == true

 

math.randomseed(os.time())

local LOGO_URL = "https://i.imgur.com/WOV2nwa.png"
local FONT = "Segoe UI;Weight=Bold"

local PANEL_W, PANEL_H = 800, 990
local sizeStore = ac.storage{ pw = PANEL_W, ph = PANEL_H }
local resizing = false
local CLOSE_KEY = 221 -- ] (مختلف عن البانل العادي الذي يستخدم \\ = 220)
local prevCloseKey = false
local panelOpen = true
local activeTab = 1


local WINDOW_TITLE = 'Drive | ADMIN MENU'
local WINDOW_ICON = ui.Icons.Car
-- ==========================================
-- ألوان
-- ==========================================
local CW  = rgbm.colors.white
local CDm = rgbm(0.66, 0.67, 0.70, 1)
local CC  = rgbm(1.00, 0.72, 0.20, 1)
local CY  = rgbm(1.00, 0.84, 0.20, 1)
local CR  = rgbm(0.93, 0.32, 0.20, 1)
local COR = rgbm(1.00, 0.45, 0.06, 1)
local ACC = COR
local DK  = rgbm(0.04, 0.03, 0.02, 1)
local CGR = rgbm(0.35, 0.85, 0.45, 1)
local BGD = rgbm(0.035, 0.035, 0.042, 0.985)

-- ==========================================
-- الإعدادات الأساسية للأنظمة المدمجة
-- ==========================================

-------------------------------------------------
-- 1. Traffic Studio
-------------------------------------------------
local mapName = ac.getTrackName() or "Unknown Map"

local selectedBotIndex = 1
local botsList = { "Loading..." }

local presetsList = {}
local selectedPresetIndex = 1
local presetName = "layout_1"

local stepOptions = {"0.01", "0.05", "0.10", "0.30", "1.00"}
local selectedStepIdx = 4 
local didInitialFetchTFC = false
local tmpBots, tmpPresets = {}, {}

local function requestTrafficList() ac.sendChatMessage("/traffic list") end

-- يحوّل SessionId القادم من السيرفر إلى اسم سيارة (من جهة العميل)
local function botDisplayName(sid)
    local n = tonumber(sid)
    if not n then return tostring(sid) end
    local ok, id = pcall(function() return ac.getCarID(n) end)
    if ok and id and id ~= "" then return id end
    return "سيارة " .. sid
end

-------------------------------------------------
-- 2. Shadda Studio
-------------------------------------------------
local SHADDA_KEYS = { T=string.byte("T"), U=string.byte("U"), O=string.byte("O"), K=string.byte("K"), F=string.byte("F"), B=string.byte("B") }
local shaddaLastStates = { T=false, U=false, O=false, K=false, F=false, B=false }
local fastCooldownTimer = 0
local FAST_SPEED_KMH = 240
local FAST_SPEED_MS = FAST_SPEED_KMH / 3.6
local function getShaddaCoordinates()
    local car = ac.getCar(0)
    return string.format("%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f", 
        car.position.x, car.position.y, car.position.z, 
        car.look.x, car.look.y, car.look.z, 
        car.up.x, car.up.y, car.up.z)
end

-------------------------------------------------
-- 3. Radar & Alerts
-------------------------------------------------
local DEFAULT_ALERT_IMAGE = "https://i.imgur.com/Zu9lIUt.png"
local SOUND_URL     = "http://91.218.66.157:8007/drive/alert.mp3"
local DISPLAY_TIME  = 2.5
local ALERT_W, ALERT_H = 460, 220

local radarMsg, radarImg, radarTimer = "", "", 0
local massMsg,  massImg,  massTimer  = "", "", 0
local soundHold = 0

local mpAlert = ui.MediaPlayer()
pcall(function() mpAlert:setSource(SOUND_URL); mpAlert:setAutoPlay(false); mpAlert:setLooping(false); mpAlert:setVolume(1.0) end)

local function playAlertSound()
  pcall(function() mpAlert:setSource(SOUND_URL); mpAlert:setVolume(1.0); mpAlert:setLooping(false) end)
  pcall(function() mpAlert:setCurrentTime(0) end)
  pcall(function() mpAlert.currentTime = 0 end)
  pcall(function() mpAlert:play() end)
  soundHold = DISPLAY_TIME
end
local function pumpSound() pcall(function() ui.setCursor(vec2(-8, -8)); ui.image(mpAlert, vec2(1, 1)) end) end

local lastMassNonce = 0   
local myNonceCounter = 0  
local AlertEvent = ac.OnlineEvent({ nonce = ac.StructItem.int64(), msg = ac.StructItem.string(200), img = ac.StructItem.string(200) }, function(sender, data)
  if sender == nil or data.nonce == 0 or data.nonce == lastMassNonce then return end
  lastMassNonce = data.nonce
  massMsg, massImg, massTimer = data.msg, (data.img ~= "" and data.img or DEFAULT_ALERT_IMAGE), DISPLAY_TIME
  playAlertSound()
end)

local localSkipState = {}
local radarInputMsg = ""
local radarInputGen = 0   -- تغيير معرّف صندوق الكتابة يجبر CSP يعيد بناءه ويأخذ النص الجديد
-- تبويبات الأدمن الإضافية
local kickReason = ""
local aiSplineOffset = 0.0
local aiTrafficSpeed = 80
local srvHour = 12
local srvWeatherDur = 0

-- ==========================================
-- EVENTS INTERCEPT (Chat)
-- ==========================================
-- ============================================================
-- نظام الشات العربي المخصص (منقول من منيو 1980)
-- شات AC الأصلي يقلب العربي؛ هذا يعترض الرسائل ويرسمها بنفسه بمحاذاة يمين مع دعم الإيموجي والعبارات.
-- ============================================================
local pulseT = 0
local chatLog = {}
local CHAT_MAX = 60
local chatBarOpen = false
local chatBarJustOpened = false
local chatInput = ""
local chatInputGen = 0
local chatBarLastCount = 0
local chatDragging, chatDragStart, chatOfsStart = false, vec2(0, 0), vec2(0, 0)
local cSt = { chatMin = false, showPlayers = false, chatReveal = 1 }
local cStor = ac.storage{ chatOpacity = 0.95, chatW = 760, chatHistH = 186, chatOfsX = 0, chatOfsY = 0, chatEmoji = true, chatPhrases = true, rec1 = "😂", rec2 = "👑", rec3 = "🫡" }

local QUICK_PHRASES = {
  "عداك العيب", "كفووووو", "ولا شيء يا كنق", "مدارس",
  "سلام عليكم", "وعليكم السلام", "لعيونك", "لعيونكم",
}
local EMOJIS = {
  "😂","🤣","😅","😭","😍","🥰","😘","😎","😏","😜","🤪","🤙",
  "🔥","👍","👎","❤️","💔","💀","👏","🙌","💪","🫶","✌️","🤝",
  "👊","🤞","🙏","🫡","🎉","⭐","💯","✅","❌","⚡","💨","🏁",
  "🚗","🏆","🥇","👑","🚦","🛑","😱","🤯","😤","😡","🥱","🎮",
}
local function useEmoji(em)
  chatInput = chatInput .. em
  chatInputGen = chatInputGen + 1
  local a, b, c = cStor.rec1, cStor.rec2, cStor.rec3
  if em == a then return end
  if em == b then cStor.rec1 = em; cStor.rec2 = a; return end
  if em == c then cStor.rec1 = em; cStor.rec2 = a; cStor.rec3 = b; return end
  cStor.rec1 = em; cStor.rec2 = a; cStor.rec3 = b
end
-- ترجمة رسائل السيرفر الإنجليزية الشائعة للعربي قبل عرضها
local SERVER_TR = {
  { "No replay submitted",                    "ما فيه مقطع محفوظ — اضغط Ctrl+Shift+S وقت المخالفة" },
  { "Replay received",                        "تم حفظ المقطع ✓" },
  { "Use /report",                            "افتح نافذة الشكوى، اكتب السبب، وأرسل" },
  { "Please wait a moment before submitting", "استنّى شوي قبل ترفع مقطع ثاني" },
  { "Your report has been submitted",         "تم إرسال بلاغك ✓ شكراً لك" },
  { "You have been kicked",                   "تم طردك من السيرفر" },
  { "You have been banned",                   "تم حظرك من السيرفر" },
  { "shutting down",                          "⚠️ السيرفر يسوي ريستارت — نرجع خلال ثواني، أعد الدخول 🔄" },
}
local function translateServer(m)
  local carN, drv = m:match("^Car (%d+) is now driven by (.+)$")
  if carN then return "السيارة " .. carN .. " صار يقودها " .. drv end
  for _, e in ipairs(SERVER_TR) do
    if m:find(e[1], 1, true) then return e[2] end
  end
  return m
end
local function carByName(nm)
  if not nm then return nil end
  local sim = ac.getSim()
  if not sim then return nil end
  for i = 0, sim.carsCount - 1 do
    if ac.getDriverName(i) == nm then return i end
  end
  return nil
end
-- انتقال بسيط للاعب (خلفه بـ 6 أمتار، بنفس اتجاهه) — للاستخدام من الشات
local function chatTP(car)
  if not car then return end
  pcall(function()
    physics.setCarVelocity(0, vec3(0, 0, 0))
    physics.setCarPosition(0, car.position - car.look * 6, -car.look, car.up)
  end)
end

ac.onChatMessage(function(message, sender)
    -- Traffic Cam Teleport
    if message:sub(1, 14) == "!TRAFFIC_GOTO:" then
        local px, py, pz = message:sub(15):match("([^,]+),([^,]+),([^,]+)")
        if px then
            local targetPos = vec3(tonumber(px), tonumber(py), tonumber(pz))
            local myCar = ac.getCar(0)
            local origPos, origLook, origUp, origVel = myCar.position, myCar.look, myCar.up, myCar.velocity
            physics.setCarPosition(0, targetPos, origLook, origUp)
            physics.setCarVelocity(0, vec3(0, 0, 0))
            setTimeout(function()
                ac.setCurrentCamera(ac.CameraMode.Free)
                setTimeout(function()
                    physics.setCarPosition(0, origPos, origLook, origUp)
                    physics.setCarVelocity(0, origVel)
                    ui.toast(ui.Icons.Camera, "📷 Free camera focused on traffic!")
                end, 0.1)
            end, 0.15)
        end
        return true
    end

    -- Traffic Lists Sync
    local mp = message:match("^!TFC_MAP:(.*)")
    if mp then mapName = mp; return true end
    
    if message:match("^!TFC_BOTS_BEGIN:") then tmpBots = {}; return true end
    local addB = message:match("^!TFC_BOTS_ADD:(.*)")
    if addB then for item in addB:gmatch("([^;]+)") do tmpBots[#tmpBots + 1] = item end return true end
    if message == "!TFC_BOTS_END" then
        botsList = tmpBots
        if #botsList == 0 then botsList = { "لا يوجد سيارات ترافيك" } end
        if selectedBotIndex > #botsList then selectedBotIndex = 1 end
        return true
    end
    
    if message:match("^!TFC_PRE_BEGIN:") then tmpPresets = {}; return true end
    local addP = message:match("^!TFC_PRE_ADD:(.*)")
    if addP then for item in addP:gmatch("([^;]+)") do tmpPresets[#tmpPresets + 1] = item end return true end
    if message == "!TFC_PRE_END" then
        presetsList = tmpPresets
        if selectedPresetIndex > #presetsList then selectedPresetIndex = 1 end
        if #presetsList > 0 and (presetName == "layout_1" or presetName == "") then
            presetName = presetsList[selectedPresetIndex] or presetName
        end
        return true
    end

    -- Shadda Intercept
    if message:sub(1, 10) == "/shadda" then return true end
    if message:match("Slot %[%w+%].*configured") or message:match("Slot %[%w+%].*not set") then return true end
    if message:sub(1, 13) == "!SHADDA_EXEC:" then
        local data = message:sub(14)
        local mode, px, py, pz, lx, ly, lz, ux, uy, uz = data:match("([^|]+)|([^,]+),([^,]+),([^,]+)|([^,]+),([^,]+),([^,]+)|([^,]+),([^,]+),([^,]+)")
        if px and lx and ux then
            local pos = vec3(tonumber(px), tonumber(py), tonumber(pz))
            local look = vec3(tonumber(lx), tonumber(ly), tonumber(lz))
            local up = vec3(tonumber(ux), tonumber(uy), tonumber(uz))
            local isFastMode = (mode == "f" or mode == "b")
            
            if not isFastMode then
                local spreadWidth, spreadLength = (math.random() - 0.5) * 14, (math.random() - 0.5) * 14
                local rightX = (up.y * look.z) - (up.z * look.y)
                local rightZ = (up.x * look.y) - (up.y * look.x)
                pos.x, pos.z = pos.x + (rightX * spreadWidth) + (look.x * spreadLength), pos.z + (rightZ * spreadWidth) + (look.z * spreadLength)
            end
            physics.setCarVelocity(0, vec3(0, 0, 0))
            physics.setCarPosition(0, pos, -look, up)
            
            if isFastMode then
                physics.setCarVelocity(0, look * FAST_SPEED_MS)
                ui.toast(ui.Icons.Rocket, "🚀 Boost! (" .. FAST_SPEED_KMH .. " km/h)")
                fastCooldownTimer = 10.0
            else
                ui.toast(ui.Icons.Location, "📍 Teleported [Point " .. string.upper(mode) .. "]")
            end
        end
        return true
    end

    -- Radar Intercept
    if message:sub(1, 11) == "!RADAR_MSG:" then
        radarMsg, radarImg, radarTimer = "شد يا شنب جاء دورك", DEFAULT_ALERT_IMAGE, DISPLAY_TIME
        playAlertSound()
        return true
    end

    -- ===== نظام الشات العربي المخصص =====
    -- أي رسالة لم تمسكها الماركرات فوق تُعالج هنا: ترجمة، تلوين رتب، دفع للسجل، ثم return true
    -- عشان ما تظهر بشات AC الأصلي (اللي يقلب العربي). الترتيب حسّاس — الفلتر العام آخر شي.
    local msg = tostring(message)
    if msg:match("%$AS1980_CODE:([%w]+)") then return true end
    if msg:find("%$AS1980_LINKED") then return true end
    if msg:find("%$AS1980_GETCODE") then return true end
    if msg:find("%$AS1980_DRIFT:") then return true end
    if msg:find("^%$AS1980_STATS:") then return true end
    -- رسالة ملوّنة برتبة ديسكورد: "$AS1980_MSG:<color>|<emoji>|<tag>|<name>|<message>"
    local mcol, memo, mtag, mnm, mtxt = msg:match("^%$AS1980_MSG:([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
    if mnm then
        if mtxt:find("^%$AS1980_") then return true end   -- البلقن يلفّ حتى الماركرات؛ لا تعرضها ككلام
        local rr, gg, bb = mcol:match("#?(%x%x)(%x%x)(%x%x)")
        local color = rr and rgbm(tonumber(rr, 16) / 255, tonumber(gg, 16) / 255, tonumber(bb, 16) / 255, 1) or nil
        local disp = mnm .. (mtag ~= "" and ("  " .. mtag) or "") .. (memo ~= "" and (" " .. memo) or "")
        chatLog[#chatLog + 1] = { name = disp, text = mtxt, srv = false, color = color, rawName = mnm, t = pulseT }
        while #chatLog > CHAT_MAX do table.remove(chatLog, 1) end
        return true
    end
    -- الفلتر العام لبقية ماركرات AS1980 — لازم يبقى آخر شي (نقله فوق $AS1980_MSG أسكت الرتب في 11 سيرفر سابقاً)
    if msg:find("^%$AS1980_") then return true end
    -- ضجيج أوامر الأدمن
    if msg:find("not an administrator") or msg:find("Unrecognized command") then return true end
    local srv = not sender or sender < 0
    local nm = srv and "السيرفر" or (ac.getDriverName(sender) or ("لاعب " .. tostring(sender)))
    chatLog[#chatLog + 1] = { name = nm, text = translateServer(msg), srv = srv, rawName = (not srv) and nm or nil, t = pulseT }
    while #chatLog > CHAT_MAX do table.remove(chatLog, 1) end
    return true
end)

-- رسالة ترحيب (تظهر في الشات المخصص بعربي صحيح)
chatLog[#chatLog + 1] = { name = "DRIVE", text = "الشات جاهز · C للعبارات والإيموجي · Enter للإرسال", srv = true, t = 0 }

-- إخفاء رسائل الدخول/الخروج الإنجليزية من الشريط العلوي
for _, rx in ipairs({ "onnected", "joined the server", "left the server", "has left", "AS1980_", "%$AS1980" }) do
  pcall(function() ac.blockSystemMessages(rx) end)
end

---------------------------------------------------------------
-- Text helpers 
---------------------------------------------------------------
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
local function sectionTitle(title, eye, X, Y, W)
  dwLeftBox(eye, 11, X, Y + 6, 150, 14, ACC)
  dwRightBox(title, 19, X, Y, W, 24, CW)
  ui.drawRectFilled(vec2(X + W - 38, Y + 27), vec2(X + W, Y + 30), ACC, 2)
end
local function bigButton(x, y, w, h, label, col, id)
  ui.setCursor(vec2(x, y))
  local cl = ui.invisibleButton(id or ("##b" .. label), vec2(w, h))
  local hov = ui.itemHovered()
  local c = hov and rgbm(col.r * 1.14, col.g * 1.14, col.b * 1.14, 1) or col
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), c, 10)
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h * 0.5), rgbm(1, 1, 1, 0.10), 10)
  ui.drawRect(vec2(x, y), vec2(x + w, y + h), rgbm(1, 1, 1, hov and 0.35 or 0.10), 10, nil, 1)
  dwBox(label, 15, x, y, w, h, DK)
  return cl
end

---------------------------------------------------------------
-- Tabs Definition (Admin Only)
---------------------------------------------------------------
local TABS = {
  { id = 1, label = "الترافيك", icon = "🚦" },
  { id = 2, label = "الشدة",    icon = "🚀" },
  { id = 3, label = "الرادار",  icon = "📢" },
  { id = 4, label = "لاعبين",  icon = "👤" },
  { id = 5, label = "إعدادات", icon = "⚙️" },
  { id = 6, label = "جو السيرفر", icon = "🌤️" },
}

local function navIcon(id, x, y, s, c)
  ui.pushDWriteFont(FONT)
  dwBox(TABS[id].icon, 20, x, y + s * 0.5, s, s, c)
  ui.popDWriteFont()
end

---------------------------------------------------------------
-- Admin Tabs Content
---------------------------------------------------------------
-- =========================================================
-- تبويب [1] الترافيك: التحكم بسيارات الترافيك (STOP cars)
--   القوائم (السيارات + التخطيطات) تجي من السيرفر عبر "/traffic list"
--   حفظ موقع / كاميرا حرة / تحريك دقيق بالـ Step / حفظ واستدعاء تخطيطات
--   * نفس منطق البلقن الأصلي: يرسل رقم السيارة (selectedBotIndex) مباشرة
-- =========================================================
local function drawTrafficAdmin(X, Y, W, H)
    if not didInitialFetchTFC then didInitialFetchTFC = true; requestTrafficList() end
    sectionTitle("إدارة الترافيك", "TRAFFIC", X, Y, W)
    local curY = Y + 48
    local gap = 10
    local btnW = (W - gap) / 2

    if bigButton(X, curY, W, 34, "🔄 تحديث القوائم", rgbm(0.16, 0.16, 0.18, 1), "##tfc_ref") then requestTrafficList() end
    curY = curY + 44

    local selName = botsList[selectedBotIndex] and botDisplayName(botsList[selectedBotIndex]) or "?"
    if bigButton(X, curY, btnW, 34, "◀ السيارة السابقة", rgbm(0.2, 0.2, 0.23, 1), "##tfc_p1") then
        selectedBotIndex = selectedBotIndex - 1; if selectedBotIndex < 1 then selectedBotIndex = #botsList end
    end
    if bigButton(X + btnW + gap, curY, btnW, 34, "السيارة التالية ▶", rgbm(0.2, 0.2, 0.23, 1), "##tfc_n1") then
        selectedBotIndex = selectedBotIndex + 1; if selectedBotIndex > #botsList then selectedBotIndex = 1 end
    end
    curY = curY + 42

    dwBox("المحدد [" .. selectedBotIndex .. "/" .. #botsList .. "]: " .. selName, 15, X, curY, W, 22, CC)
    curY = curY + 30

    if bigButton(X, curY, W, 38, "📍 حفظ موقع هذه السيارة", ACC, "##tfc_sv") then ac.sendChatMessage("/traffic setpoint " .. selectedBotIndex) end
    curY = curY + 48
    if bigButton(X, curY, W, 38, "👁️ كاميرا حرة للسيارة", rgbm(0.15, 0.5, 0.15, 1), "##tfc_fc") then ac.sendChatMessage("/traffic goto " .. selectedBotIndex) end
    curY = curY + 48

    if bigButton(X, curY, btnW, 34, "تنزيل السيارة", rgbm(0.2, 0.2, 0.23, 1), "##tfc_sp") then ac.sendChatMessage("/traffic spawn " .. selectedBotIndex) end
    if bigButton(X + btnW + gap, curY, btnW, 34, "إخفاء السيارة", rgbm(0.2, 0.2, 0.23, 1), "##tfc_hd") then ac.sendChatMessage("/traffic hide " .. selectedBotIndex) end
    curY = curY + 46

    dwRightBox("مقدار الحركة:", 15, X, curY, W, 22, CDm)
    curY = curY + 26
    local sw = (W - 4 * 6) / 5
    for i, v in ipairs(stepOptions) do
        if bigButton(X + (i - 1) * (sw + 6), curY, sw, 30, v, selectedStepIdx == i and ACC or rgbm(0.2, 0.2, 0.23, 1), "##ts_" .. i) then selectedStepIdx = i end
    end
    curY = curY + 40

    local cs = stepOptions[selectedStepIdx]
    if bigButton(X, curY, btnW, 32, "رفع", rgbm(0.2, 0.2, 0.23, 1), "##t_u") then ac.sendChatMessage(string.format("/traffic move %d up %s", selectedBotIndex, cs)) end
    if bigButton(X + btnW + gap, curY, btnW, 32, "تنزيل", rgbm(0.2, 0.2, 0.23, 1), "##t_d") then ac.sendChatMessage(string.format("/traffic move %d down %s", selectedBotIndex, cs)) end
    curY = curY + 40
    if bigButton(X, curY, btnW, 32, "للخلف", rgbm(0.2, 0.2, 0.23, 1), "##t_b") then ac.sendChatMessage(string.format("/traffic move %d back %s", selectedBotIndex, cs)) end
    if bigButton(X + btnW + gap, curY, btnW, 32, "للأمام", rgbm(0.2, 0.2, 0.23, 1), "##t_f") then ac.sendChatMessage(string.format("/traffic move %d forward %s", selectedBotIndex, cs)) end
    curY = curY + 40
    if bigButton(X, curY, btnW, 32, "يسار", rgbm(0.2, 0.2, 0.23, 1), "##t_l") then ac.sendChatMessage(string.format("/traffic move %d left %s", selectedBotIndex, cs)) end
    if bigButton(X + btnW + gap, curY, btnW, 32, "يمين", rgbm(0.2, 0.2, 0.23, 1), "##t_r") then ac.sendChatMessage(string.format("/traffic move %d right %s", selectedBotIndex, cs)) end
    curY = curY + 40
    if bigButton(X, curY, btnW, 32, "دوران يسار", rgbm(0.2, 0.2, 0.23, 1), "##t_rl") then ac.sendChatMessage(string.format("/traffic move %d rotleft %s", selectedBotIndex, cs)) end
    if bigButton(X + btnW + gap, curY, btnW, 32, "دوران يمين", rgbm(0.2, 0.2, 0.23, 1), "##t_rr") then ac.sendChatMessage(string.format("/traffic move %d rotright %s", selectedBotIndex, cs)) end
    curY = curY + 46

    dwBox("إدارة التخطيطات (الماب: " .. mapName .. ")", 15, X, curY, W, 22, ACC)
    curY = curY + 28
    dwBox("التخطيطات المحفوظة: " .. (#presetsList > 0 and (selectedPresetIndex .. "/" .. #presetsList) or "0/0"), 13, X, curY, W, 18, CDm)
    curY = curY + 24
    if bigButton(X, curY, btnW, 32, "◀ التخطيط السابق", rgbm(0.2, 0.2, 0.23, 1), "##p_prev") then
        if #presetsList > 0 then
            selectedPresetIndex = selectedPresetIndex - 1; if selectedPresetIndex < 1 then selectedPresetIndex = #presetsList end
            presetName = presetsList[selectedPresetIndex] or presetName
        end
    end
    if bigButton(X + btnW + gap, curY, btnW, 32, "التخطيط التالي ▶", rgbm(0.2, 0.2, 0.23, 1), "##p_next") then
        if #presetsList > 0 then
            selectedPresetIndex = selectedPresetIndex + 1; if selectedPresetIndex > #presetsList then selectedPresetIndex = 1 end
            presetName = presetsList[selectedPresetIndex] or presetName
        end
    end
    curY = curY + 42

    ui.setCursor(vec2(X, curY))
    ui.pushItemWidth(W)
    presetName = ui.inputText("##presetname", presetName, 8, "اسم الملف...")
    if ui.itemActive() or ui.itemFocused() then pcall(function() ac.setCurrentInputMethod(ac.UserInputMode.UI); ui.captureKeyboard(true) end) end
    ui.popItemWidth()
    curY = curY + 42

    if bigButton(X, curY, btnW, 38, "💾 حفظ التخطيط", ACC, "##p_save") then
        ac.sendChatMessage("/traffic save " .. presetName); ui.toast(ui.Icons.Save, "Saved: " .. presetName)
        setTimeout(requestTrafficList, 0.4)
    end
    if bigButton(X + btnW + gap, curY, btnW, 38, "📂 استدعاء التخطيط", rgbm(0.15, 0.5, 0.15, 1), "##p_load") then
        ac.sendChatMessage("/traffic load " .. presetName); ui.toast(ui.Icons.Confirm, "Loading: " .. presetName)
    end
    curY = curY + 46
    if bigButton(X, curY, W, 34, "🗑️ حذف التخطيط", rgbm(0.6, 0.15, 0.15, 1), "##p_del") then
        ac.sendChatMessage("/traffic delete " .. presetName); ui.toast(ui.Icons.Confirm, "Deleted: " .. presetName)
        setTimeout(requestTrafficList, 0.4)
    end
end

-- =========================================================
-- تبويب [2] الشدة: نقاط تلفريك سريعة للأدمن
-- =========================================================
local function drawShaddaAdmin(X, Y, W, H)
    sectionTitle("إدارة الشدة", "SHADDA", X, Y, W)
    local curY = Y + 48
    local sbw = (W - 100 - 16) / 3
    local function dShRow(slot)
        dwBox("SLOT [" .. slot .. "]", 15, X, curY, 90, 32, CY)
        if bigButton(X + 100, curY, sbw, 32, "حفظ", rgbm(0.15, 0.5, 0.15, 1), "##shs_" .. slot) then ac.sendChatMessage("/shadda set " .. slot:lower() .. " " .. getShaddaCoordinates()) end
        if bigButton(X + 100 + sbw + 8, curY, sbw, 32, "مسح", rgbm(0.6, 0.15, 0.15, 1), "##shc_" .. slot) then ac.sendChatMessage("/shadda clear " .. slot:lower()) end
        if bigButton(X + 100 + 2 * (sbw + 8), curY, sbw, 32, "تجربة", rgbm(0.2, 0.2, 0.23, 1), "##sht_" .. slot) then ac.sendChatMessage("/shadda tp " .. slot:lower()) end
        curY = curY + 42
    end
    dwLeftBox("📍 نقاط الوقوف الثابتة (منطقة آمنة):", 15, X, curY, W, 22, ACC); curY = curY + 32
    dShRow("T"); dShRow("U"); dShRow("O"); dShRow("K")
    curY = curY + 16
    dwLeftBox("🚀 نقاط الانطلاق السريع:", 15, X, curY, W, 22, ACC); curY = curY + 32
    dShRow("F"); dShRow("B")
end

-- =========================================================
-- تبويب [3] الرادار والتنبيهات
-- =========================================================
local function drawRadarAdmin(X, Y, W, H)
    sectionTitle("الرادار والتنبيهات", "RADAR & ALERT", X, Y, W)
    local curY = Y + 48
    local gap = 10
    local btnW = (W - gap) / 2

    if bigButton(X, curY, btnW, 36, "📍 تحديد نقطة الرادار", ACC, "##rad_s") then ac.sendChatMessage("/radar set") end
    if bigButton(X + btnW + gap, curY, btnW, 36, "🗑️ إزالة الرادار", rgbm(0.2, 0.2, 0.23, 1), "##rad_c") then ac.sendChatMessage("/radar clear"); localSkipState = {} end
    curY = curY + 48

    dwLeftBox("👥 قائمة استثناء اللاعبين:", 15, X, curY, W, 22, CW); curY = curY + 28
    ui.setCursor(vec2(X, curY))
    ui.childWindow("##rad_skip", vec2(W, 210), function()
        local simC = ac.getSim()
        for i = 0, simC.carsCount - 1 do
            local c = ac.getCar(i)
            if c and c.isConnected then
                local n = ac.getDriverName(i)
                if n ~= "" and not string.find(n, "^Traffic") then
                    local sid = c.sessionID
                    local ry = ui.getCursorY()
                    ui.setCursor(vec2(0, ry))
                    ui.drawRectFilled(vec2(0, ry), vec2(W, ry + 34), rgbm(1, 1, 1, 0.03), 6)
                    dwLeftBox(n .. " [S" .. sid .. "]", 14, 12, ry, W - 120, 34, CW)
                    if localSkipState[sid] then
                        if bigButton(W - 100, ry + 4, 90, 26, "إلغاء الاستثناء", rgbm(0.6, 0.2, 0.2, 1), "##un_" .. sid) then ac.sendChatMessage("/radar unskip " .. sid); localSkipState[sid] = false end
                    else
                        if bigButton(W - 100, ry + 4, 90, 26, "استثناء", rgbm(0.15, 0.5, 0.15, 1), "##sk_" .. sid) then ac.sendChatMessage("/radar skip " .. sid); localSkipState[sid] = true end
                    end
                    ui.dummy(vec2(0, 40))
                end
            end
        end
    end)
    curY = curY + 222

    dwLeftBox("📢 إرسال تنبيه جماعي", 16, X, curY, W, 24, ACC); curY = curY + 30

    -- صندوق الكتابة — نفس طريقة شات المنيو:
    -- ui.inputText الحقيقي يُرسم أولاً ثم يُغطّى بمستطيل معتم، والنص يُرسم يدوياً بـ
    -- DirectWrite بمحاذاة يمين مع التفاف، فيظهر العربي مشبوكاً وصحيحاً بدل المقلوب.
    -- الصندوق يكبر مع طول الرسالة (لأسفل هنا، لأن المساحة تحته فاضية عكس شريط الشات).
    -- منطقة الضغط للتركيز هي أعلى الصندوق: ارتفاع الودجت الأصلي ثابت ولا يكبر معه.
    local prevText = radarInputMsg:gsub("_", " ")
    local prevW = W - 96
    local boxH = 34
    if prevText:gsub("%s", "") ~= "" then
        ui.pushDWriteFont(FONT)
        local sz = ui.measureDWriteText(prevText, 17, prevW)
        ui.popDWriteFont()
        boxH = math.max(34, math.min(120, math.ceil(sz.y) + 14))
    end

    ui.setCursor(vec2(X + 8, curY + 3))
    ui.pushItemWidth(W - 92)
    local nt, changed, entered = ui.inputText("##alertmsg" .. radarInputGen, radarInputMsg, ui.InputTextFlags.RetainSelection)
    if changed then radarInputMsg = nt end
    if ui.itemActive() or ui.itemFocused() then pcall(function() ac.setCurrentInputMethod(ac.UserInputMode.UI); ui.captureKeyboard(true) end) end
    ui.popItemWidth()

    ui.drawRectFilled(vec2(X, curY), vec2(X + W - 76, curY + boxH), rgbm(0.11, 0.115, 0.14, 1), 8)
    ui.drawRect(vec2(X, curY), vec2(X + W - 76, curY + boxH), rgbm(ACC.r, ACC.g, ACC.b, 0.35), 8, nil, 1)
    if prevText:gsub("%s", "") ~= "" then
        ui.pushDWriteFont(FONT)
        ui.setCursor(vec2(X + 10, curY + 5))
        ui.dwriteTextAligned(prevText, 17, ui.Alignment.End, ui.Alignment.Start, vec2(prevW, boxH - 10), true, CW)
        ui.popDWriteFont()
    else
        dwRightBox("اكتب رسالتك هنا...", 15, X + 10, curY, prevW, 34, CDm)
    end

    if bigButton(X + W - 72, curY, 72, 28, "مسافة", rgbm(0.2, 0.2, 0.23, 1), "##al_spc") then
        radarInputMsg = radarInputMsg .. " "
        radarInputGen = radarInputGen + 1
    end
    curY = curY + boxH + 8

    local can = radarInputMsg:gsub("%s", "") ~= ""
    if (bigButton(X, curY, W, 38, "إرسال للجميع", can and ACC or rgbm(0.2, 0.2, 0.23, 1), "##al_snd") or entered) and can then
        local fMsg = radarInputMsg:gsub("_", " ")
        myNonceCounter = myNonceCounter + 1
        local nnc = (os.time() * 1000) + myNonceCounter
        pcall(function() AlertEvent({ nonce = nnc, msg = fMsg, img = DEFAULT_ALERT_IMAGE }, true) end)
        lastMassNonce = nnc
        massMsg, massImg, massTimer = fMsg, DEFAULT_ALERT_IMAGE, DISPLAY_TIME
        playAlertSound()
        radarInputMsg = ""
        radarInputGen = radarInputGen + 1
    end
end

---------------------------------------------------------------
-- Main rendering (Window logic)
---------------------------------------------------------------
-- =========================================================
-- تبويب [4] اللاعبين: كيك / باند / بت / تحقق من الستيم
-- =========================================================
local function drawPlayersAdmin(X, Y, W, H)
    sectionTitle("إدارة اللاعبين", "PLAYERS", X, Y, W)
    local curY = Y + 48

    dwLeftBox("سبب الطرد / الحظر:", 15, X, curY, W, 22, CDm); curY = curY + 28
    ui.setCursor(vec2(X, curY))
    ui.pushItemWidth(W)
    kickReason = ui.inputText("##kreason", kickReason, 100, "اكتب السبب (اختياري)...")
    if ui.itemActive() or ui.itemFocused() then pcall(function() ac.setCurrentInputMethod(ac.UserInputMode.UI); ui.captureKeyboard(true) end) end
    ui.popItemWidth()
    curY = curY + 42

    local sim = ac.getSim()
    local found = false
    for i = 0, sim.carsCount - 1 do
        local c = ac.getCar(i)
        if c and c.isConnected then
            local n = ac.getDriverName(i)
            if n ~= "" and not string.find(n, "^Traffic") then
                found = true
                dwBox("[" .. i .. "] " .. n, 15, X, curY, W, 24, CY); curY = curY + 28
                local bw = (W - 3 * 8) / 4
                if bigButton(X, curY, bw, 32, "نرجع بت", rgbm(0.2, 0.2, 0.23, 1), "##pit_" .. i) then ac.sendChatMessage("/pit " .. n) end
                if bigButton(X + (bw + 8), curY, bw, 32, "تحقق ستيم", rgbm(0.16, 0.16, 0.18, 1), "##who_" .. i) then
                    local sid = tostring(ac.getUserSteamID(i) or "")
                    if sid ~= "" and sid ~= "0" then ac.setClipboadText(sid); ui.toast(ui.Icons.Copy, "Steam ID: " .. sid) end
                    ac.sendChatMessage('/whois "' .. n .. '"')
                end
                if bigButton(X + 2 * (bw + 8), curY, bw, 32, "طرد كيك", ACC, "##kick_" .. i) then ac.sendChatMessage('/kick "' .. n .. '" ' .. kickReason) end
                if bigButton(X + 3 * (bw + 8), curY, bw, 32, "حظر باند", rgbm(0.6, 0.15, 0.15, 1), "##ban_" .. i) then ac.sendChatMessage('/ban "' .. n .. '" ' .. kickReason) end
                curY = curY + 40
            end
        end
    end
    if not found then dwLeftBox("لا يوجد لاعبين متصلين", 14, X, curY, W, 22, CDm) end
end

-- =========================================================
-- تبويب [5] إعدادات: ارتفاع الترافيك + سرعة الترافيك (فقط)
-- =========================================================
local function drawSettingsAdmin(X, Y, W, H)
    sectionTitle("إعدادات الترافيك", "SETTINGS", X, Y, W)
    local curY = Y + 48

    dwLeftBox("ارتفاع الترافيك عن الشارع (Spline Offset):", 15, X, curY, W, 22, ACC); curY = curY + 30
    ui.setCursor(vec2(X, curY))
    ui.pushItemWidth(W - 96)
    aiSplineOffset = ui.slider("##ai_spl", aiSplineOffset, -5.0, 5.0, "%.2f m")
    ui.popItemWidth()
    if bigButton(X + W - 90, curY, 90, 28, "تطبيق", rgbm(0.15, 0.5, 0.15, 1), "##ai_spl_ap") then
        ac.sendChatMessage("/set Extra.AiParams.SplineHeightOffsetMeters " .. math.round(aiSplineOffset, 2))
        ui.toast(ui.Icons.Confirm, "Height applied")
    end
    curY = curY + 48

    dwLeftBox("سرعة الترافيك القصوى (km/h):", 15, X, curY, W, 22, ACC); curY = curY + 30
    ui.setCursor(vec2(X, curY))
    ui.pushItemWidth(W - 96)
    aiTrafficSpeed = ui.slider("##ai_spd", aiTrafficSpeed, 0, 200, "%.0f km/h")
    ui.popItemWidth()
    if bigButton(X + W - 90, curY, 90, 28, "تطبيق", rgbm(0.15, 0.5, 0.15, 1), "##ai_spd_ap") then
        ac.sendChatMessage("/set Extra.AiParams.MaxSpeedKph " .. math.round(aiTrafficSpeed, 0))
        ui.toast(ui.Icons.Confirm, "Speed applied")
    end
    curY = curY + 48

    dwLeftBox("ملاحظة: أوامر /set تحتاج صلاحية أدمن على السيرفر.", 13, X, curY, W, 18, CDm)
end

-- =========================================================
-- تبويب [6] جو السيرفر: تغيير الوقت + الطقس (فقط)
-- =========================================================
local function drawWeatherAdmin(X, Y, W, H)
    sectionTitle("جو السيرفر", "WEATHER", X, Y, W)
    local curY = Y + 48

    -- الوقت
    dwLeftBox("وقت السيرفر (الساعة):", 15, X, curY, W, 22, ACC); curY = curY + 30
    ui.setCursor(vec2(X, curY))
    ui.pushItemWidth(W - 96)
    srvHour = ui.slider("##srv_hour", srvHour, 0, 23, "%.0f:00")
    ui.popItemWidth()
    if bigButton(X + W - 90, curY, 90, 28, "تطبيق", rgbm(0.15, 0.5, 0.15, 1), "##srv_hr_ap") then
        ac.sendChatMessage(string.format("/settime %02d:00", math.floor(srvHour + 0.5)))
        ui.toast(ui.Icons.Confirm, "Time set")
    end
    curY = curY + 44

    -- أوقات سريعة
    local qgap = 8
    local qbw = (W - 3 * qgap) / 4
    local quick = { { "فجر", 6 }, { "ظهر", 12 }, { "مغرب", 18 }, { "ليل", 0 } }
    for i, q in ipairs(quick) do
        local sel = math.floor(srvHour + 0.5) == q[2]
        local col = sel and ACC or rgbm(0.82, 0.42, 0.08, 1)
        if bigButton(X + (i - 1) * (qbw + qgap), curY, qbw, 30, q[1], col, "##qt_" .. i) then
            srvHour = q[2]
            ac.sendChatMessage(string.format("/settime %02d:00", q[2]))
            ui.toast(ui.Icons.Confirm, "Time set")
        end
    end
    curY = curY + 48

    -- الطقس (قائمة الأجواء مرتّبة)
    dwLeftBox("الطقس:", 15, X, curY, W, 22, ACC); curY = curY + 30
    local wlist = {}
    for name, val in pairs(ac.WeatherType) do
        if type(name) == "string" and type(val) == "number" then
            wlist[#wlist + 1] = { name = name, val = val }
        end
    end
    table.sort(wlist, function(a, b) return a.val < b.val end)
    local curW = ac.getSim().weatherType
    local curName = "—"
    for _, it in ipairs(wlist) do if it.val == curW then curName = it.name end end
    ui.setCursor(vec2(X, curY))
    ui.setNextItemWidth(W)
    ui.combo("##srv_weather", curName, ui.ComboFlags.HeightLarge, function()
        for _, it in ipairs(wlist) do
            if ui.selectable(it.name, it.val == curW) then
                ac.sendChatMessage("/setcspweather " .. it.val .. " " .. math.floor(srvWeatherDur + 0.5))
                ui.toast(ui.Icons.Confirm, "Weather changed: " .. it.name)
            end
        end
    end)
    curY = curY + 42

    -- مدة الانتقال
    dwLeftBox("مدة الانتقال (ثانية):", 15, X, curY, W, 22, ACC); curY = curY + 30
    ui.setCursor(vec2(X, curY))
    ui.pushItemWidth(W)
    srvWeatherDur = ui.slider("##srv_wdur", srvWeatherDur, 0, 360, "%.0f ث")
    ui.popItemWidth()
    curY = curY + 46

    dwLeftBox("ملاحظة: /settime و /setcspweather تحتاجان صلاحية أدمن على السيرفر.", 13, X, curY, W, 32, CDm)
end

local function drawLogo(x0, y0, x1, y1)
  local boxW, boxH = x1 - x0, y1 - y0
  if LOGO_URL ~= "" then
    local sz = ui.imageSize(LOGO_URL)
    if sz and sz.x > 1 and sz.y > 1 then
      local sc = math.min(boxW / sz.x, boxH / sz.y)
      local dw, dh = sz.x * sc, sz.y * sc
      local ix, iy = x0 + (boxW - dw) * 0.5, y0 + (boxH - dh) * 0.5
      ui.drawImage(LOGO_URL, vec2(ix, iy), vec2(ix + dw, iy + dh))
      return
    else ui.decodeImage(LOGO_URL) end
  end
  dwBox("DRIVE", 26, x0, y0, boxW, boxH, CW)
end

local function mainUI()
  if not panelOpen then pcall(function() ui.setWindowSize(vec2(1, 1)) end); ui.setCursor(vec2(0, 0)); ui.dummy(vec2(1, 1)); return end
  pcall(function() ui.setWindowSize(vec2(math.clamp(sizeStore.pw, 640, 1500), math.clamp(sizeStore.ph, 560, 1200))) end)
  local W = ui.windowWidth(); local H = ui.windowHeight()
  if not W or W < 300 then W = math.clamp(sizeStore.pw, 640, 1500) end
  if not H or H < 300 then H = math.clamp(sizeStore.ph, 560, 1200) end

  ui.drawRectFilled(vec2(0, 0), vec2(W, H), BGD, 14)
  for s = 1, 3 do ui.drawRectFilled(vec2(0, 0), vec2(W, 80 + s * 22), rgbm(ACC.r, ACC.g, ACC.b, 0.015), 14) end
  ui.drawRect(vec2(0, 0), vec2(W, H), rgbm(1, 1, 1, 0.09), 14, nil, 1)

  local NAV = 158
  drawLogo(16, 16, NAV - 16, 64)
  ui.drawLine(vec2(NAV, 16), vec2(NAV, H - 16), rgbm(1, 1, 1, 0.07), 1)

  local itemH, ny0 = 48, 92
  for i, tab in ipairs(TABS) do
    local iy = ny0 + (i - 1) * (itemH + 8)
    ui.setCursor(vec2(10, iy))
    local cl = ui.invisibleButton("##nv" .. tab.id, vec2(NAV - 20, itemH))
    local hov = ui.itemHovered()
    local sel = activeTab == tab.id
    if sel then
      ui.drawRectFilled(vec2(10, iy), vec2(NAV - 10, iy + itemH), rgbm(ACC.r, ACC.g, ACC.b, 0.18), 10)
      ui.drawRectFilled(vec2(10, iy), vec2(NAV - 10, iy + itemH), rgbm(ACC.r, ACC.g, ACC.b, 0.06), 10)
      ui.drawRectFilled(vec2(NAV - 13, iy + 8), vec2(NAV - 10, iy + itemH - 8), ACC, 2)
    elseif hov then
      ui.drawRectFilled(vec2(10, iy), vec2(NAV - 10, iy + itemH), rgbm(1, 1, 1, 0.05), 10)
    end
    navIcon(tab.id, NAV - 42, iy + 4, 22, sel and ACC or CDm)
    dwRightBox(tab.label, 17, 8, iy, NAV - 60, itemH, sel and CW or CDm)
    if cl then
      activeTab = tab.id
      if tab.id == 1 then requestTrafficList() end  -- حدّث قوائم الترافيك/البريسيت عند فتح التبويب
    end
  end
  dwBox("غلق: زر  \\", 11, 0, H - 40, NAV, 14, CDm)
  dwBox("DRIVE ©", 10, 0, H - 22, NAV, 12, CDm)

  local CX = NAV + 16
  local CWid = W - CX - 16
  dwBox("● ADMIN", 12, CX, 14, 100, 16, CGR)

  ui.setCursor(vec2(W - 42, 12))
  local xcl = ui.invisibleButton("##close", vec2(30, 30))
  local xhov = ui.itemHovered()
  ui.drawRectFilled(vec2(W - 42, 12), vec2(W - 12, 42), xhov and rgbm(0.9, 0.25, 0.2, 0.95) or rgbm(1, 1, 1, 0.06), 8)
  ui.drawRect(vec2(W - 42, 12), vec2(W - 12, 42), rgbm(1, 1, 1, 0.12), 8, nil, 1)
  ui.drawLine(vec2(W - 36, 18), vec2(W - 18, 36), xhov and CW or CDm, 2)
  ui.drawLine(vec2(W - 18, 18), vec2(W - 36, 36), xhov and CW or CDm, 2)
  if xcl then panelOpen = false end

  local CY0 = 50
  local CHt = H - CY0 - 18

  -- محتوى التبويب داخل نافذة قابلة للتمرير (سكرول) — تتأقلم مع حجم النافذة الفعلي
  ui.setCursor(vec2(CX, CY0))
  ui.childWindow("##adm_scroll", vec2(CWid, CHt), function()
    local iw = ui.windowWidth()
    if activeTab == 1 then drawTrafficAdmin(4, 2, iw - 12, CHt)
    elseif activeTab == 2 then drawShaddaAdmin(4, 2, iw - 12, CHt)
    elseif activeTab == 3 then drawRadarAdmin(4, 2, iw - 12, CHt)
    elseif activeTab == 4 then drawPlayersAdmin(4, 2, iw - 12, CHt)
    elseif activeTab == 5 then drawSettingsAdmin(4, 2, iw - 12, CHt)
    elseif activeTab == 6 then drawWeatherAdmin(4, 2, iw - 12, CHt)
    end
  end)

  local hs = 24
  ui.setCursor(vec2(W - hs, H - hs))
  ui.invisibleButton("##resize", vec2(hs, hs))
  if ui.itemHovered() and ui.mouseDown() then resizing = true end
  if not ui.mouseDown() then resizing = false end
  if resizing then
    local md = ui.mouseDelta()
    sizeStore.pw = math.clamp(sizeStore.pw + md.x, 580, 1400)
    sizeStore.ph = math.clamp(sizeStore.ph + md.y, 480, 1100)
  end
  local gc = resizing and ACC or (ui.itemHovered() and CW or CDm)
  ui.drawLine(vec2(W - 7, H - 24), vec2(W - 24, H - 7), gc, 1.6)
  ui.drawLine(vec2(W - 7, H - 17), vec2(W - 17, H - 7), gc, 1.6)
  ui.drawLine(vec2(W - 7, H - 10), vec2(W - 10, H - 7), gc, 1.6)
end


---------------------------------------------------------------
-- Background Logic (Update)
---------------------------------------------------------------
function script.update(dt)
  pulseT = pulseT + dt
  local canCap = true
  if type(ui.wantCaptureKeyboard) == "function" and ui.wantCaptureKeyboard() then canCap = false end
  if type(ac.isChatOpen) == "function" and ac.isChatOpen() then canCap = false end

  local ckn = canCap and ui.keyboardButtonDown(CLOSE_KEY)
  if ckn and not prevCloseKey then panelOpen = not panelOpen end
  prevCloseKey = ckn

  -- زر C يفتح/يقفل الشات (مع نفس حارس canCap عشان الكتابة ما تقفله)
  local ckC = canCap and ui.keyboardButtonDown(ui.KeyIndex.C)
  if ckC and not cSt.prevC then
    chatBarOpen = not chatBarOpen
    if chatBarOpen then chatBarJustOpened = true; cSt.chatBarIdle = pulseT; cSt.chatMin = false end
  end
  cSt.prevC = ckC

  if fastCooldownTimer > 0 then fastCooldownTimer = fastCooldownTimer - dt end
  if radarTimer > 0 then radarTimer = math.max(0, radarTimer - dt) end
  if massTimer  > 0 then massTimer  = math.max(0, massTimer - dt) end
  if soundHold  > 0 then soundHold  = math.max(0, soundHold - dt) end

  if canCap then
      for keyName, keyIndex in pairs(SHADDA_KEYS) do
          local isDown = ui.keyboardButtonDown(keyIndex)
          if isDown and not shaddaLastStates[keyName] then
              if keyName == "F" or keyName == "B" then
                  if fastCooldownTimer <= 0 then ac.sendChatMessage("/shadda tp " .. string.lower(keyName))
                  else ui.toast(ui.Icons.Warning, string.format("⏳ Wait %.1f s!", fastCooldownTimer)) end
              else ac.sendChatMessage("/shadda tp " .. string.lower(keyName)) end
          end
          shaddaLastStates[keyName] = isDown
      end
  end
end

---------------------------------------------------------------
-- Alert Overlays
---------------------------------------------------------------
local function drawAlertBox(msg, img, timer, windowId)
  local winSize = ac.getUI().windowSize
  local sx = (winSize.x - ALERT_W) * 0.5
  local sy = winSize.y * 0.15
  ui.transparentWindow(windowId, vec2(sx, sy), vec2(ALERT_W, ALERT_H), false, function()
    if img ~= "" and ui.isImageReady(img) then
      ui.drawImage(img, vec2(0, 0), vec2(ALERT_W, ALERT_H))
      ui.drawRectFilled(vec2(0, 0), vec2(ALERT_W, ALERT_H), rgbm(0, 0, 0, 0.05), 10)
    else
      if img ~= "" then ui.decodeImage(img) end
      ui.drawRectFilled(vec2(0, 0), vec2(ALERT_W, ALERT_H), rgbm(0.08, 0.09, 0.13, 0.92), 10)
    end
    ui.drawRect(vec2(0.5, 0.5), vec2(ALERT_W - 0.5, ALERT_H - 0.5), rgbm(ACC.r, ACC.g, ACC.b, 0.6), 10, nil, 1.5)
    ui.pushDWriteFont(FONT)
    dwBox("⚠ تنبيه", 14, 0, 8, ALERT_W, 20, ACC)
    dwBox(msg, 24, 10, 40, ALERT_W - 20, ALERT_H - 70, CW)
    ui.popDWriteFont()
    local pct = timer / DISPLAY_TIME
    ui.drawRectFilled(vec2(10, ALERT_H - 10), vec2(ALERT_W - 10, ALERT_H - 7), rgbm(0, 0, 0, 0.4), 2)
    ui.drawRectFilled(vec2(10, ALERT_H - 10), vec2(10 + (ALERT_W - 20) * pct, ALERT_H - 7), ACC, 2)
  end, ui.WindowFlags.NoInputs + ui.WindowFlags.NoMouseInputs)
end

---------------------------------------------------------------
-- Custom Arabic chat (log + bar) — transplanted from 1980 menu
---------------------------------------------------------------
local function drawChatLog(sim)
  if #chatLog == 0 then return end
  if chatBarOpen and not cSt.chatMin then return end   -- show the floating log when the bar is minimized or closed
  local recent = {}
  for i = #chatLog, math.max(1, #chatLog - 7), -1 do
    if pulseT - chatLog[i].t < 16 then table.insert(recent, 1, chatLog[i]) end
  end
  if #recent == 0 then return end
  local w = 640
  local nameW = 224
  local textW = w - nameW - 24
  -- reserve the REAL wrapped height per message (measured at the exact width/size used to draw below)
  -- fixes overlap: the old byte-length guess under-counted lines for Latin/URLs, so text bled onto the next row
  local hs, total = {}, 8
  for i, m in ipairs(recent) do
    local sz = ui.measureDWriteText(m.text, 15, textW)
    hs[i] = math.max(22, math.ceil(sz.y) + 4)
    total = total + hs[i]
  end
  local cy0 = sim.windowHeight - total - 200
  ui.transparentWindow("chatlog1980", vec2(16, cy0), vec2(w, total), function()
    -- auto-hide: reveal while the mouse is over the chat, or a message just arrived; otherwise fade
    -- out. mouseLocalPos (mouse relative to THIS window) is reliable even on a no-input transparent
    -- window; the window stays present so moving the mouse over the area brings the chat back.
    local lp = ui.mouseLocalPos()
    local over = lp.x >= -6 and lp.x <= (w + 6) and lp.y >= -6 and lp.y <= (total + 6)
    local target = (over or (pulseT - chatLog[#chatLog].t < 4)) and 1 or 0
    cSt.chatReveal = (cSt.chatReveal or 1) + (target - (cSt.chatReveal or 1)) * 0.14
    local rv = cSt.chatReveal
    ui.drawRectFilled(vec2(0, 0), vec2(w, total), rgbm(0, 0, 0, 0.32 * rv), 10)
    local yy = 4
    for i, m in ipairs(recent) do
      local age = pulseT - m.t
      local a = (age > 13 and math.max(0, 1 - (age - 13) / 3) or 1) * rv
      local nc = m.color and rgbm(m.color.r, m.color.g, m.color.b, a) or (m.srv and rgbm(CY.r, CY.g, CY.b, a) or rgbm(ACC.r, ACC.g, ACC.b, a))
      dwRightBox(m.name, 14, w - nameW - 8, yy, nameW, 22, nc)
      ui.setCursor(vec2(8, yy))
      ui.dwriteTextAligned(m.text, 15, ui.Alignment.End, ui.Alignment.Start, vec2(textW, hs[i]), true, rgbm(1, 1, 1, a))
      yy = yy + hs[i]
    end
  end)
end

local function drawChatBar(sim)
  if not chatBarOpen then return end
  if cSt.chatMin then
    -- minimized to a small tab: HOVER it to bring the full chat back (no need to press C again)
    local hw, hh = 116, 28
    local hx = (cSt.chatMidX or (sim.windowWidth * 0.5)) - hw * 0.5
    local hy = (cSt.chatBotY or (sim.windowHeight - 120)) - hh
    hx = math.max(0, math.min(sim.windowWidth - hw, hx))
    hy = math.max(0, math.min(sim.windowHeight - hh, hy))
    ui.transparentWindow("chatmin1980", vec2(hx, hy), vec2(hw, hh), true, true, function()
      local hov = ui.windowHovered()
      ui.drawRectFilled(vec2(0, 0), vec2(hw, hh), rgbm(0.07, 0.075, 0.1, hov and 0.95 or 0.55), 9)
      ui.drawRect(vec2(0.5, 0.5), vec2(hw - 0.5, hh - 0.5), rgbm(ACC.r, ACC.g, ACC.b, hov and 0.9 or 0.4), 9, nil, 1.2)
      dwBox("💬 الشات", 13, 0, 4, hw, 18, hov and CW or CDm)
      if hov then cSt.chatMin = false; cSt.chatBarIdle = pulseT end   -- mouse over the tab restores it
    end)
    return
  end
  local cols = 4
  local rows = math.ceil(#QUICK_PHRASES / cols)
  local gridH = cStor.chatPhrases and rows * 48 or 0
  local histH = math.floor(cStor.chatHistH)   -- resizable (drag the grip in the bottom-left corner)
  local topY = 32
  local emojiH = cStor.chatEmoji and 140 or 0
  local bw = math.floor(cStor.chatW)          -- resizable
  local pw = cSt.showPlayers and 224 or 0   -- attached side panel width for the members list
  local bh = topY + histH + 10 + emojiH + gridH + 54
  local x0 = (sim.windowWidth - bw) * 0.5 + cStor.chatOfsX
  local y0 = sim.windowHeight - bh - 120 + cStor.chatOfsY
  x0 = math.max(-bw + 80, math.min(sim.windowWidth - 80 - pw, x0)) -- keep on screen
  y0 = math.max(0, math.min(sim.windowHeight - 60, y0))
  cSt.chatMidX = x0 + bw * 0.5; cSt.chatBotY = y0 + bh   -- remembered so the minimized tab sits at the bar's bottom-center
  ui.transparentWindow("chatbar1980", vec2(x0, y0), vec2(bw + pw, bh), true, true, function()
    ui.drawRectFilled(vec2(0, 0), vec2(bw, bh), rgbm(0.07, 0.075, 0.1, cStor.chatOpacity), 14)
    ui.drawRect(vec2(0.5, 0.5), vec2(bw - 0.5, bh - 0.5), rgbm(ACC.r, ACC.g, ACC.b, 0.5), 14, nil, 1.4)
    dwBox("الشات · Enter إرسال · يصغّر لمّا تبعد · مرّر الماوس على التاب يرجع", 13, 0, 8, bw, 20, CDm)
    dwBox("شفافية", 11, 12, 7, 52, 18, CDm)
    ui.setCursor(vec2(66, 6))
    ui.setNextItemWidth(120)
    cStor.chatOpacity = ui.slider("##chatopac", cStor.chatOpacity, 0.35, 1.0, "%.2f")
    if bigButton(bw - 136, 4, 126, 22, cSt.showPlayers and "✕ إغلاق القائمة" or "👥 الأعضاء", cSt.showPlayers and rgbm(0.6, 0.32, 0.34, 1) or rgbm(0.2, 0.5, 0.36, 1), "##pltoggle") then cSt.showPlayers = not cSt.showPlayers end
    -- show/hide the emoji strip and the quick phrases (saved per player)
    if bigButton(196, 5, 34, 20, "😀", cStor.chatEmoji and rgbm(0.2, 0.5, 0.36, 1) or rgbm(0.32, 0.32, 0.38, 1), "##emtog") then cStor.chatEmoji = not cStor.chatEmoji end
    if bigButton(234, 5, 34, 20, "💬", cStor.chatPhrases and rgbm(0.2, 0.5, 0.36, 1) or rgbm(0.32, 0.32, 0.38, 1), "##phtog") then cStor.chatPhrases = not cStor.chatPhrases end

    -- Scrollable history (all messages, correct Arabic)
    ui.drawRectFilled(vec2(10, topY), vec2(bw - 10, topY + histH), rgbm(0, 0, 0, 0.28), 10)
    ui.setCursor(vec2(10, topY))
    ui.childWindow("##chathist", vec2(bw - 20, histH), function()
      local cw = ui.windowWidth() - 18   -- reserve room for the scrollbar so names don't overlap it
      local nameW = 224
      local textW = cw - nameW - 20
      local yy = 0
      for i, m in ipairs(chatLog) do
        -- variable height: long messages wrap DOWN into extra lines instead of overflowing
        local sz = ui.measureDWriteText(m.text, 15, textW)
        local hh = math.max(24, math.ceil(sz.y) + 6)
        -- click a player's name to @mention them in the input box
        if not m.srv then
          ui.setCursor(vec2(cw - nameW - 6, yy))
          if ui.invisibleButton("##men" .. i, vec2(nameW, hh)) then
            chatInput = chatInput .. "@" .. m.name .. " "
            chatInputGen = chatInputGen + 1
          end
          if ui.itemClicked(ui.MouseButton.Right) then   -- right-click a chat name = teleport to them
            pcall(function() local ci = carByName(m.rawName); if ci then chatTP(ac.getCar(ci)) end end)
          end
          if ui.itemHovered() then
            ui.drawRectFilled(vec2(cw - nameW - 6, yy + 1), vec2(cw - 4, yy + hh - 1), rgbm(ACC.r, ACC.g, ACC.b, 0.16), 4)
          end
        end
        dwRightBox(m.name, 13, cw - nameW - 4, yy, nameW - 4, 20, m.color or (m.srv and CY or ACC))
        ui.setCursor(vec2(6, yy))
        ui.dwriteTextAligned(m.text, 15, ui.Alignment.End, ui.Alignment.Start, vec2(textW, hh), true, CW)
        yy = yy + hh
      end
      -- mark the TRUE content bottom, then keep newest in view
      ui.setCursor(vec2(0, yy + 4))
      ui.dummy(vec2(1, 1))
      if chatBarJustOpened or #chatLog > chatBarLastCount then ui.setScrollHereY(1); chatBarJustOpened = false end
      chatBarLastCount = #chatLog
    end)

    -- 👥 members SIDE PANEL (attached to the right): real players only (AI filtered via isHidingLabels)
    --    left-click = @mention · right-click = teleport to them at their speed (TPS)
    if pw > 0 then
      local px = bw + 6
      ui.drawRectFilled(vec2(px, topY), vec2(bw + pw - 4, bh - 12), rgbm(0.06, 0.07, 0.1, 0.6), 12)
      ui.drawRect(vec2(px, topY), vec2(bw + pw - 4, bh - 12), rgbm(ACC.r, ACC.g, ACC.b, 0.5), 12, nil, 1.2)
      dwBox("الأعضاء", 14, px, topY + 6, pw - 10, 18, CY)
      dwRightBox("👁 شاهده · يسار: منشن · يمين: انتقل له", 10, px + 4, topY + 26, pw - 14, 14, CDm)
      ui.setCursor(vec2(px + 6, topY + 46))
      ui.childWindow("##plistwin", vec2(pw - 16, bh - topY - 62), function()
        local sim2 = ac.getSim()
        local n = 0
        if sim2 then
          for i = 0, sim2.carsCount - 1 do
            local nm = ac.getDriverName(i)
            local c = ac.getCar(i)
            -- exclude MY car (index 0), not the focused one — otherwise whoever you're
            -- spectating disappears from the list and you can't switch away.
            if nm and nm ~= "" and c and c.isConnected and not c.isHidingLabels and i ~= 0 then
              local ry = n * 32
              -- 👁 spectate: its own button, registered BEFORE the row so it owns its clicks
              ui.setCursor(vec2(3, ry + 5))
              local eye = ui.invisibleButton("##spec" .. i, vec2(20, 20))
              local eh = ui.itemHovered()
              -- row button (mention / teleport) starts after the eye
              ui.setCursor(vec2(26, ry))
              local cl = ui.invisibleButton("##plm" .. i, vec2(pw - 60, 30))
              local rc = ui.itemClicked(ui.MouseButton.Right)
              if ui.itemHovered() then ui.drawRectFilled(vec2(26, ry), vec2(pw - 34, ry + 30), rgbm(ACC.r, ACC.g, ACC.b, 0.16), 6) end
              if eh then ui.drawRectFilled(vec2(2, ry + 4), vec2(24, ry + 26), rgbm(CY.r, CY.g, CY.b, 0.22), 5) end
              dwBox("👁", 12, 2, ry + 5, 22, 20, (eh or cSt.specOn == i) and CY or CDm)
              ui.drawCircleFilled(vec2(32, ry + 15), 3, CGR, 8)
              dwRightBox(nm, 14, 40, ry + 5, pw - 86, 20, CW)
              if eye then
                pcall(function() ac.focusCar(i) end)
                cSt.specOn, cSt.specName = i, nm
              end
              if cl then chatInput = chatInput .. "@" .. nm .. " "; chatInputGen = chatInputGen + 1 end
              if rc then chatTP(c) end
              n = n + 1
            end
          end
          if n == 0 then dwBox("ما فيه لاعبين حاليًا", 12, 0, 10, pw - 26, 20, CDm) end
        end
        ui.setCursor(vec2(0, n * 32 + 4)); ui.dummy(vec2(1, 1))
      end)
    end

    -- Emoji area: 3 most-used (top) + all emojis (scrollable). Click inserts into your message.
    local recY = topY + histH + 6
    if cStor.chatEmoji then
    local recs = { cStor.rec1, cStor.rec2, cStor.rec3 }
    for i = 1, 3 do
      local rw = 56
      local rx = 10 + (i - 1) * (rw + 6)
      ui.setCursor(vec2(rx, recY))
      local rc = ui.invisibleButton("##rec" .. i, vec2(rw, 38))
      ui.drawRectFilled(vec2(rx, recY), vec2(rx + rw, recY + 38), ui.itemHovered() and rgbm(ACC.r, ACC.g, ACC.b, 0.6) or rgbm(1, 1, 1, 0.09), 8)
      dwBox(recs[i] ~= "" and recs[i] or "·", 22, rx, recY, rw, 38, CW)
      if rc and recs[i] ~= "" then useEmoji(recs[i]) end
    end
    dwRightBox("الأكثر استخداماً", 11, 200, recY + 12, bw - 212, 16, CDm)

    local allY = recY + 44
    ui.drawRectFilled(vec2(10, allY), vec2(bw - 10, allY + 90), rgbm(0, 0, 0, 0.22), 8)
    ui.setCursor(vec2(10, allY))
    ui.childWindow("##allemoji", vec2(bw - 20, 90), function()
      local cw = ui.windowWidth()
      local ecols = 13
      local gw = (cw - 8 - (ecols - 1) * 4) / ecols
      for i, em in ipairs(EMOJIS) do
        local col = (i - 1) % ecols
        local row = math.floor((i - 1) / ecols)
        local ex = 4 + col * (gw + 4)
        local ey = 4 + row * (gw + 4)
        ui.setCursor(vec2(ex, ey))
        local ec = ui.invisibleButton("##ae" .. i, vec2(gw, gw))
        if ui.itemHovered() then ui.drawRectFilled(vec2(ex, ey), vec2(ex + gw, ey + gw), rgbm(ACC.r, ACC.g, ACC.b, 0.5), 6) end
        dwBox(em, 19, ex, ey, gw, gw, CW)
        if ec then useEmoji(em) end
      end
      ui.setCursor(vec2(0, math.ceil(#EMOJIS / ecols) * (gw + 4) + 6))
      ui.dummy(vec2(1, 1))
    end)
    end -- cStor.chatEmoji

    -- Quick phrases (sending keeps the bar open)
    local phraseY = topY + histH + 10 + emojiH
    if cStor.chatPhrases then
    local pw = (bw - 20 - (cols - 1) * 10) / cols
    for i, ph in ipairs(QUICK_PHRASES) do
      local px = 10 + ((i - 1) % cols) * (pw + 10)
      local py = phraseY + math.floor((i - 1) / cols) * 48
      ui.setCursor(vec2(px, py))
      local cl = ui.invisibleButton("##qp" .. i, vec2(pw, 40))
      local hov = ui.itemHovered()
      ui.drawRectFilled(vec2(px, py), vec2(px + pw, py + 40), hov and rgbm(ACC.r, ACC.g, ACC.b, 0.9) or rgbm(1, 1, 1, 0.06), 9)
      dwBox(ph, 15, px, py, pw, 40, hov and DK or CW)
      if cl then pcall(function() ac.sendChatMessage(ph) end) end
    end
    end -- cStor.chatPhrases

    -- Text input with a LIVE correct-Arabic preview that GROWS upward as the message gets longer
    local iy = phraseY + gridH + 8
    local prevW = bw - 140
    local th = 38
    if chatInput ~= "" then
      local sz = ui.measureDWriteText(chatInput, 16, prevW)
      th = math.max(38, math.min(124, math.ceil(sz.y) + 14))
    end
    local top = iy + 38 - th
    ui.setCursor(vec2(16, iy + 5))
    ui.setNextItemWidth(bw - 134)
    local nt, changed, entered = ui.inputText("##chatin" .. chatInputGen, chatInput, ui.InputTextFlags.RetainSelection)
    if changed then chatInput = nt end
    ui.drawRectFilled(vec2(10, top), vec2(bw - 116, iy + 38), rgbm(0.11, 0.115, 0.14, 1), 9)
    ui.drawRect(vec2(10, top), vec2(bw - 116, iy + 38), rgbm(1, 1, 1, 0.1), 9, nil, 1)
    if chatInput ~= "" then
      ui.setCursor(vec2(18, top + 4))
      ui.dwriteTextAligned(chatInput, 16, ui.Alignment.End, ui.Alignment.Start, vec2(prevW, th - 8), true, CW)
    else
      dwRightBox("اكتب رسالتك هنا...", 13, 18, iy, bw - 140, 38, CDm)
    end
    if bigButton(bw - 108, iy, 98, 38, "إرسال", chatInput ~= "" and ACC or rgbm(0.3, 0.3, 0.36, 1), "##chatsend") or (entered and chatInput ~= "") then
      if chatInput ~= "" then pcall(function() ac.sendChatMessage(chatInput) end); chatInput = ""; chatInputGen = chatInputGen + 1 end
    end

    -- move the chat window by dragging any EMPTY area (does NOT block buttons/input)
    if ui.windowHovered() and ui.mouseDown(ui.MouseButton.Left) and not ui.anyItemActive() and not chatDragging then
      chatDragging = true
      chatDragStart = ui.mousePos()
      chatOfsStart = vec2(cStor.chatOfsX, cStor.chatOfsY)
    end
    if chatDragging then
      if ui.mouseDown(ui.MouseButton.Left) then
        local mp = ui.mousePos()
        cStor.chatOfsX = chatOfsStart.x + (mp.x - chatDragStart.x)
        cStor.chatOfsY = chatOfsStart.y + (mp.y - chatDragStart.y)
      else
        chatDragging = false
      end
    end
    -- RESIZE GRIP (bottom-left corner): drag to make the chat bigger/smaller — the history area
    -- and the whole bar follow, and the size is saved per player.
    local gs = 18
    ui.setCursor(vec2(4, bh - gs - 4))
    ui.invisibleButton("##chatgrip", vec2(gs, gs))
    local gh = ui.itemHovered()
    for i = 0, 2 do
      ui.drawLine(vec2(6 + i * 4, bh - 6), vec2(6, bh - 6 - i * 4), (gh or cSt.chatSizing) and CY or rgbm(1, 1, 1, 0.35), 1.6)
    end
    if gh and ui.mouseDown(ui.MouseButton.Left) and not cSt.chatSizing then
      cSt.chatSizing = true
      cSt.gripStart = ui.mousePos()
      cSt.sizeStart = vec2(cStor.chatW, cStor.chatHistH)
    end
    if cSt.chatSizing then
      if ui.mouseDown(ui.MouseButton.Left) then
        local mp = ui.mousePos()
        cStor.chatW = math.max(560, math.min(1500, cSt.sizeStart.x - (mp.x - cSt.gripStart.x)))
        cStor.chatHistH = math.max(110, math.min(620, cSt.sizeStart.y + (mp.y - cSt.gripStart.y)))
      else
        cSt.chatSizing = false
      end
    end

    -- AUTO-HIDE (vanilla-style): keep the bar alive while the mouse is over it, while a message is
    -- being typed, or while dragging. mouseLocalPos is relative to THIS window so the bounds also
    -- cover the child areas (history / emoji / members). NOTE: 'pw' was reassigned above to the
    -- phrase width, so recompute the side-panel width here for the bounds.
    local sidePw = cSt.showPlayers and 224 or 0
    local lp = ui.mouseLocalPos()
    local overBar = lp.x >= -14 and lp.x <= (bw + sidePw + 14) and lp.y >= -14 and lp.y <= (bh + 14)
    if overBar or chatInput ~= "" or chatDragging then
      cSt.chatBarIdle = pulseT
    end
  end)
  -- move the mouse away (and stop typing) and the bar shrinks to its tab after ~3s (hover the tab to restore)
  if chatBarOpen and (pulseT - (cSt.chatBarIdle or pulseT)) > 3 then cSt.chatMin = true end
end

function script.drawUI()
  local sim = ac.getSim()
  if sim then drawChatLog(sim); drawChatBar(sim) end
  if radarTimer > 0 then drawAlertBox(radarMsg, radarImg, radarTimer, "radarAlertHUD") end
  if massTimer  > 0 then drawAlertBox(massMsg,  massImg,  massTimer,  "massAlertHUD")  end

  if soundHold > 0 then
    ui.transparentWindow("drivesnd", vec2(0, 0), vec2(2, 2), false, function() pumpSound() end, ui.WindowFlags.NoInputs + ui.WindowFlags.NoMouseInputs)
  end
end

ac.log("DRIVE Admin Master UI loaded")
if isAdmin then
ui.registerOnlineExtra(
    WINDOW_ICON,
    WINDOW_TITLE,
    function() return true end,
    mainUI,
    nil,
    ui.OnlineExtraFlags.Tool
)
end
