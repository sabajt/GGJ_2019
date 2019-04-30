pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- laika
-- by jsaba, nolan

-- inits

function _init()
    fps = 30
    debugcam = false
    debugclear()
    init_space()
end

function init_space()
    pal()
    set_state("space.pre")

    shake = 0
    dietime = 0
    diedur = 2*fps
    gtime = new_gtime()
    planets = new_planets()
    nearpos, nearrad = planets[1].pos, planets[1].rad
    homeplanet = planets[1]
    nearplanet = homeplanet
    neargridsize = nearplanet.cavegridsize
    nearsurfrad, nearsurfdist = 0, 0 -- set in space_fly
    minefields = new_minefields()
    grassbatches = new_grassbatches(nearpos, nearrad)
    starbatches = new_starbatches()
    cam = new_cam()
    startpos = addvec(homeplanet.pos, vec(0, -homeplanet.rad))
    ship = new_ship(startpos)
    nearshipang = nearang(ship.pos)
    walker = new_walker()
    dogs = new_dogs()
    shipdogs = {}
    house = {pos = subvec(startpos, vec(27, 10))}
    hud = {speed = 0, surfdist = 0}
    emitters = new_emitters()
end

-- constructors

function new_walker()
    return {
        ang = 0, -- set to ship on display
        pos = zerovec()
    }
end

function new_gtime()
    return {
        frame = 1, 
        sec = 0,
        min = 0,
        perc = 0
    }
end

function new_planets()
    return { 
        -- pos rad gravrad cols cavegridsize caves [moon]
        new_planet(vec(0.5, 1), 2, 6, {12}, vec(16,8), readcavemap(0, 8*4, 16, 8)),
        new_planet(vec(10, -10), 1, 4, {5}),
        new_planet(vec(-5, 2), 0.5, 2, {13})
    }
end

function readcavemap(x, y, w, h)
    log("-- read cave map (x = "..x.." y = "..y.." w = "..w.." h = "..h..") --")
    local caves = {}
    local xo, yo = 1, 1
    local shf = w/4
    for sx=x-shf+w-1,x-shf,-1 do
        for sy=y+h-1,y,-1 do
            local sxwrap = wrap(sx, 0, w-1, true)
            log("")
            log("ss points = "..sx..", "..sy..", sx wrap ="..sxwrap..", xout = "..xo..", yout = "..yo)
            if (sget(sxwrap, sy) != 0) then
                add(caves, vec(xo, yo))
                log("adding cave = "..vecstring(vec(xo, yo)))
            end
            yo += 1
            log("")
        end
        xo += 1
        yo = 1
    end
    log("read caves length = "..#caves)
    log(" -- end read cave map --")
    return caves
end

function new_minefields()
    local p1,p2 = homeplanet,planets[2]
    local fields = {}
    local count = 20

    for i=1,count do
        local a = i/count
        local p = prm(p2.pos, p2.rad, a)
        p = addvec(p, pvec(350, a))
        local f = new_minefield(p, 260, 18) 
        add(fields, f)
    end

    -- testing
    local p = addvec(p1.pos, pvec(p1.rad + 102, 0.25))
    add(fields, new_minefield(p, 50, 10))

    return fields
end

function new_grassbatches(pos, rad)
    local batches = {}
    local cw = 80
    local w = rad*2
    local s = ceil(w/cw)
    local o = subvec(pos, vec(rad, rad))
    for x=0,s-1 do
        for y=0,s-1 do
            local p = vec(o.x+cw*x, o.y+cw*y)
            local items = {}
            local ww = cw/8
            for xx=0,ww-1 do
                for yy=0,ww-1 do
                    local odd = yy % 2 == 0
                    local px = odd and p.x+4 or p.x
                    local pp = vec(px+8*xx, p.y+8*yy)
                    if not cavecollide(vec(pp.x+4, pp.y+4)) and circinclude(pos, rad, pp, 4) then
                        add(items, {pos=pp, flip=odd})
                    end
                end
            end
            local batch = {pos=p, rad=cw, visible=false, items=items}
            add(batches, batch)
        end
    end
    return batches
end

function cavecollide(pos)
    local cell = cavecell(pos)
    if (not cell) return
    local key = tokey(cell)
    return nearplanet.caves[key] != nil
end

function new_starbatches() 
    local batches, mincell, maxcell, starcount = {}, -3, 3, 10
    local range = maxcell - mincell
    local batchcount = range * range
    for x = mincell, maxcell do
        for y = mincell, maxcell do
            local batchpos = vec(x*128, y*128)
            local items = {}
            for i = 1, starcount do
                add(items, { relpos = vec(rnd(128), rnd(128)) })
            end
            add(batches, {
                pos = batchpos, -- set per update 
                org = batchpos,
                rad = 91, -- ~sqrt(64^2)
                depth = 0.85, 
                visible = false, 
                items = items
            })
        end 
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
function new_ship(pos, dogcount)
    return {
        pos = pos,
        launchpos = pos,
        rad = 2,
        rot = 0.25,
        rotvel = 0, 
        col = 3,
        vel = zerovec(),
        time = 0,
        throttletime = 0,
        slowdown = false,
        dogcount = dogcount or 0
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
            {{7, 6, 13, 1}}, -- particle color progression
            1, -- num particle per draw emit (reps)
            0.5, -- % of time particles drawn as filled circles (0% would be all empty circles)
            acl_throttle
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
            4/30, -- rate
            zerovec(), -- pos
            0, -- ang
            0, -- ang plus / min
            6, -- life
            0.5, -- start rad
            0.5, -- end rad 
            0.3, -- start mag
            0.3, -- end mag
            0.1, -- pm mag
            100, -- max num
            {{10, 2, 1}, {12, 13, 1}}, -- colors
            1, -- reps
            1 -- % filled
        )
    }
end

function new_dogs()
    return {
        new_dog(planet_prm(planets[2], .25), 4, 20, "ground"),
        new_dog(planet_prm(homeplanet, .16), 4, 20, "ground"),
        new_dog(planet_prm(homeplanet, .28), 4, 20, "ground")
    }
end

function new_dog(pos, rad, sprite, state) 
    return {pos=pos, rad=rad, sprite=sprite, state=state}
end

function new_planet(relpos, relrad, relgravrad, cols, cavegridsize, caves, moon)
    local pos, rad, gravrad = scalevec(relpos, 128), relrad * 128, relgravrad * 128
    local cavetab = {}
    for c in all(caves) do
        cavetab[tokey(c)] = c
        log("adding key "..tokey(c).. ", value "..vecstring(c))
    end
    return {
        pos = pos,
        rad = rad,
        gravrad = gravrad,
        cols = cols,
        cavegridsize = cavegridsize or vec(8,3), -- todo: should have default size?
        caves = cavetab,
        moon = moon,
        contact = nil -- projected point of ship contact, updated per frame
    }
end

function new_moon(rad, orbrad, orbang, col)
    return {rad=rad, col=col, orbang=orbang, orbrad=orbrad}
end

function new_minefield(pos, rad, count)
    return {
        pos = pos,
        rad = rad,
        items = new_mines(pos, rad, count),
        visible = false
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
        vel = pvec(start_mag, ang),
        ang = ang,
        life = life,
        rad = start_rad,
        start_rad = start_rad,
        end_rad = end_rad,
        start_mag = start_mag,
        end_mag = end_mag,
        ctab = ctab or {0}, -- todo: remove nil check to figure out occasional crash
        col = ctab and ctab[1] or 0, -- todo: see above 
        fill = fill
    }
end

function new_mines(center, rad, count)
    local mines = {}
    for i=1,count do
        local pos = rndcirc(center, rad)
        add(mines, {sprite = 18, pos = pos, rad = 7, hit = 0 })
    end
    return mines
end

-- getters

function moon_pos(planet)
    return prm(planet.pos, planet.moon.orbrad, planet.moon.orbang)
end

function walkerpos(ang)
    local cell = cavecell(addnearprm(ship.pos, -10))
    local perc = cell.y/neargridsize.y
    local nudge = perc == 1 and -4 or 1
    return prm(nearpos, nearrad*perc+nudge, ang)
end

-- updates

function _update()
    btl, btr, btu, btd, btz, btx = btn(0), btn(1), btn(2), btn(3), btn(4), btn(5)
    update_space()
    update_time()
    update_lastdowns()
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
    gtime.perc = gtime.frame / 30
end

function update_hud()
    hud.speed = flr(shipmag() * 10) -- todo: crash logic depd prob shouldn't be hud property
    if (ship.time % 8 == 0) hud.surfdist = flr(nearsurfdist * 0.25) 
    
end

function update_space()
    update_planets()

    if in_state("space.pre") then
        update_space_pre()
    elseif in_states({"space.launch", "space.catchup", "space.fly"}) then
        update_space_fly()
    elseif in_state("space.walk") then
        update_walk()
    elseif in_state("space.die") then
        update_space_die()
    end

    if not in_state("space.walk") then -- todo: fix hacky
        update_mines()
    end

    update_moons()
    update_emitters()
    update_hud()
    update_cam()
    
    -- todo: plax drawing has to be after cam update. figure out why
    update_batches(grassbatches, addvec(cam.pos, centervec()), 91)
    update_batches(starbatches, addvec(cam.pos, centervec()), 91)
end

function update_planets()
    local low
    for p in all(planets) do
        -- set closest planet
        local sd = dist(ship.pos, p.pos) - p.rad
        p.surfdist = sd -- todo: assign all y levels?
        low = low or sd
        if not low or sd <= low then
            low = sd
            nearplanet = p
        end
    end
    nearpos = nearplanet.pos
    nearrad = nearplanet.rad
    neargridsize = nearplanet.cavegridsize
    -- set contact point 
    local dir = dirvec(ship.pos, nearpos) 
    local ang = angle(dir)
    nearplanet.contact = prm(nearpos, nearrad, ang) 

    local eang = ang + rndpm() * rnd(0.2)
    local rad = nearrad + rndpm()*rnd(10) + rnd(5)
    emitters.planetglow.pos = prm(nearpos, rad, eang) 
    emitters.planetglow.ang = eang
    emitters.planetglow.active = nearplanet.surfdist < 256 -- todo: figure out the right value(s)
end

function update_emitters()
    for _,e in pairs(emitters) do
        update_emitter(e)
    end
end

function update_moons()
    for p in all(planets) do
        if (p.moon) p.moon.orbang += 1/(30*30*5)
    end
end

function update_space_pre()
    if btnd(5) then
        set_state("space.launch")
        ship.vel = zerovec() -- todo: at start of space pre?
        poshist = {}
    elseif btnd(4) then
        set_state("space.walk")
        walker.ang = angle(subvec(ship.pos, nearpos))
        walker.pos = walkerpos(walker.ang)
    end
end

function update_space_die()
    dietime = max(0, dietime - 1)
    local t = 1 - dietime / diedur
    local target = subvec(ship.pos, centervec())
    cam.pos = lerpvec(cam.pos, target, t)

    if dietime < diedur * 0.8 then
        emitters.shipdie.active = false
        emitters.fireball.active = false
    end
    if dietime == 0 then
        ship = new_ship(startpos, ship.dogcount)
        set_state("space.pre")
    end
end

function update_batches(batches, focus, visthresh, work, workthresh)
    for b in all(batches) do
        b.pos = b.depth and plax(b.org, b.depth) or b.pos
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
                if circcollide(ship.pos, ship.rad, addvec(m.pos, vec(8, 8)), m.rad) then
                    sfx(-1, 3)
                    sfx(11, 3) 
                    m.hit = 10
                    shake = 10
                    set_state("space.die.mine")
                    dietime = diedur
                    emitters.shipdie.pos = ship.pos
                    emitters.shipdie.active = true
                    emitters.fireball.active = true
                    emitters.fireball.pos = ship.pos
                    emitters.throttle.active = false
                    ship.showflame = false
                else
                    m.hit = 0
                end
            elseif m.hit == 1 then
                del(mines, m)
            end
        end
    end
    update_batches(minefields, addvec(cam.pos, centervec()), 91, update, 1)
end

function shipsurfcollide() -- cache?
    return ship.time > 1 and nearplanet.surfdist < 0 and not cavecollide(ship.pos)    
end

function update_space_fly()

    if shipsurfcollide() then
        local descend = lastcavecell and lastcavecell.y > cavecell(ship.pos).y or true
        if landsafe() and descend then -- land
            stopship()
        else -- crash
            sfx(-1, 3)
            sfx(11, 3) 
            shake = 10
            set_state("space.die.crash")
            dietime = diedur
            emitters.shipdie.pos = ship.pos
            emitters.shipdie.active = true
            emitters.throttle.active = false
            ship.showflame = false
        end
        return
    end

    -- accumulate forces
    local acl = zerovec()
    for p in all(planets) do
        -- todo: opts = point in circ test, cache
        if circcollide(ship.pos, ship.rad, p.pos, p.gravrad) then
            -- in planet grav field
            acl = addvec(acl, grav(p, ship))
        end
    end

    if btz then -- brake
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
        acl = addvec(acl, pvec(0.115, ship.rot))
        if ship.throttletime == 0 then
            ship.showflame = true
            ship.flipflame = false
        end
        if (ship.throttletime % 2 == 0) ship.showflame = not ship.showflame
        if (ship.throttletime % 4 == 0) ship.flipflame = not ship.flipflame
        ship.throttletime += 1
    else
        sfx(-1, 3)
        emitters.throttle.active = false
        ship.throttletime = 0
        ship.showflame = false
    end

    if (not btz) ship.slowdown = false

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
    ship.rot = wrap(ship.rot + ship.rotvel, 0, 1)

    -- todo: max distance from (fix for high speed), min distance to (fix for low speed)
    -- todo: idle behavior
    -- dogs in transit
    local i, maxmag = 1, nil
    for dog in all(shipdogs) do
        local target = prm(ship.pos, i*18, invang(shipvelang))
        local predict = addvec(target, scalevec(ship.vel, fps/4))
        local seek =  scalevec(subvec(predict, dog.pos), .1)
        maxmag = maxmag or vecmag(seek)
        if (i > 1 and vecmag(seek) > maxmag) seek = pvec(maxmag, angle(seek))
        dog.pos = addvec(dog.pos, seek)
        i += 1
    end

    -- velocity, positions
    lastcavecell = cavecell(ship.pos)
    ship.vel = addvec(ship.vel, acl)
    ship.pos = addvec(ship.pos, ship.vel)
    emitters.throttle.pos = ship.pos
    emitters.throttle.ang = invang(ship.rot)
    ship.time += 1
    nearshipang = nearang(ship.pos)
    shipvelang = angle(ship.vel)

    -- ship distance from surface
    local ang = invang(nearshipang)
    local sx, sy = neargridsize.x, neargridsize.y
    local x = ceil(ang*sx)
    local caves = nearplanet.caves
    for y=sy,1,-1 do
        local key = tokey(vec(x,y))
        local cave = caves[key]
        if cave == nil then
            nearsurfrad = nearrad*(y/sy)
            nearground = prm(nearpos, nearsurfrad, ang)
            break
        end
    end
    nearsurfdist = dist(ship.pos, nearpos) - nearsurfrad
end

function addnearprm(pos, addrad)
    local dir = addrad > 0 and dirvec(pos, nearpos) or dirvec(nearpos, pos)
    return addvec(pos, pvec(abs(addrad), angle(dir)))
end

function walkercell(pos) 
    local p = pos or walker.pos -- todo: ops cache walker.pos
    return cavecell(addnearprm(p, -10))
end

function update_walk()
    walker.pos = walkerpos(walker.ang)
    walker.nearship = circcollide(ship.pos, 6, walker.pos, 6)

    local carrydog = walker.carrydog
    local cell = walkercell()
    local perc = cell.y/neargridsize.y
    local circumfrence = (2*3.1415*nearplanet.rad)*perc -- todo: ops cache planet level circumfrences?
    local angspeed = 2/circumfrence

    if not carrydog then
        for d in all(dogs) do
            if d.state == "ground" and circcollide(d.pos, 3, walker.pos, 3) then
                walker.carrydog = d
                d.state = "carry"
            end
        end
    else 
        carrydog.pos = addvec(subvec(walker.pos, vec(4, 4)), pvec(8, walker.ang))
        if walker.nearship then
           walker.carrydog = nil
           ship.dogcount += 1
           carrydog.state = "ship"
           add(shipdogs, carrydog)
        end
    end

    if btnd(4) and walker.nearship then
        set_state("space.pre")
    elseif btr then
        walker.ang = nextwalkang(-angspeed)
    elseif btl then
        walker.ang = nextwalkang(angspeed)
    end
end

function nextwalkang(addang)
    local nextang = wrap(walker.ang+addang, 0, 1)
    local nextwalkpos = walkerpos(nextang)
    local nextgroundpos = addnearprm(nextwalkpos, -10)
    local unblocked = walkercell().y == neargridsize.y or cavecollide(nextwalkpos)
    local ground = not cavecollide(nextgroundpos)
    return (ground and unblocked) and nextang or walker.ang
end

function draw_walk()
    local wspr = walker_spr()
    spr(wspr[1], walker.pos.x-4, walker.pos.y-4, 1, 1, wspr[2], wspr[3])

    if walker.nearship then
        local hudpos = addvec(ship.pos, pvec(18, ship.rot))
        printcenter("z", hudpos, 11)
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
    local fill = rnd(1) <= clamp(e.fillperc, 0, 1)

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
    -- note: if mag == 0 angle won't be reflected in addacl
    local perc = p.t / (p.life * fps)
    local acl = addacl and addacl(perc) or zerovec()
    local mag = lerp(p.start_mag, p.end_mag, perc)
    local vel = pvec(mag, p.ang) 
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

-- updates (cameras)

function update_cam()
    if debugcam then
        scrollcam()
        return
    end

    if state == "space.pre" then
        update_surface_cam(ship.pos, ship.rot)
    elseif state == "space.launch" then
        update_launch_cam()
    elseif state == "space.catchup" then
        update_catchup_cam()
    elseif state == "space.fly" then
        update_snap_cam(ship.pos)
    elseif state == "space.walk" then
        update_surface_cam(walker.pos, walker.ang)
    end
    
    if shake > 0 then 
        cam.pos = rndcirc(cam.pos, 4)
        shake -= 1
    end
end

function scrollcam()
    local p = cam.pos
    if (btl) cam.pos = vec(p.x-5, p.y)
    if (btr) cam.pos = vec(p.x+5, p.y)
    if (btd) cam.pos = vec(p.x, p.y+5)
    if (btu) cam.pos = vec(p.x, p.y-5)
end

function update_surface_cam(focus, rot)
    local rel_target = prm(centervec(), 30, invang(rot))
    local cam_target = subvec(focus, rel_target)
    local seek =  subvec(cam_target, cam.pos)
    local seek_dist = dist(cam.pos, cam_target)
    
    if seek_dist > 1  then
        local move_by = scalevec(seek, 0.1)
        cam.pos = addvec(cam.pos, move_by)
    else
        cam.pos = cam_target
    end
end

function update_launch_cam() 
    if dist(ship.pos, ship.launchpos) > 30 then
        cam.lerptime = 0
        set_state("space.catchup")
    end
end

function update_catchup_cam()
    local target = campoint(ship.pos)
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

function campoint(focus)
    return subvec(focus, cam_rel_target())
end

function update_snap_cam(focus)
    cam.pos = campoint(focus)
end

-- draws

function _draw()
    cls()
    camera(cam.pos.x, cam.pos.y)
    draw_space()
    draw_hud()
    draw_border()
    draw_debug()
end

function draw_debug()
    local xorg = cam.pos.x + 34
    local yorg = cam.pos.y + 2
    local row = 6
    -- print(state, xorg, yorg) -- game state
    print("fps: " .. stat(7), xorg, yorg)
end

function cavecell(pos)
    local dist = dist(nearpos, pos)
    if (dist > nearrad) return
    local x, y = ceil(invang(nearang(pos))*neargridsize.x), ceil(dist/(nearrad/neargridsize.y))
    return vec(x, y)
end

function draw_border()
    line(cam.pos.x, cam.pos.y, cam.pos.x + 127, cam.pos.y, 7) -- top
    line(cam.pos.x + 127, cam.pos.y, cam.pos.x + 127, cam.pos.y + 127, 7) -- right
    line(cam.pos.x + 127, cam.pos.y + 127, cam.pos.x, cam.pos.y + 127, 7) -- bottom
    line(cam.pos.x, cam.pos.y + 127, cam.pos.x, cam.pos.y, 7) -- left
end

function draw_hud()
    -- todo: more obvious state based logic
    if not in_states({"space.die", "space.walk"}) then 
        draw_warning()
        draw_facing() 
    end
    draw_mini_map()
end

function draw_caves()
    for k,v in pairs(nearplanet.caves) do
        draw_cavecell(v.x, v.y)
    end
end

function draw_cavecell(x, y)
    local sx, sy = neargridsize.x, neargridsize.y
    local ang1, ang2 = (x-1)/sx, x/sx
    local yperc1, yperc2 = (y-1)/sy, y/sy
    local l1a, l1b = addvec(nearpos, pvec(yperc1*nearrad, ang1)), addvec(nearpos, pvec(yperc2*nearrad, ang1))
    local l2a, l2b = addvec(nearpos, pvec(yperc1*nearrad, ang2)), addvec(nearpos, pvec(yperc2*nearrad, ang2))
    local caves = nearplanet.caves
    local lcave, rcave = caves[tokey(vec(wrap(x+1, 1, sx, true), y))], caves[tokey(vec(wrap(x-1, 1, sx, true), y))]
    local dcave, ucave = caves[tokey(vec(x, wrap(y-1, 1, sx, true)))], caves[tokey(vec(x, wrap(y+1, 1, sx, true)))]
    local edgecol = y != sy and 13 or 1
    if (not lcave) line(l2a.x, l2a.y, l2b.x, l2b.y, 13)
    if (not rcave) line(l1a.x, l1a.y, l1b.x, l1b.y, 13)
    if (not dcave) circseg(nearpos, nearrad * yperc1, ang1, ang2, 13)
    if (not ucave) circseg(nearpos, nearrad * yperc2, ang1, ang2, edgecol)
end

function circseg(pos, rad, a, b, col)
    local p1, p2 = prm(pos, rad, a), prm(pos, rad, b)
    local tl, _, br, _ = corners(p1, p2)
    local pclip = subvec(tl, flrvec(cam.pos))
    local w, h = br.x-tl.x, br.y-tl.y
    clip(pclip.x, pclip.y, w+2, h+1)
    circ(pos.x, pos.y, rad, col)
    clip()
end

function tokey(vec)
    return ""..vec.x.."-"..vec.y
end

function tovec(key)
    local i, c = 0, nil
    while (c != "-") do
        i += 1
        c = sub(key, i, i)
    end
    local x, y = tonum(sub(key, 1, i-1)), tonum(sub(key, i+1))
    return vec(x, y)
end

function draw_warning()
    -- rough check by direction in close proximity
    local minrayang, maxrayang = min(nearshipang, shipvelang), max(nearshipang, shipvelang)
    local between = min(maxrayang - minrayang, minrayang + (1 - maxrayang))

    -- todo: fixes the warning from showing during first launch
    -- but there is probably a better way where nearground isn't needed
    if (nearground == nil) then 
        return
    end

    -- doing cont
    local warning = between < 0.25 and nearsurfdist < 128*3
    local hudpt = prm(relcenter(), 35, nearshipang)
    local closedist = 70
    local safe = landsafe()
    local colhot = (safe or not warning) and 11 or 8
    local flick = mods(safe and 8 or 4)
    local colshape = flick and colhot or 1
    local coltext = flick and 7 or 5

    if warning then
        if nearsurfdist < closedist then -- surface in sight hud
            local contact = prm(nearpos, nearsurfrad, invang(nearshipang))
            if contact != nil and is_visible(contact) and nearsurfdist > 3 then
                if safe then
                    circfill(contact.x, contact.y, 3.5*(nearsurfdist/closedist)+1, colshape)
                else
                    warntri(contact, .3, 5, colshape)
                end
            end
        else -- surface out of sight hud
            if safe then
                surfhud(hudpt, colshape)
            else
                warntri(hudpt, .3, 10, colshape, true)
            end
            printcenter(tostr(hud.surfdist), hudpt, coltext)
        end
    elseif not btx and dist(nearpos, ship.pos) <= nearplanet.gravrad and nearsurfdist > closedist then 
        -- gravity field indicator while idle
        surfhud(hudpt, colshape)
        printcenter(tostr(hud.surfdist), hudpt, coltext)
    end
end

function relcenter()
    return addvec(cam.pos, centervec())
end

function surfhud(pt, col)
    local r, s = 0.2, 12
    local plus = wrap(nearshipang+r/2, 0, 1)
    local minus = wrap(plus-r, 0, 1)
    local a, b = addvec(pt, pvec(s, plus)), addvec(pt, pvec(s, minus))
    line(a.x, a.y, b.x, b.y, col)
end

function warntri(pos, range, scale, col)
    local plus = wrap(invang(nearshipang)+range/2, 0, 1)
    local minus = wrap(plus-range, 0, 1)
    local a, b = addvec(pos, pvec(scale, plus)), addvec(pos, pvec(scale, minus))
    local c = addvec(pos, pvec(scale, nearshipang))
    tri(a, b, c, col)
end

function tri(a, b, c, col)
    line(a.x, a.y, b.x, b.y, col)
    line(b.x, b.y, c.x, c.y, col)
    line(c.x, c.y, a.x, a.y, col)
end

function landsafe()
    return hud.speed <= 14
end

function mods(s) 
    return flr(gtime.frame / s) % 2 == 0
end

function draw_facing()
    local t = gtime.frame / 30
    t = t > 0 and t or 0.0001 -- guard against 0 index (ceil ensure 1)
    local p = prm(ship.pos, 16, ship.rot)
    local ctab = expand({11,3,13,1,0,1,13,3}, 3)
    local c = ctab[ceil(t * #ctab)]
    circ(p.x, p.y, 1, c)
end

function draw_mini_map()
    local map_side = cam.pos.x + 32
    local map_bottom = cam.pos.y + 32
    line(cam.pos.x, map_bottom, map_side, map_bottom, 7)
    line(map_side, map_bottom, map_side, cam.pos.y, 7)

    local map_corner = addvec(vec(-3000, -5000), startpos)
    local scale_ship = subvec(scalevec(subvec(ship.pos, map_corner), .004), vec(0,  homeplanet.rad * .004))
    local m_ship = addvec(scale_ship, flrvec(cam.pos))

    local scaled_planet_vecs = {}
    local scaled_moon_vecs = {}

    for p in all(planets) do
    local p_scaled = scalevec(subvec(p.pos, map_corner), .004)
        local p_add_cam = addvec(p_scaled, flrvec(cam.pos))
        add(scaled_planet_vecs, p_add_cam)
        if (p.moon) then
            local moon_vec_scaled = scalevec(subvec(moon_pos(p), map_corner), .004)
            local m_add_cam = addvec(moon_vec_scaled, flrvec(cam.pos))
            add(scaled_moon_vecs, m_add_cam)
        end
    end

    local pc = 4
    local i = 1
    for p in all(scaled_planet_vecs) do
        local r = 3
        if (i == 2) r = 2
        circfill(p.x, p.y, r, pc)
        pc += 7
        i+=1
    end

    for m in all(scaled_moon_vecs) do
        circfill(m.x, m.y, 1, 6)
    end

    circ(m_ship.x, m_ship.y, 1 , 8)
end

function draw_stars()
    local function draw(star, batch)
        if rnd(20) > 1 then -- flicker
            local pos = addvec(star.relpos, batch.pos)
            pset(pos.x, pos.y, 7)
        end
    end
    draw_batches(starbatches, draw)
end

function draw_mines()
    local function draw(mine, batch) 
        spr(32, mine.pos.x, mine.pos.y, 2, 2)
        if mine.hit > 0 then -- explosion
            local blastcol = mine.hit % 2 == 0 and 7 or 0
            for i=1,3 do
                local bpos = rndcirc(mine.pos, 4)
                circfill(bpos.x+7, bpos.y+7, 8, blastcol)
            end
        end
    end
    draw_batches(minefields, draw)
end

function draw_grass()
    local function draw(g, bat)
        spr(14, g.pos.x, g.pos.y, 1, 1, g.flip)
    end
    draw_batches(grassbatches, draw)
end

function draw_batches(batches, drawitem)
    for b in all(batches) do
        if b.visible then
            for i in all(b.items) do
                drawitem(i, b)
            end
        end
    end
end

function draw_planets()
    local p = nearplanet
    local colidx = flr(lerp(1, #p.cols, gtime.perc))
    local col = p.cols[colidx]
    circfill(p.pos.x, p.pos.y, p.rad, 0)
    circ(p.pos.x, p.pos.y, p.rad, col)
    if (p.moon != nil) then
        local mpos = moon_pos(p)
        circfill(mpos.x, mpos.y, p.moon.rad, p.moon.col)
    end
end

function corners(a, b) -- tl, tr, br, bl
    local xmin, ymin = min(a.x, b.x), min(a.y, b.y)
    local xmax, ymax = max(a.x, b.x), max(a.y, b.y)
    return vec(xmin, ymin), vec(xmax, ymin), vec(xmax, ymax), vec(xmin, ymax)
end

function draw_house()
    spr(34, house.pos.x, house.pos.y, 2, 2)
end

function draw_space()
    draw_stars()
    draw_planets()
    draw_mines()
    draw_grass()
    draw_caves()
    draw_house()
    draw_particles()
    draw_dogs()
    
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

    -- todo: fix hacky
    if in_state("space.walk") then
        draw_walk()
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
end

function draw_dogs()
    palt(0, false)
    palt(1, true)
    for d in all(dogs) do
        local p = d.pos
        if dist(p, relcenter()) < 192 then
            if d.state == "ship" then
                circ(p.x, p.y, 7, 6)
                spr(d.sprite, p.x-3, p.y-3)
            else
                spr(d.sprite, p.x, p.y)
            end
        end
    end
    palt()
end

function draw_particles() -- todo: draw order
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

function log(s)
    printh(gtimestring()..s, "laika")
end

function gtimestring()
    if (not gtime) return "[nil:nil:nil]"
    return "["..gtime.min..":"..gtime.sec..":"..gtime.frame.."] "
end

function boolstring(b) 
    return b and "true" or "false"
end

function nilstring(s)
    return s != nil and s or "nil"
end

-- vectors

function vec(x, y)
    return {x=x, y=y}
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

function dist(v1, v2)
    return vecmag(subvec(v1, v2))
end

function pvec(r, ang)
    return scalevec(vec(cos(ang), sin(ang)), r)
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
    return "("..(v and v.x or "nil")..", "..(v and v.y or "nil")..")"
end

function prm(center, rad, ang)
    return addvec(center, flrvec(pvec(rad, ang)))
end

function planet_prm(planet, ang)
    local point = prm(planet.pos, planet.rad, ang)
    return point
end

function grav(att, mov)
    local minmag = 0.02
    local maxmag = 0.1
    local dir = dirvec(att.pos, mov.pos)
    local centerdist = dist(att.pos, mov.pos)
    local surfdist = centerdist - att.rad
    local mag = maxmag
    if (surfdist > 0) then
        local gravrange = att.gravrad - att.rad
        local invpercent = 1 - (surfdist / gravrange)
        mag = lerp(minmag, maxmag, invpercent)
    end
    return scalevec(dir, mag)
end

function rectcollide(x1, y1, x2, y2, xx1, yy1, xx2, yy2)
    return (x2 >= xx1 and x1 <= xx2 and y2 >= yy1 and y1 <= yy2)
end

function rectinclude(x1, y1, x2, y2, px, py)
    return (px >= x1 and px <= x2 and py >= y1 and py <= y2)
end

function circcollide(p1, r1, p2, r2)
    return dist(p1, p2) <= r1 + r2
end

function circinclude(p1, r1, p2, r2)
    return dist(p1, p2) <= (max(r1, r2)-min(r1, r2))
end

-- other

function printcenter(string, relpos, col)
    local pos = relpos or centervec()
    pos = subvec(pos, vec(#string*2, 2))
    print(string, pos.x, pos.y, col)
end

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
    -- return addvec(center, pvec(rad, a)) 
    return prm(center, rad, a)
end

function invang(a)
    return a-0.5 > 0 and a-0.5 or (a-0.5)+1
end

function wrap(n, low, high, int)
    if (n < low) return high - (int and (low-n)-1 or low-n)
    if (n > high) return low + (int and (n-high)-1 or n-high)
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

function rndcirc(center, rad, minradperc)
    local r = sqrt(rnd(minradperc or 1)) * rad
    local a = rnd(1)
    local p = vec(r * cos(a), r * sin(a))
    return addvec(center, p)
end

-- table w/each element repeated n times
function expand(tab, n) 
    local extab = {}
    for element in all(tab) do
        for _=1,n do
            add(extab, element)
        end
    end
    return extab
end

lastdowns = expand({false},6)
function update_lastdowns() -- call at end of update cycle
    for i=0,5 do
        lastdowns[i] = btn(i)
    end
end
function btnd(b) 
    return (btn(b) and (lastdowns[b] == false))
end

-- laika helpers

function set_state(s)
    state = s
    log("")
    log("state: " .. s)
    log("")
end

function even()
    return gtime.frame % 2 == 0
end

function is_visible(p)
    local in_x_view = p.x >= cam.pos.x and p.x <= cam.pos.x+128
    local in_y_view = p.y >= cam.pos.y and p.y <= cam.pos.y+128
    return in_x_view and in_y_view
end

-- parallax rel to 0,0, depth 0=close..1=far
-- * must call after update cam pos *
function plax(org, depth) 
    return addvec(org, scalevec(flrvec(cam.pos), depth))
end

function nearang(pos)
    return angle(dirvec(nearpos, pos)) 
end

function stopship()
    sfx(-2, 3)
    ship.vel = zerovec()
    ship.pwr = 0
    ship.time = 0
    emitters.throttle.active = false
    ship.rotvel = 0
    ship.slowdown = false
    local cell = cavecell(ship.pos)
    local perc = cell.y/neargridsize.y
    local ang = angle(dirvec(ship.pos, nearpos))
    ship.rot = ang
    -- don't use perimeter point, we need unfloored to avoid < 0 surf dist
    ship.pos = addvec(nearpos, pvec(perc*nearrad, ang)) 
    ship.launchpos = ship.pos
    set_state("space.pre")
end

function cam_rel_target()
    return prm(centervec(), cam_radius(), invang(shipvelang))
end

function cam_radius()
    -- radius is proportional to rocket magnitude.
    local radrange = 30
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
    return spr_8(ship.rot, 7, 8, 9)
end

function walker_spr()
    local s1, s2 = spr_8(walker.ang, 1, 3, 5), spr_8(walker.ang, 2, 4, 6)
    return (btl or btr) and (mods(4) and s1 or s2) or s1
end

function flame_spr()
    local f = {}
    local ang = ship.rot
    local s = spr_8(ang, 10, 11, 12)
    local face = facing(ang)
    local offsets = {
        vec(-7, -1), -- ur
        vec(-4, 2), -- u
        vec(-1, -1), -- ul
        vec(2, -4), -- l
        vec(-1, -7), -- dl
        vec(-4, -10), -- d
        vec(-7, -7), -- dr
        vec(-10, -4) -- r
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

function facing(angle)
    local a = angle
    if (a >= 1/16 and a < 3/16) return 1 -- ur
    if (a >= 3/16 and a < 5/16) return 2 -- u
    if (a >= 5/16 and a < 7/16) return 3 -- ul
    if (a >= 7/16 and a < 9/16) return 4 -- l
    if (a >= 9/16 and a < 11/16) return 5 -- dl
    if (a >= 11/16 and a < 13/16) return 6 -- d
    if (a >= 13/16 and a < 15/16) return 7 -- dr
    if (a >= 15/16 or a < 1/16) return 8 -- r
end

function spr_8(angle, up, upright, right) -- return {sprite, flip x, flip y}
    local a, u, r, ur = angle, up, right, upright
    if (a >= 1/16 and a < 3/16) return {ur, false, false} -- ur
    if (a >= 3/16 and a < 5/16) return {u, false, false} -- u
    if (a >= 5/16 and a < 7/16) return {ur, true, false} -- ul
    if (a >= 7/16 and a < 9/16) return {r, true, false} -- l
    if (a >= 9/16 and a < 11/16) return {ur, true, true} -- dl
    if (a >= 11/16 and a < 13/16) return {u, false, true} -- d
    if (a >= 13/16 and a < 15/16) return {ur, false, true} -- dr
    if (a >= 15/16 or a < 1/16) return {r, false, false} -- r
end

-- replace col c1 w/ c2 in rect tl: x1 y1, br: x2 y2
function prep(v1, v2, c1, c2)
    for x = v1.x, v2.x do
        for y = v1.y, v2.y do
            if (pget(x, y) == c1) pset(x, y, c2)
        end
    end
end









__gfx__
00000000000000000000000000000000060000000000000000006000000660000000660006660000000000000000000000000000000000000000000000000000
0000000000eeee0000eeee0000eee00000eee000006eee00060eee0000611d00006611d000d66600000000000000000000000000011001100000000000000000
007007000e7111200e7111200e711e000e711e0006e7112000e71120061711d06661711d000611d0000700000000000000000000010001000000000000000000
000770000e1111206e111120061111e00e1111e000e1112000e11120061111d0d661111d0061711d000970000007000000099700000110000001000000000000
000770000e1111200e1111260e1111206211112000e1112000e1112066611ddd00d611d000611115000990000097700000997000000100000000000000000000
0070070006222260002222000d2111200021112006e1112000e111206d06d05d000ddd50000d1150000090000099000000000000011001100000100000000000
0000000000d00d000600006000022600000222000062220006022200d00000050000dd00006dd500000000000000000000000000010001000000000000000000
000000000000000000000000000d0000000060600000000000060000000000000000d50006d50000000000000000000000000000000000000000000000000000
00000000000000000000000000000000177774410000000007777440077774400777744000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000777744440777744077774444777744447777444400000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000770740447777444477074044770740447707404400000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000717004147707404470700404707004047070040400000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000117774117070040440777400007774000077740000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000444ee11144777400044ee000040ee000000ee00000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000014444111044ee00004444000004444000444440000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000141114110400040004000400004747000047470000000000000000000000000000000000000000000000000000000000
00000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00068886822600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00668866622660000000700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66668667dd2666600000c77cccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00d688ddd226d00000077cccccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000d822d222d0000007ccccccccccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000222220000000711111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000006666d00000000011c1c1c1c1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000066d0000000001cca0accccc100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000060000000000ccc000ccc11c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000600000000007c1ccc1cc11c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000001111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33000330033000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03333330033333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00003330033300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00033333333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00333333333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03333333333333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333333b23330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0000000000000000000000000000000000000101010101000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010f000013000130000000013500135000000000000000001a0001a0001a0000b5000b5000b5000b5000b5000b5000b5000e0000e000115001150010000100001c50510504105011050100000000000000000000
010800200403300000000000400304013000000400300000040530000000000040030401300000040030000004033000000000004003040130000004013000000405300000000000400304013000000400300000
01300000000050c000020050410504005040000900509000070050700007005070000600506000090050600005005050000700507000090050500000005100000000000000000000000000000000000000000000
011700000050000500055000550004500045001c504105050450004500115000000004500095000b500000001050010500045000d5000f5001050000000000000000000000000000000000000000000000000000
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
02 01424040
00 42434240
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
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

