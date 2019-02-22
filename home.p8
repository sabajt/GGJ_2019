pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

-- inits

function _init()
    fps = 30
    debugclear()
    init_scene("space")
end

function init_scene(s)
    pal()
    scene = s
    if (scene == "space") init_space()
end

function init_space()
    set_state("space.pre")

    influence_multiplier = 8
    got_dog = false
    shake = 0
    pickup_time = 0
    shown_woof = false

    planets, minefields = new_planets_minefields()
    cam = new_cam()
    ship = new_ship(get_start_pos())
    stars = new_stars()
    homeclouds = new_clouds(start_planet().pos)
    dog = new_dog(planets[2]) --todo: hard coded to always be the second planet
    house = new_house(get_start_pos())
    hud = new_hud()
end

-- constructors

function new_planets_minefields()
    local p1 = centervec()
    local p2 = vec(27.3 * 128, -28.9 * 128)
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

    local planets = {
        new_planet( -- home
            p1, 
            250, 
            3, 
            new_moon(100, 1400, .25, 7), 
            {
                new_layer(1, 1.4, 0.6), -- far
                new_layer(13, 1.3, 0.45),
                new_layer(2, 1.2, 0.3),
                new_layer(12, 1.1, 0.15) -- near
            }
        ),
        new_planet( -- puppy 1
            p2, 
            p2rad, 
            4, 
            new_moon(75, 1000, .75, 7),
            {
                new_layer(6, 1.2, 0.45),
                new_layer(9, 1.15, 0.3),
                new_layer(14, 1.1, 0.15)
            }
        ),
        new_planet( 
            vec(-12 * 128, -3 * 128), 
            100, 
            5, 
            new_moon(75, 1000, .75, 7),
            {
                new_layer(1, 1.08, 0.2), 
                new_layer(5, 1.06, 0.15), 
                new_layer(6, 1.04, 0.1),
                new_layer(7, 1.02, 0.05) 
            }
        )
    }
    return planets, p2fields
end

function new_cam()
    return {
        pos = zerovec(),
        lerptime = 0,
        vel = zerovec(),
        acl = zerovec(),
        acl_scale = 0.5
    }
end

-- facing = 2, -- 1:upright -> ccwise -> 8:right
function new_ship(pos)
    return {
        pos = pos,
        launchpos = pos,
        rad = 2,
        rot = 0.25,
        rotvel = 0, 
        col = 3,
        vel = zerovec(),
        min_mag = 0.5,
        low_mag = 0.7,
        time = 0,
        boosttime = 0,
        ignited = false, -- todo: needed?
        sboost = 0,
        slowdown = false,
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
        rad = 4,
        sprite = 20
    }
end

function new_house(start_pos)
    pos_x = start_pos.x - 27
    pos_y = start_pos.y - 15
    return {
        pos = vec(pos_x, pos_y)
    }
end

function new_goal(x, y, rad)
    return {
        pos = vec(x, y),
        rad = rad
    }
end

function new_planet(pos, rad, col, moon, layers)
    return {
        pos = pos,
        rad = rad,
        col = col,
        moon = moon,
        layers = layers
    }
end

function new_layer(col, scale, depth, buoynum)
    local n = buoynum or 0
    local buoys = {}
    for i=1,n do
        local rad = lerp(10, 30, rnd(1))
        local amp = lerp(rad/5, rad/2, rnd(1)) 
        local per = lerp(2,5, rnd(1))
        local ang = rnd(1)
        local avel = lerp(0.2, 1.5, rnd(1))
        add(buoys, new_buoy(rad, amp, per, ang, avel))
    end

    return {
        col = col,
        scale = scale,
        depth = depth or 0.1,
        buoys = buoys
    }
end

function new_buoy(rad, amp, period, ang, angvel)
    return {
        t = 0,
        ang = ang,
        angvel = angvel/1000,
        rad = rad,
        amp = amp,
        period = period,
    }
end

function new_moon(rad, orbrad, orbang, col)
    return {
        rad = rad,
        col = col,
        orbang = orbang,
        orbrad = orbrad
    }
end

function new_mine_field(x, y, rad, count)
    local pos = vec(x, y)
    return {
        pos = pos,
        rad = rad,
        mines = new_mines(pos, rad, count)
    }
end

function new_hud()
    return {
        speed = 0,
        sd = 0
    }
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

function new_stars()
    local area = vec(128*15, 128*15)
    local tab = {}
    for s=4,7 do
        for i=1,330 do
            local p = vec(rnd(1) * area.x - area.x / 2, rnd(1) * area.y - area.y / 2)
            local d = 1
            if (s == 4) d = 0.6
            if (s == 5) d = 0.7
            if (s == 6) d = 0.8
            if (s == 7) d = 0.9
            add(tab, { sprite = s, org = p, depth = d})
        end
    end
    return tab
end

function new_clouds(center)
    local rad = 300
    local tab = {}
    for s=18,19 do
        for i=1,20 do
            local p = rnd_circ_vec(center, rad)
            local d = 1
            if (s == 18) d = 0.1
            if (s == 19) d = 0.2
            add(tab, { sprite = s, org = p, depth = d})
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

-- getters

function get_planet_foi(planet)
    return planet.rad * influence_multiplier
end

-- todo: start at any angle
function get_start_pos()
    local planet = start_planet()
    return addvec(planet.pos, vec(0, -planet.rad))
end

function get_moon_pos(planet)
    return perimeter_point(planet.pos, planet.moon.orbrad, planet.moon.orbang)
end

-- updates

function _update()
    if (scene == "space") update_space()
    update_time()
    update_last_downs()
end

function update_time()
    if (gtime == nil) gtime = {}
    if (gtime.frame == nil) gtime.frame = 0
    if (gtime.sec == nil) gtime.sec = 0
    if (gtime.min == nil) gtime.min = 0

    gtime.frame += 1

    if gtime.frame > fps then
        gtime.sec += 1
        gtime.frame = 0
    end

    if gtime.sec == 60 then
        gtime.min += 1
        gtime.sec = 0
    end
end

function update_hud()
    if ship.time % 8 == 0 then
        hud.speed = flr(shipmag() * 10) -- readable speed
        hud.sd = flr(neardist() * 0.25)
    end
end

function update_space()
    update_space_common()

    if in_state("space.pre") then
        update_space_pre()
    elseif state == "space.launch" or state == "space.catchup" or state == "space.fly" then
        update_space_fly()
    elseif state == "pickup" then
        update_pickup()
    end

    update_layers()
    update_moons()
    update_emitter(ship.emitter)
    update_hud()
    update_space_cam()
end

function update_layers()
    for p in all(planets) do
        for l in all(p.layers) do
            update_layer(l)
        end
    end
end

function update_layer(l)
    for b in all(l.buoys) do
        -- ang, rad, amp, period
        b.ang = wrap(b.ang + b.angvel, 0, 1, false)
        b.t = wrap(b.t + 1, 0, flr(b.period * fps), true)
    end
end

function update_moons()
    for p in all(planets) do
        update_moon(p)
    end
end

function update_moon(planet)
    planet.moon.orbang += 1/(30*30*5)
end

function update_space_pre()
    if btnd(5) then
        set_state("space.launch")
        ship.vel = zerovec()
    end
end

function update_space_fly()

    -- collide with nearest planet body?
    if ship.time > 1 and neardist() < 0 then
        stop_ship() 
        return
    end

    -- accumulate forces
    local acl = zerovec()

    for p in all(planets) do
        if circcollide(ship.pos.x, ship.pos.y, ship.rad, p.pos.x, p.pos.y, get_planet_foi(p)) then
            -- in planet grav field
            acl = addvec(acl, gravity(p, ship))
        end
    end

    -- mine collision
    local i = 1
    for f in all(minefields) do
        local d = dist(ship.pos, f.pos) - f.rad
        if d < 20 then
            for m in all(f.mines) do
                if m.hit == false then
                     if circcollide(ship.pos.x, ship.pos.y, ship.rad, m.pos.x + 8, m.pos.y + 8, m.rad) then
                        sfx(11, 2) -- todo: clear and put on channel 3?
                        m.hit = true
                        shake = 8
                    else
                        m.hit = false
                    end
                end
            end
        end
    end

    -- input
    local btl, btr, btu, btd, btz, btx = btn(0), btn(1), btn(2), btn(3), btn(4), btn(5)

    if btnd(5) then -- start super boost
        if xdtap > 0 then
            if ship.sboost < 15 then
                ship.sboost = 15
                sfx(-1, 3)
                sfx(10, 3)
            end
            set_state("space.catchup") -- triggers cam mode catchup
        end
        xdtap = 10
        ship.slowdown = false
    elseif ship.sboost > 0 then -- super boosting 
        -- todo: this will happen 1 frame after start super boost - good? add sleep effect?
        ship.emitter.active = false
        acl = addvec(acl, polarvec(ship.rot, 1))
        ship.sboost = max(ship.sboost - 1, 0)
    elseif btz then -- break
        ship.emitter.active = false
        ship.vel = scalevec(ship.vel, 0.8)
        if ship.slowdown == false then
            ship.slowdown = true
            sfx(-1, 3)
            sfx(13, 3)
        end
    elseif btx then -- throttle
        ship.slowdown = false
        if (ship.emitter.active == false) sfx(12, 3)
        ship.emitter.active = true
        acl = addvec(acl, polarvec(ship.rot, 0.115))
        if ship.boosttime == 0 then
            ship.showflame = true
            ship.flipflame = false
        end
        if (ship.boosttime % 2 == 0) ship.showflame = not ship.showflame
        if (ship.boosttime % 4 == 0) ship.flipflame = not ship.flipflame
        ship.boosttime += 1
    else
        sfx(-1, 3)
        ship.slowdown = false
        ship.emitter.active = false
        ship.boosttime = 0
        ship.showflame = false
    end

    if not btnd(5) then
        xdtap = xdtap or 0
        xdtap = max(xdtap - 1, 0)
    end

    -- rotate
    local rotacl, defvel =  1/700, 1/100
    if btl then
        if ship.rotvel <= 0 then 
            ship.rotvel = defvel
        else
            ship.rotvel += rotacl
        end
    elseif btr then
        if ship.rotvel >= 0 then 
            ship.rotvel = -defvel
        else
            ship.rotvel += -rotacl
        end
    else 
        ship.rotvel = ship.rotvel * 0.85
    end
    ship.rot = wrap(ship.rot + ship.rotvel, 0, 1, false)

    -- toggle huds
    -- if (btnd(4)) sdon = not sdon
    sdon = btd

    -- debuglog("### show full map ###")

    -- velocity, positions
    ship.vel = addvec(ship.vel, acl)
    ship.pos = addvec(ship.pos, ship.vel)
    ship.emitter.pos = ship.pos
    ship.emitter.ang = inv_angle(ship.rot)
    ship.time += 1
end

function update_pickup()
    if gtime.frame % 15 == 0 then
        shown_woof = true
        if dog.sprite == 20 then
            dog.sprite = 21
        elseif dog.sprite == 21 then
            dog.sprite = 22
        elseif dog.sprite == 22 then
            dog.sprite = 20
        end
    end

    pickup_time += 1
    if pickup_time > 30*5 then
        got_dog = true
        ship.rot = 0.25
        pickup_time = 0
        set_state("space.pre")
    end
end

-- updates (particles)

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

-- updates (cameras)

function update_space_cam()
    if state == "space.pre" then
        update_space_prelaunch_cam()
    elseif state == "space.launch" then
        update_space_launch_cam()
    elseif state == "space.catchup" then
        update_space_catchup_cam()
    elseif state == "space.fly" then
        update_space_fly_cam()
    end
end

function update_space_common()
    local low
    for p in all(planets) do
        local surfdist = dist(ship.pos, p.pos) - p.rad
        low = low or surfdist
        if surfdist <= low then
            -- remember closest planet
            low = surfdist
            nearplanet = p
        end
    end
end

function update_space_prelaunch_cam()
    local rel_target = perimeter_point(centervec(), 30, inv_angle(ship.rot))
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

function update_space_launch_cam()
    if dist(ship.pos, ship.launchpos) > 30 then
        cam.lerptime = 0
        set_state("space.catchup")
    end
end

function update_space_catchup_cam()
    local target = subvec(ship.pos, cam_rel_target())
    local seek =  subvec(target, cam.pos)
    local perc = cam.lerptime / 30

    if vecmag(seek) > 2 and perc < 1 then
        local move = scalevec(seek, perc)
        cam.pos = addvec(cam.pos, move)
    else
        cam.pos = target
        set_state("space.fly")
    end

    cam.lerptime += 1
end

function update_space_fly_cam()
    cam.pos = subvec(ship.pos, cam_rel_target())
    if shake > 0 then
        cam.pos = rnd_circ_vec(cam.pos, 4)
        shake -= 1
    end
end

-- draws

function _draw()
    cls()
    camera(cam.pos.x, cam.pos.y)
    if (scene == "space") draw_space()
    draw_hud()
    draw_border()
    draw_debug()
end

function fizz(center, rad, ang1, ang2, colfar, colnear, reps, spread)
    for i = 1, reps do
        local pos = lerpcirc(center, rad, ang1, ang2, i/reps)
        pos = rnd_circ_vec(pos, spread)
        local col = (dist(center, pos) > rad) and colfar or colnear 
        local size = rnd(1) > 0.5 and 1 or 0.5
        circ(pos.x, pos.y, size, col)
        add(fizzcache, {p = pos, s = size, c = col})
    end
end

function fizzmem()
    if fizzcache != nil then
        for i in all(fizzcache) do
            circ(i.p.x, i.p.y, i.s, i.c)
        end
    end
end

function lerpcirc(center, rad, ang1, ang2, t)
    local a = lerp(ang1, ang2, t)
    -- return addvec(center, polarvec(a, rad)) 
    return perimeter_point(center, rad, a)
end

function draw_debug()
    local xorg = cam.pos.x + 34
    local yorg = cam.pos.y + 2
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
    local hud_bottom = cam.pos.y + 8
    local map_bottom = cam.pos.y + 32
    local map_side = cam.pos.x + 32

    local leftmargin = cam.pos.x + 8
    local topmargin = cam.pos.y + 2
    -- local rightmargin = cam.pos.x + 125

    if in_states({"space.fly", "space.catchup", "space.launch"}) then
        draw_hud_dist()
    end

    if sdon then
        local tip = perimeter_point(ship.pos, 22, nearplanetang())
        print(hud.sd, tip.x, tip.y, 7)
    end 
    draw_facing()

    -- line(cam.pos.x, hud_bottom, cam.pos.x + 127, hud_bottom, 7) -- hud divider
    line(cam.pos.x, map_bottom, map_side, map_bottom, 7)--minimap bottom
    line(map_side, map_bottom, map_side, cam.pos.y, 7)--minimap side

    draw_mini_map()
end

function draw_facing()
    local fades = { -- direction hud blink pallets keyed by background color
        [12] = expand({8,2,13,12,13,2}, 3), -- sky blue
        def = expand({11,3,13,1,0,1,13,3}, 3) -- black
    }
    local t = gtime.frame / 30
    t = t > 0 and t or 0.0001 -- guard against 0 index (ceil ensure 1)
    local p = perimeter_point(ship.pos, 16, ship.rot)
    local halfsize = vec(5, 5)
    local bgcol = colsamp(subvec(p, halfsize), addvec(p, halfsize)) 
    local ctab = fades[bgcol]
    if (ctab == nil) ctab = fades.def
    local c = ctab[ceil(t * #ctab)]
    circ(p.x, p.y, 1, c)
end

function draw_mini_map()
    local startpos = get_start_pos()
    local map_corner = addvec(vec(-3000, -5000), startpos)
    local scale_ship = subvec(scalevec(subvec(ship.pos, map_corner), .004), vec(0, start_planet().rad * .004))
    local m_ship = addvec(scale_ship, flrvec(cam.pos))

    local scaled_planet_vecs = {}
    local scaled_moon_vecs = {}

    for p in all(planets) do
    local p_scaled = scalevec(subvec(p.pos, map_corner), .004)
        local p_add_cam = addvec(p_scaled, flrvec(cam.pos))
        add(scaled_planet_vecs, p_add_cam)
        if (p.moon) then
            local moon_vec_scaled = scalevec(subvec(get_moon_pos(p), map_corner), .004)
            local m_add_cam = addvec(moon_vec_scaled, flrvec(cam.pos))
            add(scaled_moon_vecs, m_add_cam)
        end
    end

    local pc = 4
    local i = 1
    for p in all(scaled_planet_vecs) do
        local r = 3
        if (i == 2) r = 2
        circfill(p.x, p.y, r , pc)
        pc += 7
        i+=1
    end

    for m in all(scaled_moon_vecs) do
        circfill(m.x, m.y, 1, 6)
    end

    circ(m_ship.x, m_ship.y, 1 , 8)
end

function draw_hud_dist()
    local i = 1
    for p in all(planets) do
        local dir = dirvec(p.pos, ship.pos)
        local ang = angle(dir)
        local contact = perimeter_point(p.pos, p.rad, inv_angle(ang))

        if visible(contact) then -- display ship-planet contact shadow
            if planet_dist(i) > 8 then
                circfill(contact.x, contact.y, 2, 3)
            end
        else -- guide line to planets
            -- if gtime != nil then
            --     if gtime.frame % 20 == 0 or gtime.frame % 22 == 0 then 
            --         line(contact.x, contact.y, ship.pos.x, ship.pos.y, p.col)
            --     end
            -- end
        end
        i += 1
    end
end

function draw_plax_sprites(tab)
    for s in all(tab) do
        local pos = plaxrel(s.org, s.depth)
        spr(s.sprite, pos.x, pos.y)
    end
end

-- function draw_test_plax()
--     local p = vec(700, 0)
--     local a = addvec(subvec(plaxrel(p, 0.1), scalevec(p, 0.1)), scalevec(vec(64, 64), 0.1))
--     local b = addvec(subvec(plaxrel(p, 0.15), scalevec(p, 0.15)), scalevec(vec(64, 64), 0.15))
--     local c = addvec(subvec(plaxrel(p, 0.2), scalevec(p, 0.2)), scalevec(vec(64, 64), 0.2))

--     circfill(a.x, a.y, 30, 11)
--     circfill(b.x, b.y, 30, 10)
--     circfill(c.x, c.y, 30, 14)

--     circ(p.x, p.y, 3, 7)
-- end

-- parralax fizzy circles
function draw_fizzy_circles(tab)
    local i = 1
    local fizzrate = 20 -- higher slower
    if (gtime.frame % fizzrate == 0) fizzcache = {}
    for c in all(tab) do 
        local pos = addvec(c.org_pos, scalevec(flrvec(cam.pos), c.depth))
        circfill(pos.x, pos.y, c.rad, c.col)
        a, b = range_visible(pos, c.rad)
        if a != nil and b != nil then
            if gtime.frame % fizzrate == 0 then
                local j = i-1
                local colnear
                if j > 0 then
                    local prev = tab[j]
                    colnear = prev.col
                else
                    colnear = 0
                end
                -- (center, rad, ang1, ang2, colfar, colnear, reps, spread)
                fizz(pos, c.rad, a, b, c.col, colnear, 15, 2)
            else
                fizzmem()
            end
        end
        i += 1
    end
end

function draw_layers(planet)
    for l in all(planet.layers) do
        local p = plax(planet.pos, l.depth)
        circfill(p.x, p.y, planet.rad * l.scale, l.col)
        draw_buoys(planet, l)
    end
end

function draw_buoys(planet, layer)
    local p, l = planet, layer
    for b in all(l.buoys) do
        local t = b.t / (b.period * fps)
        local offset = sin(t) * b.amp
        local pos = perimeter_point(p.pos, p.rad * l.scale + offset, b.ang)
        circfill(pos.x, pos.y, b.rad, l.col)
    end
end

function draw_space()
    draw_plax_sprites(stars)

    local pi = 1
    for p in all(planets) do

        draw_layers(p)

        -- home
        if pi == 1 then
            -- draw_fizzy_circles(planet_layers(p))
            draw_plax_sprites(homeclouds)
        end

        --planet
        circfill(p.pos.x, p.pos.y, p.rad, p.col)
        circ(p.pos.x, p.pos.y, get_planet_foi(p), p.col)

        --moon
        if (p.moon != nil) then
            local mpos = get_moon_pos(p)
            circfill(mpos.x, mpos.y, p.moon.rad, p.moon.col)
        end

        pi += 1
    end

    -- draw_test_plax()

    --mines
    for f in all(minefields) do
        for m in all(f.mines) do
            spr(33, m.pos.x, m.pos.y, 2, 2)
            if (m.hit) circfill(m.pos.x + 8, m.pos.y + 8, m.rad, 10)
        end
    end

    -- particles
    draw_particles()

    --dog
    if (got_dog == false) spr(dog.sprite, dog.pos.x, dog.pos.y)

    if shown_woof and state == "pickup" then
        print("woof! bork! arf!", dog.pos.x, dog.pos.y - 15)
    end

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
    printh("", "laika", true)
end

function debuglog(s)
    printh(format_gtime() .. s, "laika")
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

function boolstring(b) 
    return b and "true" or "false"
end

function nilstring(s)
    return s != nil and s or "nil"
end

-- vectors

function vec(xval, yval)
    return {x=xval, y=yval}
end

function zerovec()
    return vec(0, 0)
end

function centervec()
    return vec(64, 64)
end

function addvec(v1, v2)
    return vec(v1.x + v2.x, v1.y + v2.y)
end

function subvec(v1, v2)
    return vec(v1.x - v2.x, v1.y - v2.y)
end

function scalevec(v1, s)
    return vec(v1.x * s, v1.y * s)
end

function norvec(v)
    return scalevec(v, 1 / vecmag(v))
end

function livec(v, max)
    return (vecmag(v) > max) and scalevec(norvec(v), max) or v
end

function flrvec(v)
    return vec(flr(v.x), flr(v.y))
end

function ceilvec(v)
    return vec(ceil(v.x), ceil(v.y))
end

function dirvec(to, from)
    return norvec(subvec(to, from))
end

function dirvec_snap(dir)
    local d = zerovec()
    -- todo: is the dirvec invocation pointless? (1, 0) unit vec?
    if (dir == "left") d = dirvec(vec(-1, 0), zerovec())
    if (dir == "right") d = dirvec(vec(1, 0), zerovec())
    if (dir == "up") d = dirvec(vec(0, -1), zerovec())
    if (dir == "down") d = dirvec(vec(0, 1), zerovec())
    return d
end

function dist(v1, v2)
    return vecmag(subvec(v1, v2))
end

function polarvec(ang, mag)
    return scalevec(vec(cos(ang), sin(ang)), mag)
end

function angle(v)
    return atan2(v.x, v.y)
end

function vecmag(v)
    -- scale to avoid overflow: 182^2
    local m = max(abs(v.x), abs(v.y))
    local x = v.x / m
    local y = v.y / m
    return sqrt(x*x + y*y) * m
end

function dot(a, b) -- overflow warning: 182^2
    return a.x * b.x + a.y * b.y
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

-- vectors (physics)

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
    local distance = vec(abs(c1x-c2x), abs(c1y-c2y))
    local mag = vecmag(distance)
    return mag <= (r1 + r2)
    -- todo: same as?... dist(vec(c1x, c1y), vec(c2x, c2y)) <= (r1 + r2)
    -- because dist == vecmag(subvec(v1, v2))
end

-- adapted from "graphics gems: v2 intersection of a circle and a line"
function circ_x_line(circ, u, v)
    -- scale down to avoid overflow: 182^2 
    local scale = min(100, max(max(max(max(max(circ.pos.x, circ.pos.y), circ.rad), u.x), u.v), v.x), v.y)
    local circ = {
        pos = scalevec(circ.pos, 1/scale), 
        rad = circ.rad/scale
    }
    local u = scalevec(u, 1/scale)
    local v = scalevec(v, 1/scale) 
    --

    local du = dirvec(v, u)
    local g = subvec(u, circ.pos)
    local a = dot(du, du)
    local b = 2 * dot(du, g)
    local c = dot(g, g) - circ.rad * circ.rad
    local d = b * b - 4 * a * c

    if d < 0 then
        return nil
    else
        local s1 = (-b + sqrt(d)) / (2 * a)
        local s2 = (-b - sqrt(d)) / (2 * a)
        local p1 = addvec(scalevec(du, s1), u)
        local p2 = addvec(scalevec(du, s2), u)

        -- scale up
        p1 = scalevec(p1, scale)
        p2 = scalevec(p2, scale)
        --
        return p1, p2
    end
end

function circ_x_lineseg(circ, u, v) -- broken
    local p1, p2 = circ_x_line(circ, u, v)
    local xmax = max(u.x, v.x)
    local xmin = min(u.x, v.x)
    local ymax = max(u.y, v.y)
    local ymin = min(u.y, v.y)

    -- todo: fix the floating pt error where a value like 1.9999 (displayed as 2) < 2 so intersection test fails
    if p1.x > xmax or p1.x < xmin or p1.y > ymax or p1.y < ymin then
        p1 = nil
    end
    if p2.x > xmax or p2.x < xmin or p2.y > ymax or p2.y < ymin then
        p2 = nil
    end
    return p1, p2

    --[[ debug in init:

    local circ = {pos=vec(2,2),rad=2}
    local u = vec(-2,2)
    local v = vec(5,2)
    local p1, p2 = circ_x_lineseg(circ, u, v)
    debuglog("-- circ x lineseg --")
    if p1 != nil then
        debuglog("p1 = " .. vecstring(p1))
    else
        debuglog("p1 is nil")
    end
    if p2 != nil then
        debuglog("p2 = " .. vecstring(p2))
    else
        debuglog("p2 is nil")
    end

    --]]
end

function line_intersect(v1, v2, w1, w2) 
    -- todo: scale down
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

-- other

function rndtab(tab)
    return tab[ceil(rnd(1)*#tab)]
end

function lerp(a, b, t)
    return a + (t * (b - a))
end

function smooth(a, b, t)
    local x = clamp((t - a) / (b - a), 0, 1); 
    return x * x * (3 - 2 * x);
end

function lerpvec(a, b, p)
    return vec(lerp(a.x, b.x, p), lerp(a.y, b.y, p))
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
	return max(low, min(n, high))
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
    local p = vec(r * cos(a), r * sin(a))
    return addvec(center, p)
end

-- modified from https://www.lexaloffle.com/bbs/?tid=28077
function trifill(p1, p2, p3, col)
    local x1 = band(p1.x, 0xffff)
	local x2 = band(p2.x, 0xffff)
	local y1 = band(p1.y, 0xffff)
    local y2 = band(p2.y, 0xffff)
    local x3 = band(p3.x, 0xffff)
    local y3 = band(p3.y, 0xffff)
    local nsx, nex, min_x, min_y, max_x, max_y
    
    -- sort
    if y1 > y2 then
        y1, y2 = y2, y1
        x1, x2 = x2, x1
    end 
    if y1 > y3 then
        y1, y3 = y3, y1
        x1, x3 = x3, x1
    end
    if y2 > y3 then
        y2, y3 = y3, y2
        x2, x3 = x3, x2		  
    end

    if y1 != y2 then 		 
        local sx = (x3 - x1) / (y3 - y1)
        local ex = (x2 - x1) / (y2 - y1)
        nsx = x1
        nex = x1
        min_y = y1
        max_y = y2

        for y = min_y, max_y - 1 do
            rectfill(nsx, y, nex, y, col)
            nsx += sx
            nex += ex
        end
    else --where top edge is horizontal
        nsx = x1
        nex = x2
    end
    
    if y3 != y2 then
        local sx = (x3-x1) / (y3-y1)
        local ex = (x3-x2) / (y3-y2)
        min_y = y2
        max_y = y3
    
        for y = min_y, max_y do
            rectfill(nsx, y, nex, y, col)
            nex += ex
            nsx += sx
        end
    else --where bottom edge is horizontal
        rectfill(nsx, y3, nex, y3, col)
    end
end

-- return dominant color in rectange: top left, bottom right. o(2)
function colsamp(tl, br)
    local tab = {}
    for x = tl.x,br.x do
        for y = tl.y,br.y do
            local col = pget(x,y)
            local count = tab[col]
            if count == nil then 
                tab[col] = 1
            else
                tab[col] = count + 1
            end
        end
    end
    local hcount, hcol = 0, 0
    for col, count in pairs(tab) do
        if count > hcount then
            hcount = count
            hcol = col
        end
    end
    return hcol
end

-- return a table where each element is repeated n times
function expand(tab, n) 
    local extab = {}
    for element in all(tab) do
        for _=1,3 do
            add(extab, element)
        end
    end
    return extab
end

-- button extensions

last_downs = {false,false,false,false,false,false}

function update_last_downs() -- call at end of update cycle
    for i=0,5 do
        last_downs[i] = btn(i)
    end
end

function btnd(b) 
    return (btn(b) and (last_downs[b] == false))
end

-- game helpers

function set_state(s)
    state = s
    debuglog("")
    debuglog("state: " .. s)
    debuglog("")
end

function visible(p)
    local in_x_view = p.x >= cam.pos.x and p.x <= cam.pos.x+128
    local in_y_view = p.y >= cam.pos.y and p.y <= cam.pos.y+128
    return in_x_view and in_y_view
end

function plaxrel(org, depth) -- parallax relative to 0,0, depth 0..1 (close..far) 
    return addvec(org, scalevec(flrvec(cam.pos), depth))
end

function plax(org, depth) -- parallax w/ absolute positioning, depth 0..1 (close..far) 
    local a = plaxrel(org, depth)
    local b = subvec(a, scalevec(org, depth))
    return addvec(b, scalevec(centervec(), depth))
end

function neardist() -- not flr for game logic. use flr for rendering 
    return dist(ship.pos, nearplanet.pos) - nearplanet.rad
end

function nearplanetang() 
    return angle(dirvec(nearplanet.pos, ship.pos)) 
end

function stop_ship()
    sfx(-2, 3)
    ship.vel = zerovec()
    ship.pwr = 0
    ship.time = 0
    ship.emitter.active = false
    ship.ignited = false -- todo: needed?
    ship.rotvel = 0
    ship.slowdown = false

    local dir = dirvec(ship.pos, nearplanet.pos)
    local ang = angle(dir)
    ship.rot = ang
    -- don't use perimeter point, we need unfloored to avoid < 0 surf dist
    ship.pos = addvec(nearplanet.pos, polarvec(ang, nearplanet.rad)) 
    ship.launchpos = ship.pos

    if circcollide(ship.pos.x, ship.pos.y, 15, dog.pos.x, dog.pos.y, 10) then
        set_state("pickup")
    else
        set_state("space.pre")
    end
end

function range_visible(center, rad)
    local campoints = {
        cam.pos, 
        addvec(cam.pos, vec(128, 0)),
        addvec(cam.pos, vec(128, 128)),
        addvec(cam.pos, vec(0, 128))
    }
    local minang, maxang = 1, 0
    local vis = false 
    for p in all(campoints) do
        local d = dirvec(p, center)
        local a = angle(d)
        local q = perimeter_point(center, rad, a)
        minang = min(a, minang)
        maxang = max(a, maxang)
        if (visible(q)) vis = true
    end
    if (vis) return minang, maxang
    return nil, nil
end

function cam_rel_target()
    return perimeter_point(centervec(), cam_radius(), inv_angle(angle(ship.vel)))
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
    return spr_8(ship.rot, 8, 9, 10)
end

function flame_spr()
    local f = {}
    local ang = ship.rot
    local s = spr_8(ang, 11, 12, 13)
    local face = facing(ang)
    local offsets = {
        vec(-7, -1), -- upright
        vec(-4, 2), -- up
        vec(-1, -1), -- upleft
        vec(2, -4), -- left
        vec(-1, -7), -- downleft
        vec(-4, -10), -- down
        vec(-7, -7), -- downright
        vec(-10, -4) -- right
    }

    f.sprite = s[1]
    f.flipx = s[2]
    f.flipy = s[3]
    f.offset = offsets[face]

    if ship.flipflame then
        if (face == 2 or face == 6) f.flipx = not f.flipx
        if (face == 4 or face == 8) f.flipy = not f.flipy
    end

    return f
end

function boostvec()
    return polarvec(ship.rot, 0.115)
end

function start_planet()
    return planets[1]
end

function planet_dist(i)
    local planet = planets[i]
    return dist(ship.pos, planet.pos) - planet.rad
end

function facing(angle)
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
00000000000000000000000000000000000000000000000000000000000000000005600000000556000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000055660000005566155000000000000000000000000000000000000000000000
0070070000000000000000000000000000500100000005000000000000500000005566000005566601555550000a000000000000000000000000000000000000
00077000000000000000000000000000000510000005500000010000000000000055660015556660005555550009a000000a000000099a000000000000000000
000770000000000000000000000000000005100000055000000050000000000005556660015666000066666600099000009aa0000099a0000000000000000000
00700700000000000000000000000000005001000010000000000000000001000555666000066000056666600000900000990000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000510056000056000566000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000100005000005000000000000000000000000000000000000000000000000000
00000000000000000000000000000000077774400000000007777440077774400777744000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000777744440777744077774444777744447777444400000000000000000000000000000000000000000000000000000000
00000000000000000000700000707700770740447777444477074044770740447707404400000000000000000000000000000000000000000000000000000000
00000000000000000077770000777770707004047707404470700404707004047070040400000000000000000000000000000000000000000000000000000000
00000000000000000777777007777770007774007070040440777400007774000077740000000000000000000000000000000000000000000000000000000000
00000000000000000077070000777000444ee00044777400044ee000040ee000000ee00000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000004444000044ee00004444000004444000444440000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000040004000400040004000400004747000047470000000000000000000000000000000000000000000000000000000000
00000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000060000000000000000000000000ee00ee000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000066600000000000000440000000eeeeeeee00000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000666660000000000004444008800eeeeeeee00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000008888800000000000443344088000eeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000006888682260000000044444344880000eeee0000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000668866622660000004434444444800000ee00000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000066668667dd26666000443444434344000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000d688ddd226d00004444444444444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000d822d222d000044ffffffffffff440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000222220000004ffffffffffffff40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000006666d0000000ff00ffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000066d00000000ff00fffff444ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000006000000000ff00fffff444ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000006000000000fffffffff440ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000fffffffff444ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
7ccccccccccccccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccbbbccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccbbbbbcccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccbbbbbcccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccbbbbbcccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccbbbccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccccc6ccccc7ccc7c77ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccc666cccc7ccc77777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccccc6ccccc7cc777777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccc6cccccccccccccccccccc7ccc777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccc666ccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccc6cccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccc484ccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccc48484cccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccc4448444ccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccc4444444ccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccc4444444ccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccc44444cccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccc444ccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7c7c77cccccccccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7c77777ccccccccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7777777ccccccccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7c777ccccccccccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
777777777777777777777777777777777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccccccccccccccccccccccc44ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccccc4444cc88cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccccccccccccccccccccc443344c88cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccccc4444434488cccccccc7ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccccccccccccccccccc44344444448cccccc7777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccc443444434344ccccc777777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7ccccccccccccccccccccccccccccccccccccc44444444444444ccccc77c7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccc44ffffffffffff44cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccc4ffffffffffffff4cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccffccffffffffffccccccccccc56cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccffccfffff444ffcccccccccc5566ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccffccfffff444ffcccccccccc5566ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccfffffffff44cffcccccccccc5566ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccccfffffffff444ff4444444445556664444444444444ccccccccccccccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccccccccccc4444444444444444444444445556664444444444444444444444444ccccccccccccccccccccccccccccccccccc7
7cccccccccccccccccccccccccccc44444444444444444444444444444444514456444444444444444444444444444444444ccccccccccccccccccccccccccc7
7cccccccccccccccccccccc44444444444444444444444444444444444444144445444444444444444444444444444444444444444ccccccccccccccccccccc7
7cccccccccccccccc44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444ccccccccccccccc7
7ccccccccccc444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444cccccccccc7
7ccccccc44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444cccccc7
7ccc4444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444cc7
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
74444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777

__gff__
0000000000000000000000000000000000010101010101000100000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200003c51037520010203352001020160202f520020402c550020500705014050265100805015050225100202008030020401a54001050130500105016550010501005001040090400c530130200851001000
000200003a6730827002670036600426008550046500724006640062400a6400b640075300d630052300f62009520126200922013620062201362009520116201062008230052300a5300b6300a6400524008640
010200200061000611007240072500610006110072400725006100061100724007250061000611007240072500610006110072400725006100061100724007250061000611007240072500610006110072400725
0002000004610096101a6101462012620106200e6200b6200b620086100d6100561008610026100d6100161008610016100b61001610056100161009610016100461001610046100161002610016100261001610
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000

