pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- laika
-- by jsaba, nolan

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
    dietime = 0
    diedur = 2*fps

    gtime = new_gtime()
    planets = new_planets()
    minefields = new_minefields()
    grassbatches = new_grassbatches()
    cam = new_cam()
    ship = new_ship(get_start_pos())
    stars = new_stars()
    dog = new_dog(planets[2]) --todo: hard coded to always be the second planet
    house = new_house(get_start_pos())
    hud = new_hud()
    emitters = new_emitters()
end

-- constructors

function new_gtime()
    return {
        frame = 1, 
        sec = 0,
        min = 0
    }
end

function new_planets()
    return {
        new_planet( -- home
            centervec(), -- pos 
            250, -- rad
            3, -- col
            new_moon(100, 1400, .25, 7)
        ),
        new_planet( -- puppy 1, mines
            vec(27.3 * 128, -28.9 * 128), 
            150, 
            5, 
            new_moon(75, 1000, .75, 7)
        ),
        new_planet( 
            vec(-12 * 128, -3 * 128), 
            100, 
            4, 
            new_moon(75, 1000, .75, 7)
        )
    }
end

function new_minefields()
    local p1,p2 = planets[1],planets[2]
    local fields = {}
    local count = 20

    for i=1,count do
        local a = i/count
        local p = perimeter_point(p2.pos, p2.rad, a)
        p = addvec(p, polarvec(a, 350))
        local f = new_mine_field(p, 260, 18) 
        add(fields, f)
    end

    -- testing
    local p = addvec(p1.pos, polarvec(0.25, p1.rad + 102))
    add(fields, new_mine_field(p, 50, 10))

    return fields
end

function new_grassbatches()
    local batches, planet, batchcount, batchrad, grasscount = {}, planets[1], 25, 30, 15
    for i = 1, batchcount do
        local ang = i / batchcount
        local pos = perimeter_point(planet.pos, planet.rad - batchrad, ang)
        local items = {}
        for i = 1, grasscount do
            add(items, { 
                pos = rnd_circ_vec(pos, batchrad), 
                col = rndtab({3, 12}) 
            })
        end
        local batch = {pos = pos, rad = batchrad, visible = false, items = items}
        add(batches, batch)
    end
    return batches
end

function new_cam()
    return {
        pos = zerovec(),
        vel = zerovec(),
        lerptime = 0,
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
        slowdown = false
    }
end

function new_emitters()
    return {
        throttle = new_emitter(
            0.08, -- emit rate
            zerovec(), -- emit position (bound to ship)
            0, -- emit angle
            0.2, -- emit angle plus or minus variation
            1.5, -- particle life (seconds)
            0.5, -- particle start radius
            3, -- particle end radius
            0.5, -- particle start magnitude
            0, -- particle end magnitude
            0, -- particle plus/minus mag
            40, -- max number of particles
            {{7, 12, 13, 1}}, -- particle color progression
            1, -- num particle per draw emit (reps)
            0.5, -- % of time particles drawn as filled circles (0% would be all empty circles)
            acl_throttle
        ),
        speedtrail = new_emitter(
            1/30, -- rate
            zerovec(), -- pos
            0, -- ang
            0.2, -- plus / min
            1, -- life
            0.5, -- start rad
            0.5, -- end rad
            0, -- start mag
            0, -- end mag
            0, -- pm mag
            30, -- max num
            {{11,3,1},{12,1},{7,6,1},{10,9,1}},
            1,
            1, -- % filled
            acl_speedtrail
        ),
        shipdie = new_emitter(
            1/30, -- rate
            zerovec(), -- pos
            0, -- ang
            0.99, -- plus / min
            0.7, -- life
            0.5, -- start rad
            1, -- end rad 
            4, -- start mag
            1, -- end mag
            0.5, -- pm mag
            80, -- max num
            {{12,12,8,1,1},{12,12,6,1,1},{12,12,12,8,1}}, -- colors
            2, -- reps
            0 -- % filled
        ),
        fireball = new_emitter(
            1/10, -- rate
            zerovec(), -- pos
            0, -- ang
            0.99, -- plus / min
            1, -- life
            0.5, -- start rad
            4, -- end rad 
            1, -- start mag
            0, -- end mag
            0.5, -- pm mag
            15, -- max num
            {{8,9,2,8,2},{9,8,9,8,1},{8,2,8,8,2}}, -- colors
            2, -- reps
            1, -- % filled
            nil, -- no acl fx
            {
                0b0111101101111111.1,
                0b0010101011111110.1,
                0b0100110101101100.1,
                0b1001111111111010.1,
                0b1010111000111101.1,
                0b1110110011110110.1,
                0b1111110111011111.1
            }, -- pats
            4
        ),
        planetglow = new_emitter(
            5/30, -- rate
            zerovec(), -- pos
            0, -- ang
            0, -- ang plus / min
            5, -- life
            0.5, -- start rad
            0.5, -- end rad 
            0.3, -- start mag
            0.3, -- end mag
            0.1, -- pm mag
            90, -- max num
            {{10, 2}, {12, 13}}, -- colors
            1, -- reps
            1 -- % filled
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

function new_planet(pos, rad, col, moon)
    return {
        pos = pos,
        rad = rad,
        col = col,
        moon = moon,
        contact = nil -- projected point of ship contact, updated per frame
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

function new_mine_field(pos, rad, count)
    return {
        pos = pos,
        rad = rad,
        items = new_mines(pos, rad, count),
        visible = false
    }
end

function new_hud()
    return {
        speed = 0,
        sd = 0
    }
end

function new_emitter(rate, pos, ang, ang_pm, life, start_rad, end_rad, start_mag, end_mag, pm_mag, max, ctabs, reps, fillperc, addacl, pats, patrate)
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
        pm_mag = pm_mag,
        max = max,
        ctabs = ctabs,
        particles = {},
        active = false,
        reps = reps,
        fillperc = fillperc,
        addacl = addacl,
        pats = pats,
        patrate = patrate
    }
end

function new_particle(pos, ang, life, start_rad, end_rad, start_mag, end_mag, fill, ctab)
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
        ctab = ctab,
        col = ctab[1],
        fill = fill
    }
end

function new_stars()
    local span = 128 * 10
    local tab = {}
    for i=1,400 do
        local p = vec(rnd(1) * span - span / 2, rnd(1) * span - span / 2)
        add(tab, { sprite = s, org = p, depth = 0.95 })
    end
    return tab
end

function new_mines(center, rad, count)
    local mines = {}
    for i=1,count do
        local pos = rnd_circ_vec(center, rad)
        add(mines, {sprite = 18, pos = pos, rad = 7, hit = 0 })
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
    gtime.frame += 1

    if gtime.frame > fps then
        gtime.sec += 1
        gtime.frame = 1
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
    update_planets()

    if in_state("space.pre") then
        update_space_pre()
    elseif in_states({"space.launch", "space.catchup", "space.fly", "space.sboost"}) then
        update_space_fly()
    elseif state == "pickup" then
        update_pickup()
    elseif in_state("space.die") then
        update_space_die(state == "space.die.mine")
    end

    update_batches(grassbatches, nil, 0, addvec(cam.pos, centervec()), 91)
    update_mines()
    update_moons()
    update_emitters()
    update_hud()
    update_space_cam()
end

function update_planets()
    local low
    for p in all(planets) do
        -- set closest planet
        local surfdist = surfdist_toship(p)
        low = low or surfdist
        if surfdist <= low then
            low = surfdist
            nearplanet = p
        end
        -- set contact point 
        if p == nearplanet then
            local dir = dirvec(ship.pos, p.pos) 
            local ang = angle(dir)
            p.contact = perimeter_point(p.pos, p.rad, ang) 

            local eang = ang + rndpm() * rnd(0.15)
            emitters.planetglow.pos = perimeter_point(p.pos, p.rad, eang) 
            emitters.planetglow.ang = eang
            emitters.planetglow.active = true
            -- todo: only set active when in range, or if always active just once on startup
        end
    end
end

function update_emitters()
    for _,e in pairs(emitters) do
        update_emitter(e)
    end
end

function update_moons()
    for p in all(planets) do
        p.moon.orbang += 1/(30*30*5)
    end
end

function update_space_pre()
    if btnd(5) then
        set_state("space.launch")
        ship.vel = zerovec()
    end
end

function update_space_die(bymine)
    dietime = max(0, dietime - 1)
    local t = 1 - dietime / diedur
    local target = subvec(ship.pos, centervec())
    cam.pos = lerpvec(cam.pos, target, t)
    if dietime < diedur * 0.8 then
        emitters.shipdie.active = false
        emitters.fireball.active = false
    end
    if dietime == 0 then
        ship = new_ship(get_start_pos())
        set_state("space.pre")
    end
end

function update_batches(batches, work, workthresh, focus, visthresh)
    for b in all(batches) do
        local d = dist(focus, b.pos) - b.rad
        b.visible = d < visthresh
        if (work and d < workthresh) work(b.items)
    end
end

function update_mines()
    local function update(mines) 
        for m in all(mines) do
            m.hit = max(0, m.hit - 1)
            if m.hit <= 0 then 
                if circcollide(ship.pos.x, ship.pos.y, ship.rad, m.pos.x + 8, m.pos.y + 8, m.rad) then
                    sfx(-1, 3)
                    sfx(11, 3) 
                    m.hit = 10
                    shake = 10
                    -- todo: if not shield...
                    set_state("space.die.mine")
                    dietime = diedur
                    emitters.shipdie.pos = ship.pos
                    emitters.shipdie.active = true
                    emitters.fireball.active = true
                    emitters.fireball.pos = ship.pos
                    emitters.throttle.active = false
                    emitters.speedtrail.active = false
                    ship.showflame = false
                    sdon = false
                else
                    m.hit = 0
                end
            elseif m.hit == 1 then
                debuglog("delete mine at pos = " .. vecstring(m.pos))
                del(mines, m)
            end
        end
    end
    update_batches(minefields, update, 1, addvec(cam.pos, centervec()), 91) 
end

function update_space_fly()

    -- collide with nearest planet body?
    if ship.time > 1 and neardist() < 0 then
        if hud.speed > 10 then -- crash
            sfx(-1, 3)
            sfx(11, 3) 
            shake = 10
            set_state("space.die.crash")
            dietime = diedur
            emitters.shipdie.pos = ship.pos
            emitters.shipdie.active = true
            emitters.throttle.active = false
            emitters.speedtrail.active = false
            ship.showflame = false
            sdon = false
        else -- land
            stop_ship() 
        end
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

    -- input
    local btl, btr, btu, btd, btz, btx = btn(0), btn(1), btn(2), btn(3), btn(4), btn(5)

    if btnd(5) then -- start super boost
        if xdtap > 0 then
            if ship.sboost < 20 then
                ship.sboost = 20
                sfx(-1, 3)
                sfx(10, 3)
            end
            set_state("space.catchup") -- triggers cam mode catchup
        end
        xdtap = 10
    elseif ship.sboost > 0 then -- super boosting 
        -- todo: this will happen 1 frame after start super boost - good? add sleep effect?
        emitters.throttle.active = false
        acl = addvec(acl, polarvec(ship.rot, 0.7))
        ship.sboost = max(ship.sboost - 1, 0)
    elseif btz then -- brake
        emitters.throttle.active = false
        ship.vel = scalevec(ship.vel, 0.8)
        if ship.slowdown == false then
            ship.slowdown = true
            sfx(-1, 3)
            sfx(13, 3)
        end
    elseif btx then -- throttle
        if (emitters.throttle.active == false) sfx(12, 3)
        emitters.throttle.active = true
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
        emitters.throttle.active = false
        ship.boosttime = 0
        ship.showflame = false
    end

    if not btnd(5) then
        xdtap = xdtap or 0
        xdtap = max(xdtap - 1, 0)
    end
    if (not btz) ship.slowdown = false
    emitters.speedtrail.active = ship.sboost > 0

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
    sdon = btd

    -- velocity, positions
    ship.vel = addvec(ship.vel, acl)
    ship.pos = addvec(ship.pos, ship.vel)
    emitters.throttle.pos = ship.pos
    emitters.throttle.ang = inv_angle(ship.rot)
    emitters.speedtrail.pos = ship.pos
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
    if (rate == 0) rate = ceil(e.rate * fps) -- specifying rate of "1"

    -- cull
    if #e.particles > e.max then
        del(e.particles, e.particles[1])
    end

    -- update
    for p in all(e.particles) do
        p.pat = (e.pats and e.t % e.patrate == 0) and rndtab(e.pats) or p.pat -- pattern
        update_particle(e.particles, p, e.addacl)
    end

    -- fill type
    local fperc = clamp(e.fillperc, 0, 1)
    local fill = rnd(1) <= fperc

    -- new particle if needed (must be after update, or could appear ahead of rocket
    -- this should be fixed in update_particle)
    if e.active and e.t % rate == 0 then
        for i=1,e.reps do
            local ang = e.ang + rnd_range(-e.ang_pm, e.ang_pm)
            local ctab = rndtab(e.ctabs)
            local pm_mag = rnd(e.pm_mag) * rndpm()
            local part = new_particle(e.pos, ang, e.life, e.start_rad, e.end_rad, e.start_mag + pm_mag, e.end_mag, fill, ctab)
            add(e.particles, part)
        end
    end

    -- increment
    e.t += 1
end

function update_particle(particles, p, addacl)
    -- todo: misleading that if mag == 0, angle wont' be reflected in addacl?
    local perc = p.t / (p.life * fps)
    local acl = addacl and addacl(perc) or zerovec()
    local mag = lerp(p.start_mag, p.end_mag, perc)
    local vel = polarvec(p.ang, mag) 
    local cdx = ceil(perc * #p.ctab)

    -- 0.5 is a valid rad (1 pt) but > 1 is floored in circfill
    if (p.start_rad < 1 and p.end_rad < 1) then
        p.rad = 0.5
    else
        p.rad = lerp(p.start_rad, p.end_rad + 1, perc)
    end
    p.col = p.ctab[cdx]
    p.vel = addvec(vel, acl)
    p.pos = addvec(p.pos, p.vel)
    p.t += 1
    -- remove after life
    if p.t > p.life * fps then
        del(particles, p)
    end
end

function acl_throttle(perc) 
    local maxmag = 4
    local mperc = clamp(shipmag(), 0, maxmag) / maxmag
    return scalevec(ship.vel, (1 - perc) * (0.99 * mperc))
end

function acl_speedtrail(perc)
    local spread = 0.08
    local ang = rnd(spread) - spread/2
    local mag = shipmag() * (0.8 + rnd(0.15))
    return polarvec(angle(ship.vel) + ang, mag)
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
    
    if shake > 0 then 
        cam.pos = rnd_circ_vec(cam.pos, 4)
        shake -= 1
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

-- todo: sboost looks strange from this state?
function update_space_launch_cam() 
    if dist(ship.pos, ship.launchpos) > 30 then
        cam.lerptime = 0
        set_state("space.catchup")
    end
end

function update_space_catchup_cam()
    local target = subvec(ship.pos, cam_rel_target())
    local seek =  subvec(target, cam.pos)
    local perc = cam.lerptime / fps

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

function draw_debug()
    local xorg = cam.pos.x + 34
    local yorg = cam.pos.y + 2
    local row = 6

    -- print(state, xorg, yorg) -- game state
    -- print("fr: " .. stat(7), xorg, yorg)
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

    if not in_state("space.die") then 
        draw_facing() 
    end

    -- line(cam.pos.x, hud_bottom, cam.pos.x + 127, hud_bottom, 7) -- hud divider
    line(cam.pos.x, map_bottom, map_side, map_bottom, 7)--minimap bottom
    line(map_side, map_bottom, map_side, cam.pos.y, 7)--minimap side

    draw_mini_map()
    
    local speedcol = hud.speed > 10 and 8 or 7
    print("speed: " .. hud.speed, map_side + 2, topmargin, speedcol)
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
        if p == nearplanet  then
            -- display ship-planet contact shadow
            if p.contact != nil and is_visible(p.contact) and surfdist_toship(p) > 8 then
                circfill(p.contact.x, p.contact.y, 2, 12)
            end
        end
        i += 1
    end
end

function draw_stars()
    for s in all(stars) do
        if rnd(20) > 1 then
            local pos = plaxrel(s.org, s.depth)
            if dist(pos, nearplanet.pos) > nearplanet.rad then
                pset(pos.x, pos.y, 1)
            end
        end
    end
end

function draw_mines()
    local function draw(mine) 
        spr(33, mine.pos.x, mine.pos.y, 2, 2)
        if mine.hit > 0 then -- explosion
            local blastcol = mine.hit % 2 == 0 and 7 or 0
            for i=1,3 do
                local bpos = rnd_circ_vec(mine.pos, 4)
                circfill(bpos.x+7, bpos.y+7, 8, blastcol)
            end
        end
    end
    draw_batches(minefields, draw)
end

function draw_grass()
    local function draw(grass)
        pset(grass.pos.x, grass.pos.y, grass.col)
        -- sspr(grass.ssp.x, grass.ssp.y, 4, 4, grass.pos.x, grass.pos.y, 4, 4, grass.flipx)
    end
    draw_batches(grassbatches, draw)
end

function draw_batches(batches, drawitem)
    for b in all(batches) do
        if b.visible then
            for i in all(b.items) do
                drawitem(i)
            end
        end
    end
end

function draw_space()
    draw_stars()

    local pi = 1
    for p in all(planets) do
        circfill(p.pos.x, p.pos.y, p.rad, 1)
        circ(p.pos.x, p.pos.y, p.rad, 12)
        --moon
        if (p.moon != nil) then
            local mpos = get_moon_pos(p)
            circfill(mpos.x, mpos.y, p.moon.rad, p.moon.col)
        end
        pi += 1
    end

    draw_mines()
    draw_grass()

    -- particles
    draw_particles()

    -- dog
    if (got_dog == false) spr(dog.sprite, dog.pos.x, dog.pos.y)
    if shown_woof and state == "pickup" then
        print("woof! bork! arf!", dog.pos.x, dog.pos.y - 15)
    end

    -- house
    spr(35, house.pos.x, house.pos.y, 2, 2)

    -- shield
    if ship.slowdown then
        -- shield?
    end
    
    -- ship
    if not in_state("space.die") then -- todo: only hide for mine
        local shiptab = ship_spr()
        spr(shiptab[1], ship.pos.x-4, ship.pos.y-4, 1, 1, shiptab[2], shiptab[3])
    end

    -- flame
    if ship.showflame then
        local f = flame_spr()
        spr(f.sprite, ship.pos.x + f.offset.x, ship.pos.y + f.offset.y, 1, 1, f.flipx, f.flipy)
    end

    -- effects
    if shake % 2 == 0 then
        pal()
    else
        pal(0, 9, 1)
        pal(5, 10, 1)
        pal(1, 2, 1)
        pal(6, 10, 1)
    end

    if ship.sboost > 0 then
        if ship.sboost % 2 == 0 then
            prep(shipdrawpos(), addvec(shipdrawpos(), vec(8,8)), 5, 7)
            prep(shipdrawpos(), addvec(shipdrawpos(), vec(8,8)), 6, 7)
        end
    end
end

function shipdrawpos() 
    return subvec(ship.pos, vec(4,4))
end

function draw_particles() -- todo: draw order, patterns!
    for _,e in pairs(emitters) do
        for p in all(e.particles) do
            local pos = p.pos
            if (p.pat) fillp(p.pat)
            if p.fill then
                circfill(pos.x, pos.y, p.rad, p.col)
            else 
                circ(pos.x, pos.y, p.rad, p.col)
            end
            fillp()
        end
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

-- other

function rndtab(tab)
    return tab[ceil(rnd(1)*#tab)]
end

function rndbool()
    return rnd(1) > 0.5
end

function rndpm()
    return rndbool() and -1 or 1
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

function lerpcirc(center, rad, ang1, ang2, t)
    local a = lerp(ang1, ang2, t)
    -- return addvec(center, polarvec(a, rad)) 
    return perimeter_point(center, rad, a)
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

function rnd_circ_vec(center, rad, minradperc)
    -- https://programming.guide/random-point-within-circle.html
    local r = sqrt(rnd(minradperc or 1)) * rad
    local a = rnd(1)
    local p = vec(r * cos(a), r * sin(a))
    return addvec(center, p)
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

-- domain specific helpers

function set_state(s)
    state = s
    debuglog("")
    debuglog("state: " .. s)
    debuglog("")
end

function even()
    return gtime.frame % 2 == 0
end

function is_visible(p)
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

function neardist() -- not flr for game logic. use flr for rendering (todo: optimize by caching value each update in update_common?)
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
    emitters.throttle.active = false
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
    -- return spr_8(ship.rot, 8, 9, 10)
    return spr_8(ship.rot, 25, 26, 27)
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

function surfdist_toship(planet)
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

-- replace color c1 with c2 in rectangle of top-left x1, y1, and bottom-right x2, y2
function prep(v1, v2, c1, c2)
    for x = v1.x, v2.x do
        for y = v1.y, v2.y do
            if (pget(x, y) == c1) pset(x, y, c2)
        end
    end
end









__gfx__
00000000b00000000000000000000000000000000000000000000000000000000005600000000556000000000000000000000000000000000000000000000000
000000000300b0300000000000000000000000000000000000000000000000000055660000005566155000000000000000000000000000000000000000000000
00700700030003000000000000000000005001000000050000000000005000000055660000055666015555500007000000000000000000000000000000000000
0007700000000000000000000000000000051000000550000001000000000000005566001555666000555555000d700000070000000dd7000000000000000000
0007700000000000000000000000000000051000000550000000500000000000055566600156660000666666000dd00000d7700000dd70000000000000000000
00700700000000000000000000000000005001000010000000000000000001000555666000066000056666600000d00000dd0000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000510056000056000566000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000100005000005000000000000000000000000000000000000000000000000000
000000000000000000000000000000000777744000000000077774400777744007777440000cc00000000ccc0000000000000000000000000000000000000000
00000000000000000000000000000000777744440777744077774444777744447777444400c71c000000c7ccccc0000000000000000000000000000000000000
00000000000000000000700000707700770740447777444477074044770740447707404400c11c00000c000c0cccccc000000000000000000000000000000000
00000000000000000077770000777770707004047707404470700404707004047070040400cccc00ccccc0c000ccc70c00000000000000000000000000000000
0000000000000000077777700777777000777400707004044077740000777400007774000cccccc00ccccc0000ccc00c00000000000000000000000000000000
00000000000000000077070000777000444ee00044777400044ee000040ee000000ee0000cccccc0000cc0000cccccc000000000000000000000000000000000
0000000000000000000000000000000004444000044ee0000444400000444400044444000cc00cc0000cc000ccc0000000000000000000000000000000000000
0000000000000000000000000000000004000400040004000400040000474700004747000c0000c00000c0000000000000000000000000000000000000000000
00000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000060000000000000000000000000ee00ee000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000066600000000000000000000000eeeeeeee00000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000666660000000000000000000000eeeeeeee00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000008888800000000000000000000000eeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000006888682260000000000000000000000eeee0000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000668866622660000000700770000000000ee00000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000066668667dd2666600000c77cccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000d688ddd226d00000077cccccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000d822d222d0000007ccccccccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000002222200000007111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000006666d00000000011c1c1c1c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000066d0000000001cca0accccc1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000060000000000ccc000ccc11c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000600000000007c1ccc1cc11c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000011111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0000000000000000000000000000000000010101010101000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00020000346130822002630036400424008540046400724006640062300a6300b630075300d620052200f61009510126100921013610062101361009510116101061008220052200a5200b6200a6300522008600
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

