-- DT Drive UI Template - Welcome Banner Module
local Image = "https://i.imgur.com/NqN5leU.png"

-- التحكم بظهور القائمة
script.hideBanner = false

-- المسافة من اليسار
local MARGIN_LEFT = 60

-- الألوان الأساسية
local COLOR_ACCENT = rgbm(1.0, 0.35, 0.0, 1.0)
local COLOR_WHITE = rgbm(1, 1, 1, 1)
local COLOR_MUTED = rgbm(0.6, 0.6, 0.6, 1)

-- دالة رسم نص بمحاذاة اليسار
local function drawLeftText(text, color, y)
    ui.setCursor(vec2(MARGIN_LEFT, y))
    ui.textColored(text, color)
end

-- دالة رسم رابط يفتح في المتصفح عند الضغط
local function drawClickableLinkLeft(text, url, y)
    local textSize = ui.measureText(text)
    local pos = vec2(MARGIN_LEFT, y)
    ui.setCursor(pos)

    local isHovered = ui.rectHovered(pos, pos + textSize)
    
    if isHovered then
        ui.textColored(text, rgbm(1.0, 0.5, 0.2, 1.0))
        ui.setMouseCursor(ui.MouseCursor.Hand)
        
        -- التعديل هنا: استخدام os.open لفتح الرابط
        if ui.mouseClicked(0) then
            os.openURL(url)
            ui.toast(ui.Icons.Confirm, "DT Drive: Opening link...")
        end
    else
        ui.textColored(text, COLOR_ACCENT)
    end
end

function script.drawUI()
    if script.hideBanner then return end

    local imgSize = vec2(700, 820)
    local buttonSize = vec2(220, 40)
    local screenSize = ui.windowSize()
    local centerPos = (screenSize - imgSize) / 2

    ui.transparentWindow("WelcomeBanner", centerPos, imgSize, function()

        -- رسم صورة الخلفية
        ui.drawImage(Image, vec2(0, 0), imgSize, rgbm(1, 1, 1, 0.85))

        -- بداية النصوص على اليسار
        local y = 350

        -- Follow Us
        ui.pushFont(ui.Font.Title)
        drawLeftText("Follow Us", COLOR_WHITE, y)
        ui.popFont()

        y = y + 30
        drawClickableLinkLeft("Discord: discord.gg/DRI", "https://discord.gg/DRI", y)
        y = y + 25
        drawClickableLinkLeft("Instagram: @iiMoov", "https://instagram.com/iiMoov/", y)

        -- Rules
        y = y + 50
        ui.pushFont(ui.Font.Title)
        drawLeftText("Rules", COLOR_WHITE, y)
        ui.popFont()

        local rules = {
            {text = "Keep chat open at all times.", color = COLOR_WHITE},
            {text = "Don't ram other drivers.", color = COLOR_WHITE},
            {text = "Do not block the road.", color = rgbm(1, 0.4, 0.4, 1.0)},
            {text = "Be respectful to others.", color = COLOR_WHITE},
            {text = "No drama or spamming.", color = COLOR_WHITE},
        }

        for i, rule in ipairs(rules) do
            y = y + 28
            drawLeftText("- " .. rule.text, rule.color, y)
        end

        y = y + 45
        ui.pushFont(ui.Font.Small)
        drawLeftText("Failure to follow rules may result in a kick/ban.", COLOR_MUTED, y)
        ui.popFont()

        -- زر الإغلاق
        local buttonX = (imgSize.x - buttonSize.x) / 2
        local buttonY = imgSize.y - buttonSize.y - 30
        local buttonPos = vec2(buttonX, buttonY)

        local btnHovered = ui.rectHovered(buttonPos, buttonPos + buttonSize)
        
        if btnHovered then
            ui.drawRectFilled(buttonPos, buttonPos + buttonSize, rgbm(1.0, 0.45, 0.1, 1.0), 6)
        else
            ui.drawRectFilled(buttonPos, buttonPos + buttonSize, COLOR_ACCENT, 6)
        end
        
        local label = "I understand"
        local labelSize = ui.measureText(label)
        ui.setCursor(buttonPos + (buttonSize - labelSize) / 2)
        ui.textColored(label, rgbm(1, 1, 1, 1))

        if btnHovered and ui.mouseClicked(0) then
            script.hideBanner = true
        end
    end)
end