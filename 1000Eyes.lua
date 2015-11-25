local Addon = CreateFrame("FRAME", "1000Eyes", UIParent);

Addon.PERFORMANCE_FACTOR = 0.01;	-- smooth and efficient!
Addon.VANISH_TIMER = 5;		-- make it fit in with the cooldown feel

Addon.DualWield = nil;


-------------------------------------
-- Sets the initial swing bar width
-- @param element
-- @param time
-- @param speed
-- @param maxwidth
--
-------------------------------------
local function SetSwingBarWidth(element, time, speed, maxwidth)
  local width = ( time / speed * maxwidth );
  if ( width < 1 ) then
    width = 1;
  elseif ( width > maxwidth ) then
    width = maxwidth;
  end
  element:SetWidth(width);
end

-------------------------------------
-- Gets attack speed from target
-- @param self
--
-------------------------------------
local function GetSwingSpeed(self)
  local mHand, oHand = UnitAttackSpeed("target");
  if(( Addon.DualWield ) and (self.SPEED == oHand)) then
    return(oHand);
  else
    return(mHand);
  end
end

-------------------------------------
-- Sets attack speed in the swing bars
-- @param self
-- @param speed
--
-------------------------------------
local function SetSwingSpeed(self, speed)
  if (speed == nil) then
    self.speed = GetSwingSpeed(self);
    if (self.speed == nil) then
      Addon.Disable(self);
      return(nil);
    end
  else
    self.speed = speed;
  end

  self.textSpeed:SetText(string.format("%.2f", math.floor(self.speed * 100 + 0.5) / 100));

  _,_,self.latency = GetNetStats();
  self.latency = self.latency / 1000;
  SetSwingBarWidth(self.lagbar, self.latency, self.speed, EyesSettingsSV[UnitName("Player")].width);
end

-------------------------------------
-- Resets swing bar frame.
-- Used after the target strikes
-- @param self
--
-------------------------------------
local function SwingFrameReset(self)
  self:SetScript("OnUpdate", nil);
  SetSwingSpeed(self);
  self.lastupdate = 0;
  self.elapsed = 0;
  self.bar:SetWidth(1);
  self.active = nil;
  self:Show();
  self.vanish = 0;
end

-------------------------------------
-- Hide swing bar frame if elapsed time bigger than Addon.VANISH_TIMER
-- @param self
-- @param elapsed
--
-------------------------------------
local function SwingFrameVanish(self, elapsed)
  if ( self.vanish > 0 ) then
    self.vanish = self.vanish - elapsed;
    if ( self.vanish <= 0 ) then
      self:SetScript("OnUpdate", nil);
      self:Hide();
    end
  end
end

-------------------------------------
-- Updates SwingBar frame with the new numbers
-- @param self
-- @param elapsed
--
-------------------------------------
local function SwingFrameTimer(self, elapsed)
  -- performance throttle
  --
  self.lastupdate = self.lastupdate + elapsed;

  if ( self.lastupdate < Addon.PERFORMANCE_FACTOR ) then
    return(nil);
  end
  self.textTime:SetText(((("%%.%df"):format(2)):format(self.elapsed)));
  self.elapsed = self.elapsed + self.lastupdate;
  self.lastupdate = 0;

  -- flag the swing timer as inactive early to help account for lag
  --
  if ( self.elapsed > (self.speed - self.latency) ) then
    self.active = nil;
  end

  if ( self.elapsed > self.speed ) then
    self.vanish = Addon.VANISH_TIMER;
    self:SetScript("OnUpdate", SwingFrameVanish);
  end

  SetSwingBarWidth(self.bar, self.elapsed, self.speed, EyesSettingsSV[UnitName("Player")].width);
end

-------------------------------------
-- Creates a swing bar frame
-- @param id 
-- @return frame
--
-------------------------------------
local function CreateSwingFrame(id)
  local frame = CreateFrame("FRAME", nil, nil);

  frame:Hide();
  frame.maxwidth = 200;
  frame.id = id;

  frame:SetWidth(frame.maxwidth);
  frame:SetHeight(5);

  frame.backdrop = frame:CreateTexture(nil, "ARTWORK");
  frame.backdrop:SetAllPoints();
  frame.backdrop:SetTexture(0,0,0,0.1);
  frame.backdrop:SetTexture("Interface\\AddOns\\1000Eyes\\Textures\\Frost.tga", false);
  frame.backdrop:SetBlendMode("MOD");

  frame.bar = frame:CreateTexture(nil, "BACKGROUND");
  frame.bar:SetPoint("LEFT", frame.backdrop);
  frame.bar:SetWidth(1);
  frame.bar:SetHeight(10);
  frame.bar:SetTexture(1,0,0,1);

  frame.lagbar = frame:CreateTexture(nil, "OVERLAY");
  frame.lagbar:SetPoint("RIGHT", frame.backdrop);
  frame.lagbar:SetWidth(1);
  frame.lagbar:SetHeight(10);
  frame.lagbar:SetTexture(0.7,0,0,0.4);

  frame.left = frame:CreateTexture(nil, "OVERLAY");
  frame.left:SetPoint("LEFT", frame.backdrop, -1);
  frame.left:SetWidth(2);
  frame.left:SetHeight(5);
  frame.left:SetTexture(0.2,0.2,0.2,1);

  frame.right = frame:CreateTexture(nil, "OVERLAY");
  frame.right:SetPoint("RIGHT", frame.backdrop, 1);
  frame.right:SetWidth(2);
  frame.right:SetHeight(5);
  frame.right:SetTexture(0.2,0.2,0.2,1);

  frame.textTime = frame:CreateFontString(nil, "ARTWORK");
  frame.textTime:SetPoint("RIGHT", frame.left, "LEFT", positionX, positionY);
  frame.textTime:SetFont("Fonts\\FRIZQT__.TTF", 12);
  frame.textTime:SetTextColor(1,1,1,1);

  frame.textSpeed = frame:CreateFontString(nil, "ARTWORK");
  frame.textSpeed:SetPoint("LEFT", frame.right, "RIGHT", positionX, positionY);
  frame.textSpeed:SetFont("Fonts\\FRIZQT__.TTF", 12);
  frame.textSpeed:SetTextColor(1,1,1,1);

  return(frame);
end

-------------------------------------
-- Checks if the target is dualwielding
-- @return 1 if true
-- @return nil if false
--
-------------------------------------
function IsTargetDualWielding()

  local MainHand, OffHand = UnitAttackSpeed("target");
  if(OffHand ~= nil) then
    return(1);
  else
    return(nil);
  end

end

-------------------------------------
-- Swing Bars Frames
--
-------------------------------------
SwingFrame = {};
SwingFrame[1] = CreateSwingFrame(1);
SwingFrame[2] = CreateSwingFrame(2);
SwingFrame[3] = CreateSwingFrame(3);


-- swing event handlers --
-- -------------------- --

local function SwingFrameMainHandEvent(self,_,_,event,_,src_guid)
  if ( string.sub(event,1,5) == "SWING" ) and ( src_guid == UnitGUID("target") ) then
    SwingFrameReset(self);
    self:SetScript("OnUpdate", SwingFrameTimer);
  end
end

-- Single event handler for DualWield (two SwingFrames).
--
-- We need to predict which one is happening as the combat log does not
-- differentiate between mainhand and offhand swing events.
--
-- Which is most unfortunate, it seems really easy to implement on Blizzard's end.
--
local function SwingFrameDualWieldEvent(self,_,_,event,_,src_guid)
  if ( string.sub(event,1,5) == "SWING" ) and ( src_guid == UnitGUID("target") ) then

    -- this happens when lag throws us out of sync.
    -- there's no easy way to figure out wtf is going on, so just
    -- reset and hope we fall back in sync.
    --
    if ( SwingFrame[self.id].active ) and ( SwingFrame[self.id+1].active ) then
      SwingFrame[self.id].active = nil;
      SwingFrame[self.id+1].active = nil;
    end

    if ( SwingFrame[self.id].active ) then
      SwingFrameReset(SwingFrame[self.id+1]);
      SwingFrame[self.id+1].active = true;
      SwingFrame[self.id+1]:SetScript("OnUpdate", SwingFrameTimer);

    else
      SwingFrameReset(SwingFrame[self.id]);
      SwingFrame[self.id].active = true;
      SwingFrame[self.id]:SetScript("OnUpdate", SwingFrameTimer);
    end
  end
end


-------------------------------------
-- Enables swing bars frames
--
-------------------------------------
function Addon.Enable(frame, func)
  SwingFrameReset(frame);
  frame:SetScript("OnEvent", func);
  frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
  frame:Hide();
end


-------------------------------------
-- Disables swing bars frames
--
-------------------------------------
function Addon.Disable(frame)
  frame:UnregisterAllEvents();
  frame:Hide();
end

-------------------------------------
-- Checks the target's attack speed
--
-------------------------------------
function Addon.InspectTarget()
  local i = 1;

  Addon.DualWield = IsTargetDualWielding();

  if ( Addon.DualWield) then
    SwingFrame[i].SPEED, SwingFrame[i+1].SPEED = UnitAttackSpeed("target");
    Addon.Enable(SwingFrame[i], SwingFrameDualWieldEvent);
    Addon.Enable(SwingFrame[i+1], nil);
    i = i + 2;

  -- main hand only
  else
    SwingFrame[i].SPEED = UnitAttackSpeed("target");
    Addon.Enable(SwingFrame[i], SwingFrameMainHandEvent);
    i = i + 1;
  end

  while ( SwingFrame[i] ) do
    Addon.Disable(SwingFrame[i]);
    i = i + 1;
  end
end


-------------------------------------
-- Saves Position into SavedVariables
--
-------------------------------------
function savePosition()

  point,_,relativePoint,x,y = SwingFrame[1]:GetPoint();
  EyesSettingsSV[UnitName("Player")].bar1.point = point;
  EyesSettingsSV[UnitName("Player")].bar1.relativePoint = relativePoint;
  EyesSettingsSV[UnitName("Player")].bar1.x = x;
  EyesSettingsSV[UnitName("Player")].bar1.y = y;

  point,_,relativePoint,x,y = SwingFrame[2]:GetPoint();
  EyesSettingsSV[UnitName("Player")].bar2.point = point;
  EyesSettingsSV[UnitName("Player")].bar2.relativePoint = relativePoint;
  EyesSettingsSV[UnitName("Player")].bar2.x = x;
  EyesSettingsSV[UnitName("Player")].bar2.y = y;

end

-------------------------------------
-- Changes Swing Bar's width and height.
-- Used when the addon loads to restore the values from SavedVariables
--
-------------------------------------
local function ChangeSwingBarSize(newWidth, newHeight)
  for i=1,2 do
    SwingFrame[i]:SetWidth(newWidth);

    SwingFrame[i]:SetHeight(newHeight);
    SwingFrame[i].bar:SetHeight(newHeight);
    SwingFrame[i].lagbar:SetHeight(newHeight);
    SwingFrame[i].left:SetHeight(newHeight);
    SwingFrame[i].right:SetHeight(newHeight);

  end
end

-------------------------------------
-- Changes Swing Bar's width.
-- Used for XML slider bar
--
-------------------------------------
function ChangeSwingBarWidth()
  if(EyesSettingsSV) then
    local newWidth = _G["eyesConfig".."Slider1"]:GetValue();
    for i=1,2 do
      SwingFrame[i]:SetWidth(newWidth);
    end

    EyesSettingsSV[UnitName("Player")].width = newWidth;
  end
end

-------------------------------------
-- Changes Swing Bar's height.
-- Used for XML slider bar
--
-------------------------------------
function ChangeSwingBarHeight()
  if(EyesSettingsSV) then
    local newHeight = _G["eyesConfig".."Slider2"]:GetValue();
    for i=1,2 do
      SwingFrame[i]:SetHeight(newHeight);
      SwingFrame[i].bar:SetHeight(newHeight);
      SwingFrame[i].lagbar:SetHeight(newHeight);
      SwingFrame[i].left:SetHeight(newHeight);
      SwingFrame[i].right:SetHeight(newHeight);

    end

    EyesSettingsSV[UnitName("Player")].height = newHeight;
  end
end

-------------------------------------
-- Changes Swing Bar's color
-- @param r red
-- @param g green
-- @param b blue
-- @param a alpha
--
-------------------------------------
local function ChangeSwingBarColor(r, g, b, a)
  SwingFrame[1].bar:SetTexture(r, g, b, a);
  SwingFrame[2].bar:SetTexture(r, g, b, a);
end

-------------------------------------
-- Textures and Fonts tables
--
-------------------------------------
Textures = {};
Textures[1] = { text  = "Frost", texture = "Interface\\AddOns\\1000Eyes\\Textures\\Frost.tga" };
Textures[2] = { text  = "Xeon", texture = "Interface\\AddOns\\1000Eyes\\Textures\\Xeon.tga" };
Textures[3] = { text  = "Runes", texture = "Interface\\AddOns\\1000Eyes\\Textures\\Runes.tga" };
Textures[4] = { text  = "Custom", texture = "Interface\\AddOns\\1000Eyes\\Textures\\Custom.tga" };

Fonts = {};
Fonts[1] = { text  = "Cooline", font = "Interface\\AddOns\\1000Eyes\\Fonts\\Cooline.ttf" };
Fonts[2] = { text  = "Digital", font = "Interface\\AddOns\\1000Eyes\\Fonts\\Digital.ttf" };
Fonts[3] = { text  = "Talisman", font = "Interface\\AddOns\\1000Eyes\\Fonts\\Talisman.ttf" };
Fonts[4] = { text  = "Custom", font = "Interface\\AddOns\\1000Eyes\\Fonts\\Custom.ttf" };


-------------------------------------
-- Changes Swing Bar's texture
-- @param newText the directory of the new texture
--
-------------------------------------
function ChangeSwingBarTexture(newText)
  label = _G["eyesConfig".."TextureName".."Label"];
  if(newText == nil and EyesSettingsSV) then
    local newTexture = _G["eyesConfig".."Slider3"]:GetValue();

    newTexture = Textures[newTexture];
    for i=1,2 do
      SwingFrame[i].backdrop:SetTexture(newTexture.texture, false);
    end

    EyesSettingsSV[UnitName("Player")].texture = newTexture.texture;

    label:SetText(newTexture.text);

  else
    for i=1,2 do
      SwingFrame[i].backdrop:SetTexture(newText, false);
    end
    for x,v in ipairs(Textures) do
      if(newText and string.match(newText, v.text)) then
        label:SetText(v.text);
        break
      end
    end
  end
end


-------------------------------------
-- Changes Swing Bar's font
-- @param newFont the directory of the new font
--
-------------------------------------
function ChangeSwingBarFont(newFont)

  label = _G["eyesConfig".."FontName".."Label"];
  if(newFont == nil and EyesSettingsSV) then
    local newFontValue = _G["eyesConfig".."Slider4"]:GetValue();

    newFontValue = Fonts[newFontValue];
    for i=1,2 do
      SwingFrame[i].textTime:SetFont(newFontValue.font, 12);
      SwingFrame[i].textSpeed:SetFont(newFontValue.font , 12);
    end

    EyesSettingsSV[UnitName("Player")].font = newFontValue.font;

    label:SetText(newFontValue.text);


  else
    if(newFont) then
      for i=1,2 do
        SwingFrame[i].textTime:SetFont(newFont, 12);
        SwingFrame[i].textSpeed:SetFont(newFont, 12);
      end
      for x,v in ipairs(Fonts) do
        if(newFont and string.match(newFont, v.text)) then
          label:SetText(v.text);
          break
        end
      end
    end
  end

end

-------------------------------------
-- Gets the values for the Slider Bars used on XML file (GUI)
-- Doesn't return anything, simply modifies right away
--
-------------------------------------
function GetSavedVariable()
  widthValue = EyesSettingsSV[UnitName("Player")].width;
  heightValue = EyesSettingsSV[UnitName("Player")].height;
  textureValue = EyesSettingsSV[UnitName("Player")].texture;
  fontValue = EyesSettingsSV[UnitName("Player")].font;

  for x,v in ipairs(Textures) do
    if(string.match(textureValue, v.text)) then
      textureValue = x;
      break
    end
  end

  for x,v in ipairs(Fonts) do
    if(string.match(fontValue, v.text)) then
      fontValue = x;
      break
    end
  end

  _G["eyesConfig".."Slider1"]:SetValue(widthValue);
  _G["eyesConfig".."Slider2"]:SetValue(heightValue);
  _G["eyesConfig".."Slider3"]:SetValue(textureValue);
  _G["eyesConfig".."Slider4"]:SetValue(fontValue);

end

--Coordinates for Frames-- --
local point, relativePoint, positionX, positionY = 0;
-- -- -- -- -- -- -- -- -- --

-------------------------------------
-- Used when the addon detects a new Character or when the player uses the reset function
--
-------------------------------------
local function newVariables()

  EyesSettingsSV[UnitName("Player")] = {}
  EyesSettingsSV[UnitName("Player")].width = 200;
  EyesSettingsSV[UnitName("Player")].height = 15;
  EyesSettingsSV[UnitName("Player")].texture = "Interface\\AddOns\\1000Eyes\\Textures\\Frost.tga";
  EyesSettingsSV[UnitName("Player")].font = "Interface\\AddOns\\1000Eyes\\Fonts\\Cooline.ttf";
  EyesSettingsSV[UnitName("Player")].color = "1 1 1 1";
  EyesSettingsSV[UnitName("Player")].bar1 = {}
  EyesSettingsSV[UnitName("Player")].bar2 = {}
  EyesSettingsSV[UnitName("Player")].bar1.point = "CENTER";
  EyesSettingsSV[UnitName("Player")].bar1.relativePoint = "CENTER";
  EyesSettingsSV[UnitName("Player")].bar1.x = 0;
  EyesSettingsSV[UnitName("Player")].bar1.y = 0;
  EyesSettingsSV[UnitName("Player")].bar2.point = "CENTER";
  EyesSettingsSV[UnitName("Player")].bar2.relativePoint = "CENTER";
  EyesSettingsSV[UnitName("Player")].bar2.x = 0;
  EyesSettingsSV[UnitName("Player")].bar2.y = 0;

end


-------------------------------------
-- Gets the position from SavedVariable
-- @param bar which bar?
-- @return point
-- @return UIParent
-- @return relativePoint
-- @return positionX
-- @return positionY
--
-------------------------------------
local function getPosition(bar)

  if(bar == 1) then
    point = EyesSettingsSV[UnitName("Player")].bar1.point;
    relativePoint = EyesSettingsSV[UnitName("Player")].bar1.relativePoint;
    positionX = EyesSettingsSV[UnitName("Player")].bar1.x;
    positionY = EyesSettingsSV[UnitName("Player")].bar1.y;

    return point, UIParent, relativePoint, positionX, positionY;
  end
  if(bar == 2) then
    point = EyesSettingsSV[UnitName("Player")].bar2.point;
    relativePoint = EyesSettingsSV[UnitName("Player")].bar2.relativePoint;
    positionX = EyesSettingsSV[UnitName("Player")].bar2.x;
    positionY = EyesSettingsSV[UnitName("Player")].bar2.y;

    return point, UIParent, relativePoint, positionX, positionY;
  end

end

-------------------------------------
-- Gets the color from SavedVariable
-- @return r red
-- @return g green
-- @return b blue
-- @return a alpha
--
-------------------------------------

local function getColor()
  local r, g, b, a;
  local strColor = EyesSettingsSV[UnitName("Player")].color;

  r, g, b, a = strColor:match("([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+)")

  return r, g, b, a;
end



Addon:SetScript("OnEvent", function(_, event)
  if(event == "VARIABLES_LOADED") then
    if type(EyesSettingsSV) ~= "table" then
      EyesSettingsSV = {}
      newVariables();
    end
    local found = 0

    for name,number in pairs(EyesSettingsSV) do
      if UnitName("Player") == name then
        found = 1
        break
      end
    end
    if found == 0 then
      newVariables();
    end

    local width = EyesSettingsSV[UnitName("Player")].width
    local height = EyesSettingsSV[UnitName("Player")].height
    local texture = EyesSettingsSV[UnitName("Player")].texture
    local font = EyesSettingsSV[UnitName("Player")].font

    SwingFrame[1]:SetPoint(getPosition(1))
    SwingFrame[2]:SetPoint(getPosition(2))
    ChangeSwingBarSize(width, height)
    ChangeSwingBarColor(getColor())
    ChangeSwingBarTexture(texture)
    ChangeSwingBarFont(font)

    GetSavedVariable()
    --  SwingFrame[3]:SetPoint(point, UIParent, relativePoint, positionX, positionY)

  end

  if ( event == "PLAYER_TARGET_CHANGED" ) then
    Addon:SetScript("OnEvent",Addon.InspectTarget);
  end

  Addon.InspectTarget();

end);

-------------------------------------
-- Function that will be used for the 4th param of ShowColorPicker
-- @param restore
--
-------------------------------------
function myColorCallback(restore)
  local newR, newG, newB, newA;
  if restore then
    -- The user bailed, we extract the old color from the table created by ShowColorPicker.
    newR, newG, newB, newA = unpack(restore);
  else
    -- Something changed
    newA, newR, newG, newB = OpacitySliderFrame:GetValue(), ColorPickerFrame:GetColorRGB();
  end

  -- Update our internal storage.
  r, g, b, a = newR, newG, newB, newA;

  SwingFrame[1].bar:SetTexture(r, g, b, a);

  SwingFrame[2].bar:SetTexture(r, g, b, a);

  EyesSettingsSV[UnitName("Player")].color =r .. " " .. g .. " " .. b .. " " .. a;

end

-------------------------------------
-- Shows ColorPicker Frame which is implemented in WoW (http://www.wowwiki.com/Using_the_ColorPickerFrame)
-- @param r red (from 0 to 1)
-- @param g green (from 0 to 1)
-- @param b blue (from 0 to 1)
-- @param a alpha aka opacity (from 0 to 1)
-- @param changedCallback the function that will be called back
--
-------------------------------------
function ShowColorPicker(r, g, b, a, changedCallback)
  ColorPickerFrame:SetColorRGB(getColor());
  ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = (a ~= nil), a;
  ColorPickerFrame.previousValues = {r,g,b,a};
  ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc =
    changedCallback, changedCallback, changedCallback;
  ColorPickerFrame:Hide(); -- Need to run the OnShow handler.
  ColorPickerFrame:Show();
end


SLASH_1000Eyes1, SLASH_1000Eyes2 = "/1000eyes", "/eyes";


-------------------------------------
-- Slash commands function.
-- The commands are: unlock, lock, config and reset.
-- @param cmd command that will be checked
--
-------------------------------------
function SlashCmd(cmd)
  if (cmd:match"unlock") then
    for i=1,2 do
      SwingFrame[i]:SetMovable(true)
      SwingFrame[i]:EnableMouse(true)
      SwingFrame[i]:RegisterForDrag("LeftButton")
      SwingFrame[i]:SetScript("OnDragStart",  function(_,event)
        SwingFrame[i]:StartMoving();
      end);
      SwingFrame[i]:SetScript("OnDragStop", function(_,event)
        SwingFrame[i]:StopMovingOrSizing();
      end);
    end
  elseif (cmd:match"lock") then
    for i=1,2 do
      SwingFrame[i]:SetMovable(false)
      SwingFrame[i]:EnableMouse(false)
      savePosition();
    end

  elseif (cmd:match"config") then
    eyesConfig:Show();


  elseif (cmd:match"reset") then
    newVariables();
    print("Bars' position reseted --- Type \"/reload\"")
  elseif (cmd:match"help") then
    print("To use commands you need to type \"/eyes cmd\" here cmd is the command");
    print("1000Eyes commands:")
    print("/eyes unlock\" - Unlock the bars, allowing you to move them by dragging")
    print("/eyes lock\" - Lock the bars and save their positions on the database")
    print("/eyes reset\" - Reset bars' position. You need to /reload afterwards")
  else
    print("Command not valid. Type \"/eyes help\" for more information.")
  end
end

SlashCmdList["1000Eyes"] = SlashCmd;


--Addon:RegisterEvent("PLAYER_REGEN_DISABLED");
--Addon:RegisterEvent("PLAYER_REGEN_ENABLED");
Addon:RegisterEvent("PLAYER_TARGET_CHANGED");
--Addon:RegisterEvent("PLAYER_FOCUS_CHANGED");
Addon:RegisterEvent("PLAYER_ENTERING_WORLD");
--Addon:RegisterEvent("ADDON_LOADED");
Addon:RegisterEvent("VARIABLES_LOADED");
