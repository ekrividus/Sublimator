--[[
Copyright © 2020, Ekrividus
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of autoMB nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Ekrividus BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

--[[
autoMB will cast elements for magic bursts automatically
job/level is pulled from game and appropriate elements are used

single bursting only for now, but double may me introduced later

]]
_addon.version = '1.0.0'
_addon.name = 'Sublimator'
_addon.author = 'Ekrividus'
_addon.commands = {'sublimator','sublimate'}
_addon.lastUpdate = '9/8/2020'
_addon.windower = '4'

require 'tables'

res = require('resources')
config = require('config')

defaults = T{}
defaults.debug = false -- Show debug output
defaults.mp_missing = 600 -- Use when missing this many MP
defaults.mpp_low = 30 -- Or use if MP falls below this point
defaults.full_only = true -- Only use when MP full
defaults.min_charge_seconds = 90 -- Minimum time in seconds
defaults.delay = 1 -- seconds between MP checks
defaults.verbose = true -- Spam your chat with details

settings = config.load(defaults)
local player = windower.ffxi.get_player()
local buffs = T{}
local recasts = T{}
local last_check_time = 0
local charge_time = 0
local main_job = nil
local active = true

function get_buffs(player)
    local l = T{}
    for k, b in pairs(player.buffs) do
        if (res.buffs:with('id',b)) then
            l[b] = res.buffs:with('id',b).name
        end
    end

    return T(l)
end

function start()
    active = true
end

function stop()
    active = false
end

function reset()
    active = false
    main_job = windower.ffxi.get_player().main_job:lower()
    if (not settings[main_job]) then
        settings[main_job] = {}
        settings[main_job].mp_missing = settings.mp_missing
        settings[main_job].mpp_low = settings.mpp_low
        settings[main_job].mp_missing = settings.mp_missing
        settings[main_job].min_charge_seconds = settings.min_charge_seconds
    end
end

function show_help()
    windower.add_to_chat(17, _addon.name..": Help\n"..
    [[
        Keep sublimation up and use as appropriate.\n
        Commands:\n
        save - saves current settings to your main job\n
        mpp <number> - sets the MP % for sublimation\n
        missing <number> - sets an amount of MP lost for sublimation\n
        full [true|false] - will only use sublmiation when full if true\n
        charge <number> - sets minimum charge time for sublimation if full is false\n
        verbose [true|false] - sets whether or not to post extra messages
    ]])

end

windower.register_event('prerender', function(...)
    if (not active) then
        return
    end

    local time = os.time()
    player = windower.ffxi.get_player()

    if (player.status > 1) then
        return
    end

    if (last_check_time + settings.delay < time) then
        buffs = get_buffs(player)
        recasts = windower.ffxi.get_ability_recasts()
        last_check_time = time

        if (main_job and settings[main_job]) then 
            mpp_low = settings[main_job].mpp_low
            mp_missing = settings[main_job].mp_missing
            full_only = settings[main_job].full_only
            min_charge_seconds = settings[main_job].min_charge_seconds
        else
            mpp_low = settings.mpp_low
            mp_missing = settings.mp_missing
            full_only = settings.full_only
            min_charge_seconds = settings.min_charge_seconds
        end

        if (player.vitals.mpp < mpp_low or (player.vitals.max_mp - player.vitals.mp) > mp_missing) then
            if (buffs[188] and recasts[234] == 0) then
                if (settings[main_job].verbose or (settings[main_job].verbose == nil and settings.verbose)) then
                    windower.add_to_chat(17, _addon.name..": Sublimation for MP - Full")
                end
                windower.send_command('input /ja "Sublimation" <me>')
                return
            elseif (buffs[187] and not full_only and (charge_time + min_charge_seconds < time) and recasts[234] == 0) then
                if (settings[main_job].verbose or (settings[main_job].verbose == nil and settings.verbose)) then
                    windower.add_to_chat(17, _addon.name..": Sublimation for MP - Not Full")
                end
                windower.send_command('input /ja "Sublimation" <me>')
                return
            end
        end
        if ((not buffs[187] and not buffs[188]) and (not recasts[234] or recasts[234] == 0)) then
            if (settings[main_job].verbose or (settings[main_job].verbose == nil and settings.verbose)) then
                windower.add_to_chat(17, _addon.name..": Sublimation - Up")
            end
            charge_time = time
            windower.send_command('input /ja "Sublimation" <me>')
            return
        end
    end
end)

windower.register_event('load', reset)
windower.register_event('job change', function()
    reset()
end)

windower.register_event('logout', stop)
windower.register_event('zone change', stop)

windower.register_event('addon command', function(...)
    local cmd = ''
    local args = T{}
    if (#arg > 0) then
        args = T(arg)
        cmd = args[1]
        args:remove(1)
    end

    if (cmd == '') then
        active = not active
        windower.add_to_chat(17, _addon.name..": "..(active and "Starting" or "Stopping"))
    elseif (cmd == 'start') then
        start()
        windower.add_to_chat(17, _addon.name..": "..(active and "Starting" or "Stopping"))
    elseif (cmd == 'stop') then
        stop()
        windower.add_to_chat(17, _addon.name..": "..(active and "Starting" or "Stopping"))
    elseif (cmd == 'save') then
        settings:save()
        windower.add_to_chat(17, _addon.name..": Saving settings for "..main_job)
    elseif (cmd == 'help' or cmd == 'h') then
        show_help()
    elseif (cmd == 'mpp') then
        windower.add_to_chat(17, #args.." - "..args[1])
        if (#args > 0 and tonumber(args[1])) then
            settings[main_job].mpp_low = tonumber(args[1])
        end
    elseif (cmd == 'missing') then
        if (#args > 0 and tonumber(args[1])) then
            settings[main_job].mp_missing = tonumber(args[1])
        end
    elseif (cmd == 'full') then
        if (#args > 0) then
            if (args[1] == 'true') then
                settings[main_job].full_only = true
            elseif (args[1] == 'false') then
                settings[main_job].full_only = false
            else
                settings[main_job].full_only = not settings[main_job].full_only
            end
        end
    elseif (cmd == 'charge') then
        if (#args > 0 and tonumber(args[1])) then
            settings[main_job].min_charge_seconds = tonumber(args[1])
        end
    elseif (cmd == 'verbose' or cmd == 'v') then
        if (#args > 0) then
            if (args[1] == 'true') then
                settings[main_job].verbose = true
            elseif (args[1] == 'false') then
                settings[main_job].verbose = false
            else
                settings[main_job].verbose = not settings[main_job].verbose
            end
        end
    end
end)
