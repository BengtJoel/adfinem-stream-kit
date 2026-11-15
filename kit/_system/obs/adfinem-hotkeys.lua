--[[
  AD FINEM Stream Kit - toggles for Stream Deck (or any keyboard)
  Added to OBS by the kit's installer (Tools > Scripts). Each toggle is a normal
  OBS hotkey you can change in Settings > Hotkeys ("AD FINEM: ...").

  Default keys (Ctrl + Alt + Shift + ...), used by the AD FINEM Stream Deck page:
    F13-F16  scenes (set on the scenes themselves; F17 = Ending too, it plays the outro)
    F18 mic   F19 desktop audio   F20 webcam   F21 sponsors   F22 alerts
    F23 screenshot   F24 recording        Ctrl + Shift + F13  start/stop stream
    F12 music in my headphones on/off (the music stays on stream)
  Webcam, sponsors and alerts are kept the same in every scene: show or hide one (here, in OBS
  or with the Stream Deck's OBS keys) and the others follow.
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

-- Music for the stream ("AF Music" = VB-CABLE, Spotify plays into it; set up by the kit's installer).
-- The item "AF Music - in my headphones" in "AF - In-Game" is the switch (Stream Deck "Music" key or the
-- hotkey): visible = you hear the music too. The stream always has it. OBS plays it to your headphones
-- (audio monitoring); Desktop Audio already records everything you hear, so while you listen and Desktop
-- Audio is on, OBS does not add it a second time.
local MUSIC, MUSIC_SWITCH = "AF Music", "AF Music - in my headphones"
local desktop_sh, music_armed = nil, false

local function hear_music()
  local vis = nil
  each_scene(function(scene)
    if vis ~= nil then return end
    local item = obs.obs_scene_find_source(scene, MUSIC_SWITCH)
    if item ~= nil then vis = obs.obs_sceneitem_visible(item) end
  end)
  return vis ~= false
end

local function desktop_live()
  local src = obs.obs_get_output_source(DESKTOP_CHANNEL)
  if src == nil then return false end
  local live = obs.obs_source_enabled(src) and not obs.obs_source_muted(src)
  obs.obs_source_release(src)
  return live
end

local function apply_music()
  obs.timer_remove(apply_music); music_armed = false
  local m = obs.obs_get_source_by_name(MUSIC)
  if m == nil then return end
  local want = obs.OBS_MONITORING_TYPE_NONE                                    -- stream only
  if hear_music() then
    want = desktop_live() and obs.OBS_MONITORING_TYPE_MONITOR_ONLY             -- you hear it, Desktop Audio puts it on stream
                          or obs.OBS_MONITORING_TYPE_MONITOR_AND_OUTPUT        -- you hear it, OBS puts it on stream
  end
  if obs.obs_source_get_monitoring_type(m) ~= want then obs.obs_source_set_monitoring_type(m, want) end
  obs.obs_source_release(m)
end

local function music_later()
  if not music_armed then music_armed = true; obs.timer_add(apply_music, 60) end
end

local function on_desktop_mute(cd) music_later() end

local function toggle_music()
  local done = false
  each_scene(function(scene)
    if done then return end
    local item = obs.obs_scene_find_source(scene, MUSIC_SWITCH)
    if item ~= nil then obs.obs_sceneitem_set_visible(item, not obs.obs_sceneitem_visible(item)); done = true end
  end)
  music_later()
end

-- Keep webcam, sponsors and alerts the same in every scene. The Stream Deck's OBS keys switch the
-- one in "AF - In-Game" (so they can show its state); this copies the change to the other scenes.
local MIRROR = { ["AF Sponsors"] = true, ["AF Alerts"] = true }
local webcam_name, handlers, pending, armed, applying = nil, {}, {}, false, false

local function mirror_tick()
  obs.timer_remove(mirror_tick); armed = false
  local todo = pending; pending = {}
  applying = true
  for name, vis in pairs(todo) do
    each_scene(function(scene)
      local item = obs.obs_scene_find_source(scene, name)
      if item ~= nil and obs.obs_sceneitem_visible(item) ~= vis then obs.obs_sceneitem_set_visible(item, vis) end
    end)
  end
  applying = false
end

local function on_item_visible(cd)
  if applying then return end
  local item = obs.calldata_sceneitem(cd, "item")
  if item == nil then return end
  local name = obs.obs_source_get_name(obs.obs_sceneitem_get_source(item))
  if name == MUSIC_SWITCH then music_later(); return end
  if MIRROR[name] or (webcam_name ~= nil and name == webcam_name) then
    pending[name] = obs.calldata_bool(cd, "visible")
    if not armed then armed = true; obs.timer_add(mirror_tick, 40) end      -- do it outside the signal
  end
end

local function unhook_scenes()
  for _, sh in ipairs(handlers) do obs.signal_handler_disconnect(sh, "item_visible", on_item_visible) end
  handlers = {}
  if desktop_sh ~= nil then
    obs.signal_handler_disconnect(desktop_sh, "mute", on_desktop_mute)
    obs.signal_handler_disconnect(desktop_sh, "enable", on_desktop_mute)
    desktop_sh = nil
  end
end

local function hook_scenes()
  unhook_scenes()
  local scenes = obs.obs_frontend_get_scenes()
  if scenes then
    for _, src in ipairs(scenes) do
      local sh = obs.obs_source_get_signal_handler(src)
      obs.signal_handler_connect(sh, "item_visible", on_item_visible)
      table.insert(handlers, sh)
    end
    obs.source_list_release(scenes)
  end
  webcam_name = find_webcam()
  local d = obs.obs_get_output_source(DESKTOP_CHANNEL)
  if d ~= nil then
    desktop_sh = obs.obs_source_get_signal_handler(d)
    obs.signal_handler_connect(desktop_sh, "mute", on_desktop_mute)
    obs.signal_handler_connect(desktop_sh, "enable", on_desktop_mute)
    obs.obs_source_release(d)
  end
  music_later()
end

local function on_frontend_event(ev)
  if ev == obs.OBS_FRONTEND_EVENT_SCENE_COLLECTION_CHANGING or ev == obs.OBS_FRONTEND_EVENT_EXIT then
    unhook_scenes()
  elseif ev == obs.OBS_FRONTEND_EVENT_FINISHED_LOADING or ev == obs.OBS_FRONTEND_EVENT_SCENE_COLLECTION_CHANGED
      or ev == obs.OBS_FRONTEND_EVENT_SCENE_LIST_CHANGED then
    hook_scenes()
  end
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
  { id = "adfinem_music",    desc = "AD FINEM: Music in my headphones on / off (stays on stream)", key = "OBS_KEY_F12", mods = "cas",
    fn = function() toggle_music() end },
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
  obs.obs_frontend_add_event_callback(on_frontend_event)
  hook_scenes()                       -- (no scenes yet when OBS is starting: FINISHED_LOADING hooks them)
end

function script_unload()
  unhook_scenes()
end

function script_save(settings)
  for _, h in ipairs(HOTKEYS) do
    local arr = obs.obs_hotkey_save(handles[h.id])
    obs.obs_data_set_array(settings, h.id, arr)
    obs.obs_data_array_release(arr)
  end
  obs.obs_data_set_bool(settings, "adfinem_defaults_set", true)
end
