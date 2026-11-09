--[[
  AD FINEM Stream Kit - toggles for Stream Deck (or any keyboard)
  Added to OBS by the kit's installer (Tools > Scripts). Each toggle is a normal
  OBS hotkey you can change in Settings > Hotkeys ("AD FINEM: ...").

  Default keys (Ctrl + Alt + Shift + ...), used by the AD FINEM Stream Deck page:
    F13-F16  scenes (set on the scenes themselves; F17 = Ending too, it plays the outro)
    F18 mic   F19 desktop audio   F20 webcam   F21 sponsors   F22 alerts
    F23 screenshot   F24 recording        Ctrl + Shift + F13  start/stop stream
]]
obs = obslua

local DESKTOP_CHANNEL, MIC_CHANNEL = 1, 3

local function each_scene(fn)
  local scenes = obs.obs_frontend_get_scenes()
  if scenes then
    for _, src in ipairs(scenes) do fn(obs.obs_scene_from_source(src), obs.obs_source_get_name(src)) end
    obs.source_list_release(scenes)
  end
end

local function toggle_mute(channel)
  local src = obs.obs_get_output_source(channel)
  if src ~= nil then
    obs.obs_source_set_muted(src, not obs.obs_source_muted(src))
    obs.obs_source_release(src)
  end
end

-- show/hide a source in every AD FINEM scene, all set to the same new state
local function toggle_item(source_name)
  local target = nil
  each_scene(function(scene)
    local item = obs.obs_scene_find_source(scene, source_name)
    if item ~= nil then
      if target == nil then target = not obs.obs_sceneitem_visible(item) end
      obs.obs_sceneitem_set_visible(item, target)
    end
  end)
end

local function find_webcam()
  local name = nil
  each_scene(function(scene)
    if name then return end
    local items = obs.obs_scene_enum_items(scene)
    if items then
      for _, item in ipairs(items) do
        local src = obs.obs_sceneitem_get_source(item)
        local id = obs.obs_source_get_unversioned_id(src)
        if id == "dshow_input" or id == "v4l2_input" or id == "av_capture_input" or id == "pipewire-camera-source" then
          name = obs.obs_source_get_name(src); break
        end
      end
      obs.sceneitem_list_release(items)
    end
  end)
  return name
end

local HOTKEYS = {
  { id = "adfinem_mic",      desc = "AD FINEM: Mute / unmute mic",          key = "OBS_KEY_F18", mods = "cas",
    fn = function() toggle_mute(MIC_CHANNEL) end },
  { id = "adfinem_desktop",  desc = "AD FINEM: Mute / unmute desktop audio", key = "OBS_KEY_F19", mods = "cas",
    fn = function() toggle_mute(DESKTOP_CHANNEL) end },
  { id = "adfinem_cam",      desc = "AD FINEM: Show / hide webcam",          key = "OBS_KEY_F20", mods = "cas",
    fn = function() local n = find_webcam(); if n then toggle_item(n) end end },
  { id = "adfinem_sponsors", desc = "AD FINEM: Show / hide sponsors",        key = "OBS_KEY_F21", mods = "cas",
    fn = function() toggle_item("AF Sponsors") end },
  { id = "adfinem_alerts",   desc = "AD FINEM: Show / hide alerts",          key = "OBS_KEY_F22", mods = "cas",
    fn = function() toggle_item("AF Alerts") end },
  { id = "adfinem_shot",     desc = "AD FINEM: Screenshot",                  key = "OBS_KEY_F23", mods = "cas",
    fn = function() obs.obs_frontend_take_screenshot() end },
  { id = "adfinem_rec",      desc = "AD FINEM: Start / stop recording",      key = "OBS_KEY_F24", mods = "cas",
    fn = function() if obs.obs_frontend_recording_active() then obs.obs_frontend_recording_stop() else obs.obs_frontend_recording_start() end end },
  { id = "adfinem_stream",   desc = "AD FINEM: Start / stop stream",         key = "OBS_KEY_F13", mods = "cs",
    fn = function() if obs.obs_frontend_streaming_active() then obs.obs_frontend_streaming_stop() else obs.obs_frontend_streaming_start() end end },
}

local handles = {}

function script_description()
  return "<b>AD FINEM Stream Kit</b><br>Toggles for the Stream Deck page: mic, desktop audio, webcam, " ..
         "sponsors, alerts, screenshot, recording and stream.<br>Change the keys in Settings &gt; Hotkeys (search \"AD FINEM\")."
end

local function default_binding(h)
  local arr = obs.obs_data_array_create()
  local d = obs.obs_data_create()
  obs.obs_data_set_string(d, "key", h.key)
  obs.obs_data_set_bool(d, "control", h.mods:find("c") ~= nil)
  obs.obs_data_set_bool(d, "alt", h.mods:find("a") ~= nil)
  obs.obs_data_set_bool(d, "shift", h.mods:find("s") ~= nil)
  obs.obs_data_array_push_back(arr, d)
  obs.obs_data_release(d)
  return arr
end

-- Windows: look for a kit update once, a little after OBS starts (asks only if there is one)
local function check_update()
  obs.timer_remove(check_update)
  if package.config:sub(1, 1) ~= "\\" then return end
  local ps = script_path() .. "../check-update.ps1"
  os.execute('start "" /b powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' .. ps .. '"')
end

function script_load(settings)
  local first = not obs.obs_data_get_bool(settings, "adfinem_defaults_set")
  for _, h in ipairs(HOTKEYS) do
    handles[h.id] = obs.obs_hotkey_register_frontend(h.id, h.desc, function(pressed) if pressed then h.fn() end end)
    local arr = first and default_binding(h) or obs.obs_data_get_array(settings, h.id)
    obs.obs_hotkey_load(handles[h.id], arr)
    obs.obs_data_array_release(arr)
  end
  obs.obs_data_set_bool(settings, "adfinem_defaults_set", true)
  obs.timer_add(check_update, 20000)
end

function script_save(settings)
  for _, h in ipairs(HOTKEYS) do
    local arr = obs.obs_hotkey_save(handles[h.id])
    obs.obs_data_set_array(settings, h.id, arr)
    obs.obs_data_array_release(arr)
  end
  obs.obs_data_set_bool(settings, "adfinem_defaults_set", true)
end
