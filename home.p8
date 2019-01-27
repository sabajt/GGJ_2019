pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

level = 1
influence_multiplier = 8
swing = 0
fps = 30
-- music(0)

-- inits
function _init()
    debugclear()
    init_scene("putt")
end

function init_scene(s)
    pal()
    scene = s
    init_models() -- belongs in init_putt?
    if (scene == "putt") init_putt()
end

function init_models()
    init_levels()
    cam = new_cam()
    ship = new_ship(get_start_pos(level))
    stars = new_stars()
    homeclouds = new_clouds(start_planet().pos)
    dog = new_dog(get_planets(level)[2]) --TODO:hard coded to always be the second planet in the level
    house = new_house(get_start_pos(level))
end

function init_putt()
    set_state("putt.pre")
    shake = 0
    ship.facing = 2 -- up (redundant with new_ship)
end

-- models

function new_cam()
    return {
        pos = zerovec(),
        lerptime = 0,
        vel = zerovec(),
        acl = zerovec(),
        acl_scale = 0.5
    }
end

function in_cam_view(center)
    local in_x_view = center.x >= cam.pos.x and center.x <= cam.pos.x+128
    local in_y_view = center.y >= cam.pos.y and center.y <= cam.pos.y+128
    return in_x_view and in_y_view
end

function new_ship(pos)
    return {
        pos = pos,
        rad = 2,
        rot = 0.25,
        col = 3,
        facing = 2, -- 1:upright -> ccwise -> 8:right
        turn_tick = 0,
        vel = zerovec(),
        acl = zerovec(),
        min_mag = 0.5,
        low_mag = 0.7,
        time = 0,
        boosttime = 0,
        res_mag = 0.0008, -- changed by delta
        start_res_mag = 0.0008, -- constant
        res_delta = 0.0008, -- constant
        emitter = new_emitter(
            0.08, -- emit rate
            pos, -- emit position
            0, -- emit angle
            0.2, -- emit angle plus or minus variation
            1.5, -- particle life (seconds)
            0.5, -- particle start radius
            3, -- particle end radius
            0.5, -- particle start magnitude
            0, -- particle end magnitude
            60, -- max number of particles
            {8, 2, 13, 1} -- particle color progression
        )
    }
end

function new_dog(planet)
    return {
        pos = planet_perimeter_point(planet, .25),
        rad = 4
    }
end

function new_house(start_pos)
        pos_x = start_pos.x - 27
        pos_y = start_pos.y - 15
        return {
        pos = makevec(pos_x, pos_y)
    }
end

-- rotation is based on facing for now.
-- this will flip to facing based on rotation for v2 (precicion) steering
function get_ship_rot()
    return ship.facing / 8 -- facing 1:upright -> ccwise -> 8:right
end

function get_ship_vel_ang()
    return angle(ship.vel)
end

function get_ship_stopped()
    local breakpoint = 15
    return shipmag() < ship.min_mag and ship.time > breakpoint
end

-- new planet args (x, y, rad, col, moon_rad, moon_orbit_rad, moon_ang, moon_col)
-- if planet has no moon, just leave off last 4 args
function init_levels()
    -- puppy planet center
    local p2 = makevec(3500, -3700)
    local p2rad = 150

    local p2fields = {}
    local fieldcount = 15
    for i=1,fieldcount do
        local a = i/fieldcount
        local p = perimeter_point(p2, p2rad, a)
        p = addvec(p, polarvec(a, 320))
        local f = new_mine_field(p.x, p.y, 260, 25) 
        add(p2fields, f)
    end
    
    levels = {
        { -- 1
            par = 1,
            goal = new_goal(-200, 64, 3),
            planets = {
                new_planet(64, 64, 250, 4, 50, 1925, .25, 7),
                new_planet(p2.x, p2.y, p2rad, 3, 75, 1150, .75, 7)
            },
            mine_fields = p2fields
        },
        {  -- 2
            par = 2,
            goal = new_goal(64, 20, 3),
            planets = {
                new_planet(64, 64, 5, 4)
            }
        },
        {  -- 3
            par = 2,
            goal = new_goal(-45, 10, 3),
            planets = {
                new_planet(50, 70, 5, 3),
                new_planet(-10, 30, 7, 5)
            }
        },
        {  -- 4
            par = 2,
            goal = new_goal(-45, 10, 3),
            planets = {
                new_planet(20, 10, 5, 4),
                new_planet(120-12, 64, 7, 5),
                new_planet(120-30, 120-10, 4, 11),
                new_planet(50, 40, 4, 13),
                new_planet(10, 100, 9, 12),
                new_planet(120, 0, 10, 15)
            }
        }
    }
end

function new_goal(x, y, rad)
    return {
        pos = makevec(x, y),
        rad = rad
    }
end

function new_planet(x, y, rad, col, moon_rad, moon_orbit_rad, moon_ang, moon_col)
    local pos = makevec(x, y)
    return {
        pos = pos,
        rad = rad,
        col = col,
        huddist = 0, -- scaled, readable distance from ship to planet for hud display
        moon = new_moon(pos, moon_rad,  moon_orbit_rad, moon_ang, moon_col)
    }
end

function new_moon(planet_pos, moon_rad, orbit_rad, orbit_ang, moon_col)
    if (moon_rad == nil) return
    return {
        pos = perimeter_point(planet_pos, orbit_rad, orbit_ang), --update angle to simulate orbit
        rad = moon_rad,
        col = moon_col,
        orbit_ang = orbit_ang,
        orbit_rad = orbit_rad
    }
end

function new_mine_field(x, y, rad, count)
    local pos = makevec(x, y)
    return {
        pos = pos,
        rad = rad,
        mines = new_mines(pos, rad, count)
    }
end

function update_moon(planet)
    local moon = planet.moon
    moon.orbit_ang += 1/(30*30*5)
    moon.pos =  perimeter_point(planet.pos, moon.orbit_rad, moon.orbit_ang)
end

function new_emitter(rate, pos, ang, ang_pm, life, start_rad, end_rad, start_mag, end_mag, max, color_tab)
    return {
        t = 0,
        rate = rate,
        pos = pos,
        ang = ang,
        ang_pm = ang_pm,
        life = life,
        start_rad = start_rad,
        end_rad = end_rad,
        start_mag = start_mag,
        end_mag = end_mag,
        max = max,
        color_tab = color_tab,
        particles = {},
        active = false
    }
end

function new_particle(pos, ang, life, start_rad, end_rad, start_mag, end_mag, color_tab)
    return {
        t = 0,
        pos = pos,
        vel = polarvec(ang, start_mag),
        ang = ang,
        life = life,
        rad = start_rad,
        start_rad = start_rad,
        end_rad = end_rad,
        start_mag = start_mag,
        end_mag = end_mag,
        color_tab = color_tab,
        col = color_tab[1]
    }
end

function get_level(lev)
     return levels[lev]
end


function get_planets(lev)
    return get_level(lev).planets
end

function get_mine_fields(lev)
    return get_level(lev).mine_fields
end

function get_goal(lev)
    return get_level(lev).goal
end

function get_planet_foi(planet)
    return planet.rad * influence_multiplier
end

-- todo: start at any angle
function get_start_pos(lev)
    local planet = start_planet()
    return addvec(planet.pos, makevec(0, -planet.rad))
end


function new_stars()
    local area = makevec(128*15, 128*15)
    local tab = {}
    for s=4,7 do
        for i=1,350 do
            local p = makevec(rnd(1) * area.x - area.x / 2, rnd(1) * area.y - area.y / 2)
            local d = 1
            if (s == 4) d = 0.6
            if (s == 5) d = 0.7
            if (s == 6) d = 0.8
            if (s == 7) d = 0.9
            add(tab, { sprite = s, org_pos = p, depth = d})
        end
    end
    return tab
end

function new_clouds(center)
    local rad = 400
    local tab = {}
    for s=18,19 do
        for i=1,70 do
            local p = rnd_circ_vec(center, rad)
            local d = 1
            if (s == 18) d = 0.2
            if (s == 19) d = 0.3
            add(tab, { sprite = s, org_pos = p, depth = d})
        end
    end
    return tab
end

function new_mines(center, rad, count)
    local mines = {}
    for i=1,count do
        local pos = rnd_circ_vec(center, rad)
        add(mines, {sprite = 18, pos = pos, rad = 8, hit = false})
    end
    return mines
end

-- updates

function _update()
    if (scene == "putt") update_putt()
    update_time()
    -- debuglog("frame rate: " .. stat(7))
end

function update_time()
    if (gtime == nil) gtime = {}
    if (gtime.frame == nil) gtime.frame = 0
    if (gtime.sec == nil) gtime.sec = 0
    if (gtime.min == nil) gtime.min = 0

    gtime.frame += 1

    if gtime.frame == fps then
        gtime.sec += 1
        gtime.frame = 0
    end

    if gtime.sec == 60 then
        gtime.min += 1
        gtime.sec = 0
    end
end

function update_hud()
    if hud == nil then
        hud = {}
        hud.speed = 0
    end

    -- space out hud number displays for readability
    if ship.time % 8 == 0 then
        hud.speed = flr(shipmag() * 10) -- readable speed
        local i = 1
        for p in all(get_planets(level)) do
            p.huddist = flr(planet_dist(i) * 0.2)
            i += 1
        end
    end
end

function update_putt()
    if in_state("putt.pre") then
        update_putt_pre()
    elseif state == "putt.launch" or state == "putt.catchup" or state == "putt.fly" then
        update_putt_fly()
    elseif state == "putt.win" then
        update_putt_win()
    end

    update_moons()
    update_emitter(ship.emitter)
    update_hud()
    update_putt_cam()
end

function update_moons()
    for p in all(get_planets(level)) do
        update_moon(p)
    end
end

function update_putt_pre()
    if btnp(5) then
        set_state("putt.launch")
        ship.vel = zerovec()
    end
end

function update_putt_fly()

    local ship_in_grav_field = false
    local stopped = false

    -- accumulate forces
    ship.acl = zerovec()
    for p in all(get_planets(level)) do
        local checkcollide = ship.time > 30
        if checkcollide and circcollide(ship.pos.x, ship.pos.y, ship.rad, p.pos.x, p.pos.y, p.rad) then
            -- collide with planet body
            stop_ship() -- any bugs if the rest of function continues?
            stopped = true
        elseif circcollide(ship.pos.x, ship.pos.y, ship.rad, p.pos.x, p.pos.y, get_planet_foi(p)) then
            -- in planet grav field
            -- ship.acl = addvec(ship.acl, gravity(p, ship))
            ship_in_grav_field = true
        end
    end

    local i = 1
    for f in all(get_mine_fields(level)) do
        local d = dist(ship.pos, f.pos) - f.rad
        if d < 20 then
            for m in all(f.mines) do
                if circcollide(ship.pos.x, ship.pos.y, ship.rad, m.pos.x + 8, m.pos.y + 8, m.rad) then
                    m.hit = true
                    shake = 8
                else
                    m.hit = false
                end
            end
        end
    end

    if stopped == false then
        update_putt_fly_2()
    end
end

-- todo: don't be silly
function update_putt_fly_2()

    if btn(5) then
        if btn(3) then -- slow
            ship.vel = scalevec(ship.vel, 0.8)
        else
            -- if (btn(2)) -- fast? 

            ship.emitter.active = true
            ship.acl = addvec(ship.acl, boostvec())
            if ship.boosttime == 0 then
                ship.showflame = true
                ship.flipflame = false
            end

            if (ship.boosttime % 2 == 0) ship.showflame = not ship.showflame
            if (ship.boosttime % 4 == 0) ship.flipflame = not ship.flipflame
            ship.boosttime += 1
        end
    else
        ship.emitter.active = false
        ship.boosttime = 0
        ship.showflame = false
    end

    -- turn rocket facing (does this need to be somewhere else?)
    if btn(0) then -- left
        ship.turn_tick += 1
        if ship.turn_tick > 3 then
            ship.facing += 1
            ship.turn_tick = 0
        end
    elseif btn(1) then -- right
        ship.turn_tick += 1
        if ship.turn_tick > 3 then
            ship.facing -= 1
            ship.turn_tick = 0
        end
    else
        ship.turn_tick = 0
    end
    ship.facing = wrap(ship.facing, 0, 7, true)

    -- velocity, positions
    ship.vel = addvec(ship.vel, ship.acl)
    ship.pos = addvec(ship.pos, ship.vel)
    ship.emitter.pos = ship.pos
    ship.emitter.ang = inv_angle(get_ship_rot())

    -- check for goal
    local goal = get_goal(level)
    if circcollide(ship.pos.x, ship.pos.y, ship.rad, goal.pos.x, goal.pos.y, goal.rad) then
        win_level()
    end

    ship.time += 1
end

function update_putt_win()
    if btnp(5) then
        level = level + 1
        init_scene("putt")
    end
end

-- update cameras

function update_putt_cam()
    if state == "putt.pre" then
        update_putt_prelaunch_cam()
    elseif state == "putt.launch" then
        update_putt_launch_cam()
    elseif state == "putt.catchup" then
        update_putt_catchup_cam()
    elseif state == "putt.fly" then
        update_putt_fly_cam()
    end
end

function update_putt_prelaunch_cam()
    local rel_target = perimeter_point(centervec(), 30, inv_angle(get_ship_rot()))
    local cam_target = subvec(ship.pos, rel_target)
    local seek =  subvec(cam_target, cam.pos)
    local seek_dist = dist(cam.pos, cam_target)
    if seek_dist > 1  then
        local move_by = scalevec(seek, 0.1)
        cam.pos = addvec(cam.pos, move_by)
    else
        cam.pos = cam_target
    end
end

function update_putt_launch_cam()
    if dist(ship.pos, get_start_pos(level)) > 30 then
        cam.lerptime = 0
        set_state("putt.catchup")
    end
end

function update_putt_catchup_cam()
    local target = subvec(ship.pos, cam_rel_target())
    local seek =  subvec(target, cam.pos)
    local perc = cam.lerptime / 30

    if vecmag(seek) > 2 and perc < 1 then
        local move = scalevec(seek, perc)
        cam.pos = addvec(cam.pos, move)
    else
        cam.pos = target
        set_state("putt.fly")
    end

    cam.lerptime += 1
end

function update_putt_fly_cam()
    cam.pos = subvec(ship.pos, cam_rel_target())
    if shake > 0 then
        cam.pos = rnd_circ_vec(cam.pos, 4)
        shake -= 1
    end
end

-- physics

function gravity(attractor, mover)
    local dir = dirvec(attractor.pos, mover.pos)
    local centerdist = dist(attractor.pos, mover.pos)
    local planetdist = centerdist - attractor.rad
    local gravrange = abs(get_planet_foi(attractor) - attractor.rad)
    local invpercent = 1 - (planetdist / gravrange)
    local minmag = 0.02
    local maxmag = 0.1
    local mag = lerp(minmag, maxmag, invpercent)
    return scalevec(dir, mag)
end

function rectcollide(x1, y1, x2, y2, xx1, yy1, xx2, yy2)
    return (x2 >= xx1 and x1 <= xx2 and y2 >= yy1 and y1 <= yy2)
end

function rectinclude(x1, y1, x2, y2, px, py)
    return (px >= x1 and px <= x2 and py >= y1 and py <= y2)
end

function circcollide(c1x, c1y, r1, c2x, c2y, r2)
    local distance = makevec(abs(c1x-c2x), abs(c1y-c2y))
    local mag = vecmag(distance)
    return mag <= (r1 + r2)
end

-- draw

function _draw()
    cls()
    camera(cam.pos.x, cam.pos.y)
    if (scene == "putt") draw_putt()
    draw_hud()
    draw_border()
    draw_debug()
end

function draw_debug()
    local xorg = cam.pos.x + 8
    local yorg = cam.pos.y + 10
    local row = 6

    -- print(state, xorg, yorg) -- game state
    print("fr: " .. stat(7), xorg, yorg)

end

function draw_border()
    line(cam.pos.x, cam.pos.y, cam.pos.x + 127, cam.pos.y, 7) -- top
    line(cam.pos.x + 127, cam.pos.y, cam.pos.x + 127, cam.pos.y + 127, 7) -- right
    line(cam.pos.x + 127, cam.pos.y + 127, cam.pos.x, cam.pos.y + 127, 7) -- bottom
    line(cam.pos.x, cam.pos.y + 127, cam.pos.x, cam.pos.y, 7) -- left
end

function draw_hud()
    hud_bottom = cam.pos.y + 8
    local leftmargin = cam.pos.x + 8
    local topmargin = cam.pos.y + 2
    -- local rightmargin = cam.pos.x + 125

    if in_states({"putt.fly", "putt.catchup", "putt.launch"}) then
        draw_hud_dist()
    end

    line(cam.pos.x, hud_bottom, cam.pos.x + 127, hud_bottom, 7) -- hud divider
    print(hud.speed, leftmargin, topmargin, 7) -- velocity
end

function draw_hud_dist()
    local i = 1
    for p in all(get_planets(level)) do
        local dir = dirvec(p.pos, ship.pos)
        local ang = angle(dir)
        local contact = perimeter_point(p.pos, p.rad, inv_angle(ang))

        if in_cam_view(contact) then -- display ship-planet contact shadow
            if planet_dist(i) > 8 then
                circfill(contact.x, contact.y, 2, 3)
            end
        else -- guide line to planets
            if gtime != nil then
                if gtime.frame % 20 == 0 or gtime.frame % 22 == 0 then 
                    line(contact.x, contact.y, ship.pos.x, ship.pos.y, p.col)
                end
            end
        end
        i += 1
    end
end

function cam_box() -- top-left, top-right, bottom-right, bottom-left
    return cam.pos, addvec(cam.pos, makevec(128, 0)), addvec(cam.pos, makevec(128, 128)), addvec(cam.pos, makevec(0, 128))
end

function line_intersect(v1, v2, w1, w2)
    local x = nil
    local y = nil

    local a1, b1, c1 = line_coef(v1, v2)
    local a2, b2, c2 = line_coef(w1, w2)

    local det = a1 * b2 - a2 * b1
    if det != 0 then
        x = (b2 * c1 - b1 * c2) / det
        y = (a1 * c2 - a2 * c1) / det
    end

    return x, y
end

function line_coef(v1, v2)
    local a = v2.y - v1.y
    local b = v1.x - v2.x
    local c = a * v1.x + b * v1.y
    return a, b, c
end

function draw_parallax_sprite_tab(tab)
    local i = 0
    for s in all(tab) do
        local pos = addvec(s.org_pos, scalevec(flrvec(cam.pos), s.depth))
        spr(s.sprite, pos.x, pos.y)
        i += 1
    end
end

function draw_putt()
    -- parallax objects
    draw_parallax_sprite_tab(stars)

    -- planets
    local pi = 1
    for p in all(get_planets(level)) do
        if pi == 1 then
            --final transition zone
            circfill(p.pos.x, p.pos.y, p.rad + 850, 1)
            circ(p.pos.x , p.pos.y , p.rad + 850, 1)

            --middle transition zone
            circfill(p.pos.x, p.pos.y, p.rad + 550, 13)
            circ(p.pos.x , p.pos.y , p.rad + 550, 13)

            --atmosphere
            circfill(p.pos.x, p.pos.y, p.rad +250, 12)
            circ(p.pos.x , p.pos.y , p.rad + 250, 12)

            draw_parallax_sprite_tab(homeclouds)
        end

        --planet
        circfill(p.pos.x, p.pos.y, p.rad, p.col)
        circ(p.pos.x, p.pos.y, get_planet_foi(p), p.col)

        --moon
        if (p.moon != nil) then
            circfill(p.moon.pos.x, p.moon.pos.y, p.moon.rad, p.moon.col)
            circ(p.moon.pos.x, p.moon.pos.y, p.moon.rad, p.moon.col)
        end

        pi += 1
    end

    --mines
    for f in all(get_mine_fields(level)) do
        for m in all(f.mines) do
            spr(33, m.pos.x, m.pos.y, 2, 2)
            if (m.hit) circfill(m.pos.x + 8, m.pos.y + 8, m.rad, 10)
        end
    end

    -- particles
    draw_particles()

    -- goal
    local goal = get_goal(level)
    spr(16, goal.pos.x-4, goal.pos.y-12, 1, 2)

    --dog
    spr(20, dog.pos.x, dog.pos.y)
        --sprite scaling example
        -- sspr(32, 8, 8, 8, dog.pos.x, dog.pos.y, 150, 150)
    --house
    spr(35, house.pos.x, house.pos.y, 2, 2)
    -- ship
    local shiptab = ship_spr()
    spr(shiptab[1], ship.pos.x-4, ship.pos.y-4, 1, 1, shiptab[2], shiptab[3])

    -- flame
    if ship.showflame then
        local f = flame_spr()
        spr(f.sprite, ship.pos.x + f.offset.x, ship.pos.y + f.offset.y, 1, 1, f.flipx, f.flipy)
    end

    -- win state
    if state == "putt.win" then
        local win_text = "sunk it!"
        print(win_text, cam.pos.x+hcenter(win_text), cam.pos.y+10, 7)
    end

    -- effects
    if shake == 7 or shake == 5 or shake == 3  then
        pal(0, 9, 1)
        pal(5, 10, 1)
        pal(1, 2, 1)
        pal(6, 10, 1)
    elseif shake == 6 or shake == 4 or shake == 2 or shake == 1 then
        pal()
    end
end

function draw_particles()
    for p in all(ship.emitter.particles) do
        circfill(p.pos.x, p.pos.y, p.rad, p.col)
    end
end

-- debug

function debugclear()
    printh("", "home", true)
end

function debuglog(s)
    printh(format_gtime() .. s, "home")
end

function format_gtime()
    local s = "[nil:nil:nil] "
    if (gtime != nil) s = "[" .. gtime.min .. ":" .. gtime.sec .. ":" .. gtime.frame .. "] "
    return s
end

function csv_new(name, headers)
    if (csv == nil) csv = {}
    csv[name] = {}
    csv[name].headers = headers
    csv[name].values = {}
end

function csv_append(name, values)
    for v in all(values) do
        add(csv[name].values, v)
    end
end

function csv_debuglog(name)
    local headers = csv[name].headers

    debuglog("")
    debuglog("csv " .. name .. ":")
    debuglog("--------------")
    debuglog(csv_format_line(headers))

    local linebuffer = {}
    local i = 1
    for v in all(csv[name].values) do
        add(linebuffer, v)
        if i % #headers == 0 then
            debuglog(csv_format_line(linebuffer))
            linebuffer = {}
        end
        i += 1
    end
end

function csv_format_line(values)
    local i = 1
    local result = ""
    for v in all(values) do
        result = result .. v
        if (i != #values) result = result .. ","
        i += 1
    end
    return result
end

-- vectors

function makevec(xval, yval)
    return {x=xval, y=yval}
end

function zerovec()
    return makevec(0, 0)
end

function centervec()
    return makevec(64, 64)
end

function addvec(v1, v2)
    return makevec(v1.x + v2.x, v1.y + v2.y)
end

function subvec(v1, v2)
    return makevec(v1.x - v2.x, v1.y - v2.y)
end

function scalevec(v1, s)
    return makevec(v1.x * s, v1.y * s)
end

function normvec(v)
    return scalevec(v, 1 / vecmag(v))
end

function limvec(v, max)
    return (vecmag(v) > max) and scalevec(normvec(v), max) or v
end

function flrvec(v)
    return makevec(flr(v.x), flr(v.y))
end

function dirvec(to, from)
    return normvec(subvec(to, from))
end

function dirvec_snap(dir)
    local d = zerovec()
    -- todo: is the dirvec invocation pointless? (1, 0) unit vec?
    if (dir == "left") d = dirvec(makevec(-1, 0), zerovec())
    if (dir == "right") d = dirvec(makevec(1, 0), zerovec())
    if (dir == "up") d = dirvec(makevec(0, -1), zerovec())
    if (dir == "down") d = dirvec(makevec(0, 1), zerovec())
    return d
end

function dist(v1, v2)
    return vecmag(subvec(v1, v2))
end

function polarvec(ang, mag)
    return scalevec(makevec(cos(ang), sin(ang)), mag)
end

function angle(v)
    return atan2(v.x, v.y)
end

function vecmag(v)
    -- scale down first to avoid overflow 182^2 > 32767
    local m = max(abs(v.x), abs(v.y))
    local x = v.x / m
    local y = v.y / m
    return sqrt(x*x + y*y) * m
end

function vecstring(v)
    return "("..v.x..", "..v.y..")"
end

function perimeter_point(center, rad, ang)
    return addvec(center, flrvec(polarvec(ang, rad)))
end

function planet_perimeter_point(planet, ang)
    local point = perimeter_point(planet.pos, planet.rad, ang)
    return point
end
-- particles

function update_emitter(e)
    local rate = flr(e.rate * fps)

    -- cull
    if #e.particles > e.max then
        del(e.particles, e.particles[1])
    end

    -- update
    for p in all(e.particles) do
        update_particle(e.particles, p)
    end

    -- new particle if needed (must be after update, or could appear ahead of rocket
    -- this should be fixed in update_particle)
    if e.active and e.t % rate == 0 then
        local ang = e.ang + rnd_range(-e.ang_pm, e.ang_pm)
        local part = new_particle(e.pos, ang, e.life, e.start_rad, e.end_rad, e.start_mag, e.end_mag, e.color_tab)
        add(e.particles, part)
    end

    -- increment
    e.t += 1
end

function update_particle(particles, p)

    local acl = zerovec()

    -- percent thru  particle life
    local perc = p.t / (p.life * fps)

    -- momentum v1:
    local maxmag = 4
    local mperc = clamp(shipmag(), 0, maxmag) / maxmag
    acl = addvec(acl, scalevec(ship.vel, (1 - perc) * (0.99 * mperc)))

    -- calculate base velocity
    local mag = lerp(p.start_mag, p.end_mag, perc)
    p.vel = polarvec(p.ang, mag)

    -- radius: 0.5 is a valid rad (1 pt) but > 1 is floored in circfill, so add 1 to end rad
    p.rad = lerp(p.start_rad, p.end_rad + 1, perc)

    -- color
    local col_idx = ceil(perc * #p.color_tab)
    p.col = p.color_tab[col_idx]

    -- apply velocity, increment time
    p.vel = addvec(p.vel, acl)
    p.pos = addvec(p.pos, p.vel)
    p.t += 1

    -- remove after life
    if p.t > p.life * fps then
        del(particles, p)
    end
end

-- other

function rndtab(tab)
    return tab[ceil(rnd(1)*#tab)]
end

function lerp(val1, val2, t)
    local diff = val2 - val1
    return val1 + (t * diff)
end

function inv_angle(a)
    return a-0.5 > 0 and a-0.5 or (a-0.5)+1
end

function wrap(n, low, high, truncate)
    if n < low then
        if (truncate) return high
        return high - (low - n)
    elseif n > high then
        if (truncate) return low
        return low + (n - high)
    end
    return n
end

function clamp(n, low, high)
    if (n < low) return low
    if (n > high) return high
    return n
end

function rnd_range(a, b)
    local max = max(a, b)
    local min = min(a, b)
    return min + rnd(max - min)
end

function rnd_circ_vec(center, rad)
    -- https://programming.guide/random-point-within-circle.html
    local r = sqrt(rnd(1)) * rad
    local a = rnd(1)
    local p = makevec(r * cos(a), r * sin(a))
    return addvec(center, p)
end

-- game

function set_state(s)
    state = s
    debuglog("")
    debuglog("state: " .. s)
    debuglog("")
end

function stop_ship()
    ship.vel = zerovec()
    ship.pwr = 0
    ship.time = 0
    ship.res_mag = ship.start_res_mag
    ship.emitter.active = false
    ship.pos = get_start_pos(level)
    ship.facing = 2
    set_state("putt.pre")
end

function win_level()
    set_state("putt.win")
    ship.vel = zerovec()
end

function cam_rel_target()
    return perimeter_point(centervec(), cam_radius(), inv_angle(get_ship_vel_ang()))
end

function cam_radius()
    -- radius is proportional to rocket magnitude.
    local radrange = 40
    local magrange = 10
    return min((radrange * shipmag()) / magrange, radrange)
end

function in_states(states)
    local match = false
    for s in all(states) do
        if (in_state(s)) match = true
    end
    return match
end

function in_state(s)
    return sub(state, 1, #s) == s
end

function shipmag()
    return vecmag(ship.vel)
end

function ship_spr()
    local ang = get_ship_rot()
    return spr_8(ang, 8, 9, 10)
end

function flame_spr()
    local f = {}
    local ang = get_ship_rot()
    local s = spr_8(ang, 11, 12, 13)
    local facing = ship_facing(ang)
    local offsets = {
        makevec(-7, -1), -- upright
        makevec(-4, 2), -- up
        makevec(-1, -1), -- upleft
        makevec(2, -4), -- left
        makevec(-1, -7), -- downleft
        makevec(-4, -10), -- down
        makevec(-7, -7), -- downright
        makevec(-10, -4) -- right
    }

    f.sprite = s[1]
    f.flipx = s[2]
    f.flipy = s[3]
    f.offset = offsets[facing]

    if ship.flipflame then
        if (facing == 2 or facing == 6) f.flipx = not f.flipx
        if (facing == 4 or facing == 8) f.flipy = not f.flipy
    end

    return f
end

function boostvec()
    return polarvec(get_ship_rot(), 0.11)
end

function start_planet()
    return get_planets(level)[1]
end

function planet_dist(i)
    local planet = get_planets(level)[i]
    return dist(ship.pos, planet.pos) - planet.rad
end

function ship_facing(angle)
    local a = angle
    if (a >= 1/16 and a < 3/16) return 1 -- upright
    if (a >= 3/16 and a < 5/16) return 2 -- up
    if (a >= 5/16 and a < 7/16) return 3 -- upleft
    if (a >= 7/16 and a < 9/16) return 4 -- left
    if (a >= 9/16 and a < 11/16) return 5 -- downleft
    if (a >= 11/16 and a < 13/16) return 6 -- down
    if (a >= 13/16 and a < 15/16) return 7 -- downright
    if (a >= 15/16 or a < 1/16) return 8 -- right
end

function spr_8(angle, up, upright, right) -- return {sprite, flip x, flip y}
    local a, u, r, ur = angle, up, right, upright
    if (a >= 1/16 and a < 3/16) return {ur, false, false} -- up-right
    if (a >= 3/16 and a < 5/16) return {u, false, false} -- up
    if (a >= 5/16 and a < 7/16) return {ur, true, false} -- up-left
    if (a >= 7/16 and a < 9/16) return {r, true, false} -- left
    if (a >= 9/16 and a < 11/16) return {ur, true, true} -- down-left
    if (a >= 11/16 and a < 13/16) return {u, false, true} -- down
    if (a >= 13/16 and a < 15/16) return {ur, false, true} -- down-right
    if (a >= 15/16 or a < 1/16) return {r, false, false} -- right
end

-- screen

function hcenter(string)
    return 64 - #string*2
end

-- replace color c1 with c2 in rectangle of top-left x1, y1, and bottom-right x2, y2
function prep(x1, y1, x2, y2, c1, c2)
    for x = x1, x2 do
        for y = y1, y2 do
            if (pget(x, y) == c1) pset(x, y, c2)
        end
    end
end









__gfx__
00000000000000000000000000000000000000000000000000000000000000000005600000000556000000000000000000000000000000000000000007777440
00000000000900000009999000009000000000000000000000000000000000000055660000005566155000000000000000000000000000000000000077774444
0070070000999000000199900000990000500100000005000000000000500000005566000005566601555550000a000000000000000000000000000077074044
00077000099999000000999009999990000510000005500000010000000000000055660015556660005555550009a000000a000000099a000000000070700404
000770000119110000091190011199100005100000055000000050000000000005556660015666000066666600099000009aa0000099a0000000000000777400
007007000009000000910010000091000050010000100000000000000000010005556660000660000566666000009000009900000000000000000000000ee000
00000000000100000010000000001000000000000000000000000000000000000510056000056000566000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000100005000005000000000000000000000000000000000000000000000000000
00000000000000000000000000000000077774400000000007777440077774400777744000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000777744440777744077774444777744447777444400000000000000000000000000000000000000000000000000000000
09090900000cc0000000700000707700770740447777444477074044770740447707404400000000000000000000000000000000000000000000000000000000
9090900000cc6c000077770000777770707004047707404470700404707004047070040400000000000000000000000000000000000000000000000000000000
0909090000cccc000777777007777770007774007070040440777400007774000077740000000000000000000000000000000000000000000000000000000000
90909000000cc0000077070000777000444ee00044777400044ee000040ee000000ee00000000000000000000000000000000000000000000000000000000000
0000060000000000000000000000000004444000044ee00004444000004444000444440000000000000000000000000000000000000000000000000000000000
00000600000000000000000000000000040004000400040004000400004747000047470000000000000000000000000000000000000000000000000000000000
00001600000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00019610000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00145691000000666000000000000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00140191000006666600000000000044440088000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00014410000008888800000000000443344088000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00001100000688868226000000004444434488000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006688666226600000044344444448000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000066668667dd26666000443444434344000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000d688ddd226d00004444444444444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000d822d222d000044ffffffffffff440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000222220000004ffffffffffffff40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000006666d0000000ff00ffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000066d00000000ff00fffff444ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000006000000000ff00fffff444ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000006000000000fffffffff440ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000fffffffff444ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000010101010101000101000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
012800201855018055185611803224521245350c51624000240261a0001a53611000150461a0001c5371c0271f5141e6121d5321c61718057170770e1700e0700517700000000000000000000000000000000000
0101002002537045370553707537045370653707537095370653708537095370b537085370a5370b5370d1370e5001050011500135000e5001050011500135000e5001050011500135000e500105001150013500
011e000000045000000057500000000050000000075000000704500000075750000007145000001003610046000450000000575000000000500000000750000007045000000e575186150f125000001152110511
011e00001c1101f1111f1111f115181141812624616107131e546240001800024000000000000000000000001c1101f1111f1111f115181141812624616107130000000000000000000000000000000000000000
010c00200004000010000111200000050000100000000000000400001500000000000005000014000000000000040000150000000000000500001400000000000004000015000000000000050000140000000000
010c00000004000010000111200000050000150000000000000400001100000000000005000015000000000000040000110000000000000500001500000000000004000011000000000000050000150000000000
010c00000004000010000111200000050000150000000000020400201100000000000405004015000000000005040050110000000000050500501500000000000504005011000000000005050050150000000000
010c00000404004010040111200004050040150000000000040400401100000000000405004015000000000009040090110000000000090500901500000000000804008011000000000007050070150000000000
010f00000c0330c0000000000000246140c6000c6150c60010117000001c10000000246150000000000000000c0330000000000000002461500000000000000010117000001c1000000024615000000000000000
010f0000070100705000000000000c0500001010040000001d5121d5221d5121d5221f511135531f5001f50000000000000000000000000000000000000000000000000000000000000000000000000000000000
010d00000c0730c0000c03300000246250c6000c0430c6000c03300000180250000024515000000c033000000c0331d0000e5021b00024615000000c0230c0131c8141a8510d8510c800246150eb510f8510e851
010d00000c5350c000279000e9000e9300c900119001395110100000001c10000000246150000000000000000c033000000000000000246150000000000000000c000000001c1000000024615000000000000000
0110000010900119000c9000d9000f900129001a9001a9001d9001f9000d9000d9001c9001d9001e9002090020900239001690016900129000000000000000001a50011500130001a50000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 02040304
00 06060304
00 07020304
00 08094344
00 0a0b4344

