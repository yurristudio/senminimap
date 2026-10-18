-- SenMinimap 0.1.0 by Yurri Gaming. No external libraries required.
-- SenMapDB is retained for compatibility with migrated preferences.
local ADDON = ...
local defaults = {size=220, scale=1, x=400, y=0, point="CENTER", locked=false,
    opacity=0.96, clock=true, mail=true, friends=true, daylight=true, localTime=false,
    accent="Teal", dock="Right", zonePosition="Inside bottom", showZone=true, showZoom=true, showSettingsIcon=true,
    mailIcon=true, daylightIcon=true, hideBackground=false}
local colors = {Teal={0.56,0.90,0.87}, Ice={0.56,0.75,1}, Amber={1,0.73,0.35}}
local db, root, header, dock, settings, accentLine, zone, moveLabel, zoneOverlay
local slots, controls = {}, {}
local gear, zoomIn, zoomOut, zoneShade, trackingButton, mover, trackingMenu
local mapTop=33
local RefreshTracking, ToggleTracking
local mapButtons = {}
local pending, ready, elapsed = false, false, 0
local hiddenHost
local suppressed = setmetatable({}, {__mode="k"})
local editModeHooks = setmetatable({}, {__mode="k"})
local function say(s) print("|cff8ee6deSenMinimap:|r "..s) end
local function combat() return InCombatLockdown and InCombatLockdown() end
local function box(name, parent)
    local f=CreateFrame("Frame",name,parent,"BackdropTemplate")
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(0.035,0.043,0.055,0.96)
    f:SetBackdropBorderColor(0.14,0.17,0.20,1)
    return f
end
local function label(parent,text,size)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size or 11,"")
    f:SetTextColor(0.84,0.88,0.91)
    f:SetText(text)
    return f
end
local function tooltip(self,title,body)
    GameTooltip:SetOwner(self,"ANCHOR_LEFT")
    GameTooltip:SetText(title,0.56,0.90,0.87)
    GameTooltip:AddLine(body,0.8,0.84,0.88,true)
    GameTooltip:Show()
end
local function button(parent,text,w,h,fn)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetSize(w,h)
    b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    b:SetBackdropColor(0.075,0.095,0.12,1)
    b:SetBackdropBorderColor(0.18,0.23,0.28,1)
    b.text=label(b,text,11); b.text:SetPoint("CENTER")
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(0.56,0.90,0.87,1) end)
    b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(0.18,0.23,0.28,1); GameTooltip:Hide() end)
    b:SetScript("OnClick",fn)
    return b
end
-- Original vector-style UI icons; crisp at the dock's native size.
local function icon(parent,kind)
    local f=CreateFrame("Frame",nil,parent)
    f:SetSize(20,20); f:SetPoint("CENTER"); f:EnableMouse(false)
    f.lines={}
    local function line(x1,y1,x2,y2)
        local l=f:CreateTexture(nil,"ARTWORK")
        local dx,dy=x2-x1,y2-y1
        l:SetSize(math.sqrt(dx*dx+dy*dy)+0.6,1.6)
        l:SetPoint("CENTER",f,"CENTER",(x1+x2)/2,(y1+y2)/2)
        local angle
        if dx==0 then angle=dy>=0 and math.pi/2 or -math.pi/2
        else angle=math.atan(dy/dx); if dx<0 then angle=angle+math.pi end end
        l:SetRotation(angle)
        f.lines[#f.lines+1]=l
    end
    local function arc(cx,cy,r,a,b,n)
        for i=0,n-1 do
            local t1=a+(b-a)*i/n; local t2=a+(b-a)*(i+1)/n
            line(cx+r*math.cos(t1),cy+r*math.sin(t1),cx+r*math.cos(t2),cy+r*math.sin(t2))
        end
    end
    if kind=="mail" then
        line(-8,-5,8,-5); line(8,-5,8,5); line(8,5,-8,5); line(-8,5,-8,-5)
        line(-8,5,0,-1); line(0,-1,8,5)
        line(-8,-5,-3,-1); line(8,-5,3,-1)
    elseif kind=="settings" then
        arc(0,0,5.5,0,2*math.pi,28)
        arc(0,0,2,0,2*math.pi,16)
        for i=0,7 do
            local a=i*math.pi/4
            line(5*math.cos(a),5*math.sin(a),8*math.cos(a),8*math.sin(a))
        end
    elseif kind=="search" then
        -- Field glasses: twin lenses, bridge and tapered barrels.
        arc(-5,-3,3.6,0,2*math.pi,18); arc(5,-3,3.6,0,2*math.pi,18)
        line(-8,-1,-6,6); line(-6,6,-3,6); line(-3,6,-1,-1)
        line(1,-1,3,6); line(3,6,6,6); line(6,6,8,-1)
        line(-2,2,2,2)
    elseif kind=="head" then
        arc(0,4,3.5,0,2*math.pi,16)
        arc(0,-6,7,0,math.pi,16)
        line(-7,-6,7,-6)
    elseif kind=="sun" then
        arc(0,0,4,0,2*math.pi,24)
        for i=0,7 do local a=i*math.pi/4
            line(6*math.cos(a),6*math.sin(a),9*math.cos(a),9*math.sin(a))
        end
    else
        -- Crescent outline: outer arc and a smaller, offset inner arc.
        arc(0,0,8,math.pi/3,5*math.pi/3,32)
        arc(8,0,8,2*math.pi/3,4*math.pi/3,24)
    end
    function f:Tint(r,g,b)
        for _,l in ipairs(self.lines) do l:SetColorTexture(r,g,b,1) end
    end
    f:Tint(0.84,0.88,0.91)
    return f
end
local function Zoom(delta)
    Minimap:SetZoom(math.max(0,math.min(Minimap:GetZoomLevels()-1,Minimap:GetZoom()+delta)))
end
local Apply, OpenSettings, RefreshControls
local function requestApply()
    if combat() then pending=true; say("Changes queued until combat ends."); return end
    Apply()
end
local function SavePosition()
    root:StopMovingOrSizing()
    local p,_,rp,x,y=root:GetPoint(1)
    -- StartMoving produces a screen-relative anchor; use its point on UIParent.
    db.point=p; db.x=x; db.y=y
    if RefreshControls then RefreshControls() end
end
local function hideDecoration(f)
    if not f then return end
    f:Hide()
    if f.EnableMouse then f:EnableMouse(false) end
    if f.HookScript and not suppressed[f] then
        suppressed[f]=true
        f:HookScript("OnShow",function(self)
            if ready then
                if combat() then pending=true; return end
                self:Hide()
                if self.EnableMouse then self:EnableMouse(false) end
            end
        end)
    end
end
local function SuppressBlizzardMinimap()
    if combat() then pending=true; return end
    local cluster=MinimapCluster
    if cluster then
        -- Keep the registered system object intact for Blizzard layout code.
        -- Its hidden parent prevents Edit Mode from resurrecting its visuals.
        cluster:SetParent(hiddenHost)
        hideDecoration(cluster)
        hideDecoration(cluster.Selection)
        hideDecoration(cluster.ZoneTextButton)
        hideDecoration(cluster.IndicatorFrame)
        hideDecoration(cluster.Clock)
        hideDecoration(cluster.MailFrame)
    end
    for _,name in ipairs({"GameTimeFrame","TimeManagerClockButton","MiniMapMailFrame",
        "MinimapZoneTextButton","MinimapClusterSelection"}) do
        hideDecoration(_G[name])
    end
    local manager=EditModeManagerFrame
    if manager and not editModeHooks[manager] then
        editModeHooks[manager]=true
        manager:HookScript("OnShow",function()
            if ready then requestApply() end
        end)
        manager:HookScript("OnHide",function()
            if ready then requestApply() end
        end)
    end
end
local function Skin()
    -- Keep the live Blizzard map, tracking and quest markers intact.
    Minimap:SetParent(root)
    Minimap:ClearAllPoints(); Minimap:SetPoint("TOPLEFT",root,"TOPLEFT",5,-mapTop)
    Minimap:SetSize(db.size,db.size)
    Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
    Minimap:SetFrameLevel(root:GetFrameLevel()+2)
    Minimap:Show()
    for _,name in ipairs({"MinimapBorder","MinimapBorderTop","MinimapBackdrop","MinimapZoneTextButton",
        "MinimapZoomIn","MinimapZoomOut","GameTimeFrame","TimeManagerClockButton","MiniMapMailFrame"}) do
        hideDecoration(_G[name])
    end
    -- Modern clients own these as fields; legacy globals alone miss hover zoom.
    for _,key in ipairs({"ZoomIn","ZoomOut"}) do
        local f=Minimap[key]
        if f then f:SetParent(hiddenHost); hideDecoration(f) end
    end
    if MinimapCluster then
        hideDecoration(MinimapCluster.ZoneTextButton)
    end
    -- Move known native controls as real controls, retaining their click handlers.
    hideDecoration(_G.MiniMapTracking)
    if MinimapCluster then hideDecoration(MinimapCluster.Tracking) end
    local native={_G.QueueStatusButton, _G.MiniMapWorldMapButton}
    local offset=0
    for i=1,2 do
        local f=native[i]
        if f then
            f:SetParent(root); f:ClearAllPoints()
            f:SetPoint("TOPLEFT",root,"TOPRIGHT",db.dock=="Right" and dock:IsShown() and 34 or 5,-mapTop-offset)
            offset=offset+34
        end
    end
    -- Hide the old owner only AFTER rescuing the live map and useful controls.
    SuppressBlizzardMinimap()
end
local function updateInfo()
    if not ready then return end
    zone:SetText((GetMinimapZoneText and GetMinimapZoneText()) or "Unknown zone")
    local h,m=GetGameTime()
    local vertical=db.dock=="Left" or db.dock=="Right"
    if db.localTime then
        slots.clock.text:SetText(date(vertical and "%H\n%M" or "%H:%M"))
    else slots.clock.text:SetFormattedText(vertical and "%02d\n%02d" or "%02d:%02d",h,m) end
    local has=HasNewMail and HasNewMail()
    slots.mail.text:SetText(has and "MAIL !" or "MAIL")
    slots.mail.text:SetTextColor(has and 1 or 0.48,has and 0.75 or 0.55,has and 0.36 or 0.60)
    slots.mail.text:SetShown(not db.mailIcon)
    slots.mail.icon:SetShown(db.mailIcon)
    slots.mail.icon:Tint(has and 1 or 0.48,has and 0.75 or 0.55,has and 0.36 or 0.60)
    local online
    if C_FriendList and C_FriendList.GetNumOnlineFriends then online=C_FriendList.GetNumOnlineFriends() end
    slots.friends.text:SetText(online and tostring(online) or "?")
    local c=colors[db.accent] or colors.Teal
    slots.friends.head:Tint(c[1],c[2],c[3])
    local day=h>=6 and h<18
    slots.daylight.text:SetText(day and "DAY" or "NIGHT")
    slots.daylight.text:SetShown(not db.daylightIcon)
    slots.daylight.sun:Tint(1,0.77,0.36)
    slots.daylight.moon:Tint(0.64,0.79,1)
    slots.daylight.sun:SetShown(db.daylightIcon and day)
    slots.daylight.moon:SetShown(db.daylightIcon and not day)
end
Apply=function()
    if not ready then return end
    local topZone=db.showZone and db.zonePosition=="Top"
    mapTop=topZone and 33 or 5
    root:SetSize(db.size+10,db.size+mapTop+5)
    root:SetScale(db.scale)
    root:ClearAllPoints()
    root:SetPoint(db.point,UIParent,db.point,db.x,db.y)
    root:Show()
    header:SetShown(topZone)
    accentLine:SetShown(topZone)
    gear:ClearAllPoints(); trackingButton:ClearAllPoints()
    trackingButton:SetPoint("BOTTOMLEFT",Minimap,"BOTTOMLEFT",3,3)
    gear:SetPoint("LEFT",trackingButton,"RIGHT",3,0)
    local alpha=db.hideBackground and 0 or db.opacity
    root:SetBackdropColor(0.035,0.043,0.055,alpha)
    dock:SetBackdropColor(0.035,0.043,0.055,alpha)
    root:SetBackdropBorderColor(0.14,0.17,0.20,alpha)
    dock:SetBackdropBorderColor(0.14,0.17,0.20,alpha)
    zoneShade:SetColorTexture(0.02,0.03,0.04,alpha*0.8)
    for _,b in ipairs(mapButtons) do
        b:SetBackdropColor(0.075,0.095,0.12,alpha)
        b:SetBackdropBorderColor(0.18,0.23,0.28,alpha)
    end
    zoomIn:SetShown(db.showZoom); zoomOut:SetShown(db.showZoom)
    gear:SetShown(db.showSettingsIcon)
    local c=colors[db.accent] or colors.Teal
    accentLine:SetColorTexture(c[1],c[2],c[3],alpha)
    zone:SetTextColor(c[1],c[2],c[3])
    zone:ClearAllPoints()
    local inside=db.zonePosition=="Inside bottom"
    zoneOverlay:SetShown(inside and db.showZone)
    zone:SetShown(db.showZone)
    -- Reserve equal space on both sides so the label stays truly centered.
    zoneOverlay:ClearAllPoints()
    local inset=53 -- Bottom-left controls always need clearance; keep zone centered.
    zoneOverlay:SetPoint("BOTTOMLEFT",Minimap,"BOTTOMLEFT",inset,0)
    zoneOverlay:SetPoint("BOTTOMRIGHT",Minimap,"BOTTOMRIGHT",-inset,0)
    zone:SetParent(inside and zoneOverlay or header)
    zone:SetPoint("LEFT",inside and 8 or 6,0)
    zone:SetPoint("RIGHT",inside and -8 or -3,0)
    zone:SetJustifyH(inside and "CENTER" or "LEFT")
    moveLabel:Hide()
    mover:SetShown(not db.locked and not combat())
    mover:SetBackdropColor(c[1],c[2],c[3],0.16)
    mover:SetBackdropBorderColor(c[1],c[2],c[3],0.9)
    trackingButton.symbol:Tint(c[1],c[2],c[3])
    dock:ClearAllPoints()
    local vertical=db.dock=="Left" or db.dock=="Right"
    if db.dock=="Top" then dock:SetPoint("BOTTOMLEFT",root,"TOPLEFT",0,0)
    elseif db.dock=="Left" then dock:SetPoint("TOPRIGHT",root,"TOPLEFT",0,0)
    elseif db.dock=="Right" then dock:SetPoint("TOPLEFT",root,"TOPRIGHT",0,0)
    else dock:SetPoint("TOPLEFT",root,"BOTTOMLEFT",0,0) end
    local n=0
    for _,key in ipairs({"clock","mail","friends","daylight"}) do if db[key] then n=n+1 end end
    dock:SetShown(n>0)
    dock:SetSize(vertical and 29 or db.size+10,vertical and (db.size+mapTop+5) or 29)
    local i=0
    for _,key in ipairs({"clock","mail","friends","daylight"}) do
        local b=slots[key]; b:SetShown(db[key]); b:ClearAllPoints()
        b.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",vertical and 8 or 10,"")
        if key=="clock" then
            b.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",vertical and 12 or 10,"")
            b.text:SetJustifyH("CENTER")
        elseif key=="friends" then
            b.head:SetScale(1)
            b.head:ClearAllPoints(); b.text:ClearAllPoints()
            b.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",vertical and 11 or 10,"")
            b.text:SetJustifyH("CENTER")
            if vertical then
                b.head:SetPoint("CENTER",b,"CENTER",0,7)
                b.text:SetPoint("TOP",b.head,"BOTTOM",0,-1)
            else
                b.head:SetPoint("RIGHT",b,"CENTER",-2,0)
                b.text:SetPoint("LEFT",b,"CENTER",1,0)
            end
        end
        if db[key] then
            if vertical then
                local rowHeight=(db.size+mapTop+3)/n
                b:SetSize(27,rowHeight); b:SetPoint("TOPLEFT",dock,"TOPLEFT",1,-1-i*rowHeight)
            else
                local w=(db.size+8)/n
                b:SetSize(w,27); b:SetPoint("TOPLEFT",dock,"TOPLEFT",1+i*w,-1)
            end
            i=i+1
        end
    end
    mover:ClearAllPoints()
    mover:SetPoint("TOPLEFT",root,"TOPLEFT",vertical and db.dock=="Left" and n>0 and -29 or 0,db.dock=="Top" and n>0 and 29 or 0)
    mover:SetPoint("BOTTOMRIGHT",root,"BOTTOMRIGHT",vertical and db.dock=="Right" and n>0 and 29 or 0,db.dock=="Bottom" and n>0 and -29 or 0)
    Skin(); updateInfo()
    if trackingMenu and trackingMenu:IsShown() then RefreshTracking() end
end
local function TrackingInfo(index)
    if not C_Minimap or not C_Minimap.GetTrackingInfo then return end
    local info,texture,active=C_Minimap.GetTrackingInfo(index)
    if type(info)=="table" then return info end
    if info then return {name=info,texture=texture,active=active} end
end
local function ChangeTracking(index,enabled)
    if combat() then say("Tracking changes are unavailable during combat."); return end
    if C_Minimap and C_Minimap.SetTracking then
        local ok,err=pcall(C_Minimap.SetTracking,index,enabled)
        if not ok then say("Could not change tracking: "..tostring(err)) end
    end
end
RefreshTracking=function()
    if not trackingMenu then return end
    local count=C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetNumTrackingTypes() or 0
    local c=colors[db.accent] or colors.Teal
    -- Borderless tracking popup; accent is used only for active checks.
    trackingMenu:ClearAllPoints()
    trackingMenu:SetPoint("TOPLEFT",root,"TOPRIGHT",db.dock=="Right" and dock:IsShown() and 34 or 5,-mapTop)
    trackingMenu.offset=math.max(0,math.min(trackingMenu.offset,math.max(0,count-12)))
    local visible=math.min(count,12)
    trackingMenu:SetHeight(36+visible*23+(count>12 and 18 or 0))
    trackingMenu.footer:SetText(count>12 and "Scroll for more" or "")
    for i,row in ipairs(trackingMenu.rows) do
        local index=i+trackingMenu.offset
        local info=index<=count and TrackingInfo(index)
        row:SetShown(info~=nil)
        if info then
            row.index=index
            row.text:SetText(info.name or "Tracking")
            row.itemIcon:SetTexture(info.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.check.mark:SetShown(info.active and true or false)
            row.check.mark:SetVertexColor(c[1],c[2],c[3],1)
        end
    end
end
ToggleTracking=function()
    if combat() then say("Open tracking outside combat."); return end
    if not C_Minimap or not C_Minimap.GetNumTrackingTypes or not C_Minimap.SetTracking then
        say("This client does not expose the tracking API."); return
    end
    if not trackingMenu then
        trackingMenu=box("SenMinimapTrackingMenu",UIParent)
        trackingMenu:SetFrameStrata("DIALOG"); trackingMenu:SetFrameLevel(60)
        trackingMenu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
        trackingMenu:SetBackdropColor(0.02,0.025,0.03,0.96)
        local function flat(b)
            b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
            b:SetBackdropColor(1,1,1,0)
            b:SetScript("OnEnter",function(self) self:SetBackdropColor(1,1,1,0.07) end)
            b:SetScript("OnLeave",function(self) self:SetBackdropColor(1,1,1,0); GameTooltip:Hide() end)
        end
        trackingMenu:SetWidth(250); trackingMenu:SetClampedToScreen(true); trackingMenu:EnableMouse(true)
        trackingMenu.offset=0; trackingMenu.rows={}
        local close=button(trackingMenu,"X",18,20,function() trackingMenu:Hide() end)
        close:SetPoint("TOPRIGHT",-6,-5); flat(close)
        local clear=button(trackingMenu,"Uncheck All",210,23,function()
            for i=1,C_Minimap.GetNumTrackingTypes() do ChangeTracking(i,false) end
            RefreshTracking()
        end); clear:SetPoint("TOPLEFT",8,-5); flat(clear)
        clear.text:ClearAllPoints(); clear.text:SetPoint("LEFT",3,0)
        for i=1,12 do
            local row=button(trackingMenu,"",234,23,function(self)
                local info=TrackingInfo(self.index)
                if info then ChangeTracking(self.index,not info.active); RefreshTracking() end
            end)
            row:SetPoint("TOPLEFT",8,-30-(i-1)*23); flat(row)
            row.text:ClearAllPoints(); row.text:SetPoint("LEFT",30,0); row.text:SetPoint("RIGHT",-31,0)
            row.text:SetJustifyH("LEFT"); row.text:SetWordWrap(false)
            row.itemIcon=row:CreateTexture(nil,"ARTWORK")
            row.itemIcon:SetSize(19,19); row.itemIcon:SetPoint("RIGHT",-5,0)
            row.check=box(nil,row)
            row.check:SetSize(13,13); row.check:SetPoint("LEFT",7,0)
            row.check:SetBackdropColor(0.02,0.025,0.03,1)
            row.check:SetBackdropBorderColor(0.35,0.40,0.44,0.85)
            row.check:EnableMouse(false)
            row.check.mark=row.check:CreateTexture(nil,"OVERLAY")
            row.check.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            row.check.mark:SetPoint("CENTER"); row.check.mark:SetSize(19,19)
            trackingMenu.rows[i]=row
        end
        trackingMenu.footer=label(trackingMenu,"",10); trackingMenu.footer:SetPoint("BOTTOM",0,6)
        trackingMenu:EnableMouseWheel(true)
        trackingMenu:SetScript("OnMouseWheel",function(self,delta) self.offset=self.offset-delta; RefreshTracking() end)
        table.insert(UISpecialFrames,"SenMinimapTrackingMenu")
        trackingMenu:Hide()
    end
    if trackingMenu:IsShown() then trackingMenu:Hide(); return end
    RefreshTracking(); trackingMenu:Show()
end
local function createMap()
    hiddenHost=CreateFrame("Frame",nil,UIParent)
    hiddenHost:Hide()
    root=box("SenMinimapFrame",UIParent); root:SetFrameStrata("LOW")
    root:SetMovable(true); root:SetClampedToScreen(true)
    header=CreateFrame("Button",nil,root); header:SetHeight(28)
    header:SetPoint("TOPLEFT",5,-3); header:SetPoint("TOPRIGHT",-60,-3)
    zoneOverlay=CreateFrame("Frame",nil,root)
    zoneOverlay:SetFrameLevel(root:GetFrameLevel()+5)
    zoneOverlay:SetPoint("BOTTOMLEFT",Minimap,"BOTTOMLEFT",0,0)
    zoneOverlay:SetPoint("BOTTOMRIGHT",Minimap,"BOTTOMRIGHT",0,0)
    zoneOverlay:SetHeight(25); zoneOverlay:EnableMouse(false)
    zoneShade=zoneOverlay:CreateTexture(nil,"BACKGROUND")
    zoneShade:SetAllPoints()
    zone=label(header,"SenMinimap",11); zone:SetPoint("LEFT",6,0); zone:SetPoint("RIGHT",-3,0)
    zone:SetJustifyH("LEFT"); zone:SetWordWrap(false)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function() if not db.locked and not combat() then root:StartMoving() end end)
    header:SetScript("OnDragStop",SavePosition)
    header:SetScript("OnEnter",function(self) tooltip(self,"SenMinimap",db.locked and "Position locked. Open settings to unlock." or "Drag this header to move the minimap.") end)
    header:SetScript("OnLeave",function() GameTooltip:Hide() end)
    gear=button(root,"",23,23,function() OpenSettings() end)
    gear.settingsIcon=icon(gear,"settings")
    gear.settingsIcon:Tint(0.92,0.73,0.32)
    gear:SetPoint("TOPRIGHT",-5,-5)
    zoomIn=button(root,"+",22,22,function() Zoom(1) end)
    zoomOut=button(root,"-",22,22,function() Zoom(-1) end)
    zoomIn:SetPoint("BOTTOMRIGHT",Minimap,"BOTTOMRIGHT",-3,3)
    zoomOut:SetPoint("RIGHT",zoomIn,"LEFT",-3,0)
    zoomIn:SetFrameLevel(root:GetFrameLevel()+8)
    zoomOut:SetFrameLevel(root:GetFrameLevel()+8)
    trackingButton=button(root,"",23,23,function() ToggleTracking() end)
    trackingButton.symbol=icon(trackingButton,"search")
    gear:SetFrameLevel(root:GetFrameLevel()+9)
    trackingButton:SetFrameLevel(root:GetFrameLevel()+9)
    mapButtons={gear,zoomIn,zoomOut,trackingButton}
    for _,b in ipairs(mapButtons) do
        b:SetScript("OnEnter",function(self) self.text:SetTextColor(0.56,0.90,0.87) end)
        b:SetScript("OnLeave",function(self) self.text:SetTextColor(0.84,0.88,0.91); GameTooltip:Hide() end)
    end
    gear:SetScript("OnEnter",function(self)
        self.settingsIcon:Tint(1,0.88,0.52)
        tooltip(self,"SenMinimap","Click to toggle settings. You can also use /senminimap.")
    end)
    gear:SetScript("OnLeave",function(self)
        self.settingsIcon:Tint(0.92,0.73,0.32); GameTooltip:Hide()
    end)
    accentLine=root:CreateTexture(nil,"OVERLAY"); accentLine:SetHeight(1)
    accentLine:SetPoint("TOPLEFT",5,-30); accentLine:SetPoint("TOPRIGHT",-5,-30)
    moveLabel=label(root,"UNLOCKED - drag zone header",10); moveLabel:SetPoint("BOTTOM",root,"TOP",0,39)
    dock=box(nil,root)
    local tips={clock={"Clock","Server time by default. Local time can be selected in settings."},
        mail={"Mail","Highlights when the game reports new mail. Visit a mailbox to read it."},
        friends={"Friends","Click to open your friends list. The number counts in-game friends online, excluding Battle.net friends."},
        daylight={"Day / night","A server-clock indicator: day 06:00-17:59, night 18:00-05:59. Not a moon-phase or lighting measurement."}}
    for _,key in ipairs({"clock","mail","friends","daylight"}) do
        local k=key
        local b=CreateFrame("Button",nil,dock); b.text=label(b,"",10); b.text:SetPoint("CENTER")
        b:SetScript("OnEnter",function(self) tooltip(self,tips[k][1],tips[k][2]) end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        if k=="friends" then
            b.head=icon(b,"head")
            b.head:ClearAllPoints(); b.head:SetPoint("RIGHT",b,"CENTER",-2,0)
            b.text:ClearAllPoints(); b.text:SetPoint("LEFT",b,"CENTER",1,0)
            b:SetScript("OnClick",function() if ToggleFriendsFrame then ToggleFriendsFrame() end end)
        end
        if k=="mail" then b.icon=icon(b,"mail") end
        if k=="daylight" then
            b.sun=icon(b,"sun"); b.sun:Tint(1,0.77,0.36)
            b.moon=icon(b,"moon"); b.moon:Tint(0.64,0.79,1)
        end
        slots[k]=b
    end
    mover=box("SenMinimapMover",root)
    mover:SetFrameStrata("DIALOG"); mover:SetFrameLevel(50)
    mover:EnableMouse(true); mover:RegisterForDrag("LeftButton")
    local dragText=label(mover,"SENMINIMAP\nDrag anywhere to move\nRight-click to lock",12)
    dragText:SetPoint("CENTER"); dragText:SetJustifyH("CENTER")
    mover:SetScript("OnDragStart",function() if not db.locked and not combat() then root:StartMoving() end end)
    mover:SetScript("OnDragStop",SavePosition)
    mover:SetScript("OnMouseUp",function(_,mouse)
        if mouse=="RightButton" then SavePosition(); db.locked=true; requestApply(); if settings then RefreshControls() end end
    end)
    mover:Hide()
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel",function(self,delta)
        Zoom(delta>0 and 1 or -1)
    end)
    -- Widely used contract for square-aware minimap button libraries.
    _G.GetMinimapShape=function() return "SQUARE" end
end
local function createSettings()
    settings=box("SenMinimapSettings",UIParent); settings:SetSize(430,700)
    settings:SetPoint("CENTER"); settings:SetFrameStrata("DIALOG")
    settings:SetMovable(true); settings:SetClampedToScreen(true); settings:EnableMouse(true)
    settings:RegisterForDrag("LeftButton")
    settings:SetScript("OnDragStart",function(self) self:StartMoving() end)
    settings:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    local title=label(settings,"SENMINIMAP  /  APPEARANCE",15); title:SetPoint("TOPLEFT",22,-22)
    local subtitle=label(settings,"0.1.0  |  Yurri Gaming",10); subtitle:SetPoint("TOPLEFT",22,-45)
    local close=button(settings,"X",25,25,function() settings:Hide() end); close:SetPoint("TOPRIGHT",-12,-12)
    table.insert(UISpecialFrames,"SenMinimapSettings")
    local function check(key,text,x,y)
        local c=CreateFrame("CheckButton",nil,settings,"UICheckButtonTemplate")
        c:SetSize(24,24); c:SetPoint("TOPLEFT",x,y)
        local t=label(c,text,11); t:SetPoint("LEFT",c,"RIGHT",4,0)
        c:SetScript("OnClick",function(self) db[key]=self:GetChecked() and true or false; requestApply() end)
        controls[key]=function() c:SetChecked(db[key]) end
    end
    check("locked","Lock position",20,-73)
    check("localTime","Use local clock",220,-73)
    local function slider(key,text,lo,hi,step,y)
        local t=label(settings,text,11); t:SetPoint("TOPLEFT",23,y)
        local s=CreateFrame("Slider",nil,settings,"OptionsSliderTemplate")
        s:SetPoint("TOPLEFT",155,y-2); s:SetSize(205,16)
        s:SetMinMaxValues(lo,hi); s:SetValueStep(step); s:SetObeyStepOnDrag(true)
        if s.Low then s.Low:SetText("") end; if s.High then s.High:SetText("") end
        local value=label(settings,"",11); value:SetPoint("TOPLEFT",370,y)
        local syncing=false
        local function display(v) value:SetText(step<1 and string.format("%.2f",v) or tostring(math.floor(v+0.5))) end
        s:SetScript("OnValueChanged",function(_,v)
            display(v); if syncing then return end
            db[key]=math.floor(v/step+0.5)*step
            if combat() then pending=true else Apply() end
        end)
        controls[key]=function() syncing=true; s:SetValue(db[key]); display(db[key]); syncing=false end
    end
    slider("size","Map size",160,360,2,-118)
    slider("scale","Overall scale",0.65,1.5,0.05,-161)
    slider("opacity","Background opacity",0,1,0.05,-204)
    local function coordinate(key,text,x)
        local t=label(settings,text,11); t:SetPoint("TOPLEFT",x,-249)
        local e=CreateFrame("EditBox",nil,settings,"InputBoxTemplate"); e:SetSize(74,24)
        e:SetPoint("TOPLEFT",x+21,-242); e:SetAutoFocus(false); e:SetMaxLetters(7)
        e:SetScript("OnEnterPressed",function(self)
            local v=tonumber(self:GetText())
            if v then db[key]=math.max(-10000,math.min(10000,v)); requestApply() end
            self:ClearFocus(); RefreshControls()
        end)
        e:SetScript("OnEscapePressed",function(self) self:ClearFocus(); RefreshControls() end)
        controls[key]=function() e:SetText(tostring(math.floor(db[key]+0.5))) end
    end
    coordinate("x","X",23); coordinate("y","Y",175)
    local hint=label(settings,"Offsets use the saved anchor. Press Enter to apply.",10); hint:SetPoint("TOPLEFT",23,-277)
    local accent=button(settings,"",180,28,function()
        local nextColor={Teal="Ice",Ice="Amber",Amber="Teal"}; db.accent=nextColor[db.accent] or "Teal"; requestApply(); RefreshControls()
    end); accent:SetPoint("TOPLEFT",23,-306)
    controls.accent=function() accent.text:SetText("Accent: "..db.accent) end
    local pos=button(settings,"",180,28,function() local nextDock={Bottom="Top",Top="Left",Left="Right",Right="Bottom"}; db.dock=nextDock[db.dock] or "Bottom"; requestApply(); RefreshControls() end)
    pos:SetPoint("TOPLEFT",222,-306); controls.dock=function() pos.text:SetText("Dock: "..db.dock) end
    local zonePos=button(settings,"",379,28,function()
        db.zonePosition=db.zonePosition=="Top" and "Inside bottom" or "Top"
        requestApply(); RefreshControls()
    end)
    zonePos:SetPoint("TOPLEFT",23,-348)
    controls.zonePosition=function() zonePos.text:SetText("Zone name: "..db.zonePosition.."  (click to change)") end
    check("showZone","Show zone name",20,-388)
    check("showZoom","Show + / - zoom",220,-388)
    check("clock","Clock",20,-422); check("friends","Friends",220,-422)
    check("mail","Show mail",20,-456); check("mailIcon","Mail: icon (off = text)",220,-456)
    check("daylight","Show day / night",20,-490)
    check("daylightIcon","Day/night: icon (off = text)",220,-490)
    check("hideBackground","Hide all backgrounds",20,-532)
    check("showSettingsIcon","Show settings icon",220,-532)
    local bgHint=label(settings,"Includes borders, zone strip and button backgrounds.\nMap, labels and icons remain visible.",10)
    bgHint:SetPoint("TOPLEFT",25,-562)
    local reset=button(settings,"Reset position",180,28,function()
        db.point=defaults.point; db.x=defaults.x; db.y=defaults.y; requestApply(); RefreshControls()
    end); reset:SetPoint("BOTTOMLEFT",23,60)
    local lock=button(settings,"Lock and close",180,28,function() db.locked=true; requestApply(); RefreshControls(); settings:Hide() end)
    lock:SetPoint("BOTTOMRIGHT",-28,60)
    local note=label(settings,"/senminimap  |  Changes save automatically on logout.\nLayout changes during combat apply after combat ends.",10)
    note:SetPoint("BOTTOMLEFT",23,20)
    settings:Hide()
end
RefreshControls=function() for _,fn in pairs(controls) do fn() end end
OpenSettings=function()
    if not ready then return end
    if not settings then createSettings() end
    RefreshControls(); settings:SetShown(not settings:IsShown())
end
-- Entry in the game's Options > AddOns list.
local optionsPanel, optionsRegistered
local function RegisterAddonOptions()
    if optionsRegistered then return end
    local modern=Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory
    if not modern and not InterfaceOptions_AddCategory then return end
    if not optionsPanel then
        optionsPanel=CreateFrame("Frame","SenMinimapAddonOptions",UIParent)
        optionsPanel.name="SenMinimap"
        local title=label(optionsPanel,"SenMinimap",22)
        title:SetPoint("TOPLEFT",20,-20); title:SetTextColor(0.56,0.90,0.87)
        local version=label(optionsPanel,"Version 0.1.0  |  Yurri Gaming",12)
        version:SetPoint("TOPLEFT",20,-52)
        local description=label(optionsPanel,"Customize your minimap, dock, tracking and appearance.",13)
        description:SetPoint("TOPLEFT",20,-88)
        description:SetPoint("TOPRIGHT",-20,-88); description:SetJustifyH("LEFT")
        local open=button(optionsPanel,"Open Settings",160,32,function()
            -- Always open, even if the standalone window is already visible.
            if not ready then return end
            for _,frame in ipairs({SettingsPanel or false,InterfaceOptionsFrame or false}) do
                if frame and frame:IsShown() then
                    if HideUIPanel then HideUIPanel(frame) else frame:Hide() end
                end
            end
            if not settings then createSettings() end
            RefreshControls(); settings:Show(); settings:Raise()
        end)
        open:SetPoint("TOPLEFT",20,-130)
        local hint=label(optionsPanel,"You can also type /senminimap or click the minimap settings icon.",11)
        hint:SetPoint("TOPLEFT",20,-181)
        hint:SetPoint("TOPRIGHT",-20,-181); hint:SetJustifyH("LEFT")
        optionsPanel:Hide()
    end
    if modern then
        local category=Settings.RegisterCanvasLayoutCategory(optionsPanel,"SenMinimap")
        Settings.RegisterAddOnCategory(category)
    else
        InterfaceOptions_AddCategory(optionsPanel)
    end
    optionsRegistered=true
end
local events=CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED"); events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED"); events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("MINIMAP_UPDATE_TRACKING")
events:RegisterEvent("GLOBAL_MOUSE_DOWN")
events:SetScript("OnEvent",function(_,event,name)
    if ready and event=="ADDON_LOADED" then RegisterAddonOptions() end
    if event=="GLOBAL_MOUSE_DOWN" then
        if trackingMenu and trackingMenu:IsShown() and not MouseIsOver(trackingMenu) and not MouseIsOver(trackingButton) then
            trackingMenu:Hide()
        end
    elseif event=="ADDON_LOADED" and name==ADDON then
        if type(SenMapDB)~="table" then SenMapDB={} end
        db=SenMapDB
        for k,v in pairs(defaults) do if type(db[k])~=type(v) then db[k]=v end end
        db.size=math.max(160,math.min(360,db.size)); db.scale=math.max(0.65,math.min(1.5,db.scale))
        db.opacity=math.max(0,math.min(1,db.opacity))
        if not colors[db.accent] then db.accent="Teal" end
        local anchors={TOP=true,TOPLEFT=true,TOPRIGHT=true,LEFT=true,CENTER=true,RIGHT=true,BOTTOM=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
        if not anchors[db.point] then db.point=defaults.point end
        if db.dock~="Top" and db.dock~="Left" and db.dock~="Right" then db.dock="Bottom" end
        if db.zonePosition~="Inside bottom" then db.zonePosition="Top" end
    elseif event=="MINIMAP_UPDATE_TRACKING" and trackingMenu and trackingMenu:IsShown() then
        RefreshTracking()
    elseif event=="PLAYER_LOGIN" and db and Minimap then
        createMap(); ready=true; requestApply(); RegisterAddonOptions()
        say("Loaded 0.1.0. /senminimap for settings.")
    elseif event=="PLAYER_REGEN_DISABLED" and root then
        SavePosition(); mover:Hide(); pending=true
        if trackingMenu then trackingMenu:Hide() end
    elseif event=="PLAYER_REGEN_ENABLED" and ready then
        if pending then pending=false; Apply() end
    elseif ready and (event=="PLAYER_ENTERING_WORLD" or
        (event=="ADDON_LOADED" and (name=="Blizzard_EditMode" or name=="Blizzard_TimeManager" or name=="Blizzard_Minimap"))) then
        requestApply()
    end
end)
events:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed>=1 then elapsed=0; updateInfo() end
end)
SLASH_SENMINIMAP1="/senminimap"
SLASH_SENMINIMAP2="/senmap"
SlashCmdList.SENMINIMAP=function(msg)
    if not ready then return end
    msg=(msg or ""):lower():match("^%s*(.-)%s*$")
    if msg=="unlock" or msg=="lock" then db.locked=msg=="lock"; requestApply(); if settings then RefreshControls() end
    elseif msg=="reset" then db.point=defaults.point; db.x=defaults.x; db.y=defaults.y; requestApply(); if settings then RefreshControls() end
    else OpenSettings() end
end
