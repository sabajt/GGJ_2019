pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

level = 1
influence_multiplier = 8 
swing = 0
fps = 30

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
    ball = new_ball(get_start_pos(level))
    stars = new_stars()
end

function init_putt() 
    set_state("putt.pre")

    ball.facing = 2 -- up (redundant with new_ball)
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

function new_ball(pos)
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

-- rotation is based on facing for now. 
-- this will flip to facing based on rotation for v2 (precicion) steering
function get_ball_rot()
    return ball.facing / 8 -- facing 1:upright -> ccwise -> 8:right
end

function get_ball_vel_ang()
    return angle(ball.vel)
end

function get_ball_stopped()
    local breakpoint = 15
    return ballmag() < ball.min_mag and ball.time > breakpoint
end

function init_levels()
    levels = {
        { -- 1
            par = 1,
            goal = new_goal(-200, 64, 3),
            planets = {
                new_planet(64, 64, 250, 4),
                new_planet(3500, -3700, 150, 3)
            }
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

function new_planet(x, y, rad, col)
    return {
        pos = makevec(x, y),
        rad = rad,
        col = col,
        huddist = 0 -- scaled, readable distance from ship to planet for hud display
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

function get_level(lev) 
     return levels[lev]
end

function get_planets(lev) 
    local l = get_level(lev)
    return get_level(lev).planets
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
    if ball.time % 8 == 0 then 
        hud.speed = flr(ballmag() * 10) -- readable speed 
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

    update_emitter(ball.emitter)
    update_hud()
    update_putt_cam() 
end

function update_putt_pre()
    if btnp(5) then
        set_state("putt.launch")
        ball.vel = zerovec()
    end
end

function update_putt_fly()

    local ball_in_grav_field = false
    local stopped = false

    -- accumulate forces
    ball.acl = zerovec()
    for p in all(get_planets(level)) do
        local checkcollide = ball.time > 30
        if checkcollide and circcollide(ball.pos.x, ball.pos.y, ball.rad, p.pos.x, p.pos.y, p.rad) then
            -- collide with planet body
            stop_ball() -- any bugs if the rest of function continues?
            stopped = true
        elseif circcollide(ball.pos.x, ball.pos.y, ball.rad, p.pos.x, p.pos.y, get_planet_foi(p)) then
            -- in planet grav field
            ball.acl = addvec(ball.acl, gravity(p, ball))
            ball_in_grav_field = true
        end
    end

    if stopped == false then
        update_putt_fly_2()
    end
end

function rndtab(tab)
    return tab[ceil(rnd(1)*#tab)]
end

-- todo: don't be silly
function update_putt_fly_2()

    if btn(5) then
        ball.emitter.active = true
        ball.acl = addvec(ball.acl, boostvec())
        if ball.boosttime == 0 then 
            ball.showflame = true
            ball.flipflame = false
        end
        if (ball.boosttime % 2 == 0) ball.showflame = not ball.showflame
        if (ball.boosttime % 4 == 0) ball.flipflame = not ball.flipflame
        ball.boosttime += 1
    else
        ball.emitter.active = false
        ball.boosttime = 0
        ball.showflame = false
    end    

    -- turn rocket facing (does this need to be somewhere else?)
    if btn(0) then -- left
        ball.turn_tick += 1
        if ball.turn_tick > 3 then 
            ball.facing += 1
            ball.turn_tick = 0
        end
    elseif btn(1) then -- right
        ball.turn_tick += 1
        if ball.turn_tick > 3 then
            ball.facing -= 1
            ball.turn_tick = 0
        end
    else 
        ball.turn_tick = 0
    end
    ball.facing = wrap(ball.facing, 0, 7, true)

    -- velocity, positions
    ball.vel = addvec(ball.vel, ball.acl)
    ball.pos = addvec(ball.pos, ball.vel)
    ball.emitter.pos = ball.pos
    ball.emitter.ang = inv_angle(get_ball_rot())

    -- check for goal
    local goal = get_goal(level)
    if circcollide(ball.pos.x, ball.pos.y, ball.rad, goal.pos.x, goal.pos.y, goal.rad) then
        win_level()
    end

    ball.time += 1
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
    local rel_target = perimeter_point(centervec(), 30, inv_angle(get_ball_rot()))
    local cam_target = subvec(ball.pos, rel_target)
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
    if dist(ball.pos, get_start_pos(level)) > 30 then
        cam.lerptime = 0
        set_state("putt.catchup")
    end
end

function update_putt_catchup_cam()
    local target = subvec(ball.pos, cam_rel_target())
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
    cam.pos = subvec(ball.pos, cam_rel_target())
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
        local dir = dirvec(p.pos, ball.pos)
        local ang = angle(dir)
        local contact = perimeter_point(p.pos, p.rad, inv_angle(ang))

        if in_cam_view(contact) then -- display ship-planet contact shadow
            if planet_dist(i) > 8 then
                circfill(contact.x, contact.y, 2, 3) 
            end
        else -- display surface distance
            line(contact.x, contact.y, ball.pos.x, ball.pos.y, p.col)

            local text = "" .. p.huddist

            -- local x = clamp(contact.x, cam.pos.x + 2, cam.pos.x + 129 - (2 + #text * 4))
            -- local y = clamp(contact.y, hud_bottom + 2, cam.pos.y + 121)

            local v1 = ball.pos
            local v2 = addvec(ball.pos, dir)
            local tl, tr, br, bl = cam_box()
            local x, y
            debuglog("")
            debuglog("start loop")
            for seg in all({{a = tl, b = tr}, {a = tr, b = br}, {a = br, b = bl}, {a = bl, b = tl}}) do 
                local xint, yint = line_intersect(v1, v2, seg.a, seg.b)
                if (xint != nil and yint != nil) and ((x == nil and y == nil) or (xint < x and yint < y)) then 
                    x, y = xint, yint
                end
                debuglog("v1 = " .. v1.x .. ", " .. v1.y .. ", v2 = " .. v2.x .. ", " .. v2.y .. ", seg a = " .. seg.a.x .. ", " .. seg.a.y .. ", seg b = " .. seg.b.x .. ", " .. seg.b.y .. ", xint = " .. xint .. ", yint = " .. yint .. ", x = " .. x .. ", y = " .. y)
            end

            print(text, x, y, p.col) 
            debuglog("")
        end
        i += 1
    end
end

function cam_box() -- top-left, top-right, bottom-right, bottom-left
    return cam.pos, addvec(cam.pos, makevec(128, 0)), addvec(cam.pos, makevec(128, 128)), addvec(cam.pos, makevec(0, 128))
end

function slope(v1, v2)
    return (v2.y - v1.y) / (v2.x - v1.x)
end

function y_intercept(v1, v2)
    return v1.y - slope(v1, v2) * v1.x
end

function line_intersect_slopeform(v1, v2, w1, w2)  
    local mv = slope(v1, v2)
    local bv = y_intercept(v1, v2)
    local mw = slope(w1, w2)
    local bw = y_intercept(w1, w2)

    --[[ 
        y = mv * x + bv
        -mv * x + y = bv
        -mv * x + (mw * x + bw) = bv 
        x + (mw * x + bw) / -mv = bv / -mv
        x + (mw * x / -mv) + (bw / -mv) = bv / -mv
        x + (mw * x / -mv) = (bv / -mv) - (bw / -mv)
        -mv * x + mw * x = -mv * ((bv / -mv) - (bw / -mv))
        (-mv + mw) * x = -mv * ((bv / -mv) - (bw / -mv))
        (-mv + mw) * x = bv - bw
        x = (bv - bw) / (mw - mv)
    ]] 

    local x = (bv - bw) / (mw - mv)

    debuglog("")
    debuglog("line_intersect_slopeform")
    debuglog("x = " .. x)
    debuglog("")
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

function draw_stars()
    local i = 0
    for star in all(stars) do
        local pos = addvec(star.org_pos, scalevec(flrvec(cam.pos), star.depth))
        spr(star.sprite, pos.x, pos.y)
        i += 1
    end
end

function draw_putt()

    -- stars
    draw_stars()

    -- planets
    for p in all(get_planets(level)) do
        circfill(p.pos.x, p.pos.y, p.rad, p.col)
        circ(p.pos.x, p.pos.y, get_planet_foi(p), p.col)
    end

    -- particles
    draw_particles()

    -- goal
    local goal = get_goal(level)
    spr(16, goal.pos.x-4, goal.pos.y-12, 1, 2)

    -- ball
    local balltab = ball_spr()
    spr(balltab[1], ball.pos.x-4, ball.pos.y-4, 1, 1, balltab[2], balltab[3])

    -- flame
    if ball.showflame then
        local f = flame_spr()
        spr(f.sprite, ball.pos.x + f.offset.x, ball.pos.y + f.offset.y, 1, 1, f.flipx, f.flipy)
    end

    -- win state
    if state == "putt.win" then
        local win_text = "sunk it!"
        print(win_text, cam.pos.x+hcenter(win_text), cam.pos.y+10, 7)
    end
end

function draw_particles()
    for p in all(ball.emitter.particles) do
        circfill(p.pos.x, p.pos.y, p.rad, p.col)
    end
end

-- debug

function debugclear()
    printh("", "spacegolf_log", true)
end

function debuglog(s)
    printh(format_gtime() .. s, "spacegolf_log")
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
    local mperc = clamp(ballmag(), 0, maxmag) / maxmag
    acl = addvec(acl, scalevec(ball.vel, (1 - perc) * (0.99 * mperc)))

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

-- game

function set_state(s)
    state = s
    debuglog("")
    debuglog("state: " .. s)
    debuglog("")
end

function stop_ball()
    ball.vel = zerovec()
    ball.pwr = 0
    ball.time = 0
    ball.res_mag = ball.start_res_mag
    ball.emitter.active = false
    ball.pos = get_start_pos(level)
    ball.facing = 2
    set_state("putt.pre")
end

function win_level()
    set_state("putt.win")
    ball.vel = zerovec()
end

function cam_rel_target()
    return perimeter_point(centervec(), cam_radius(), inv_angle(get_ball_vel_ang()))
end

function cam_radius()
    -- radius is proportional to rocket magnitude. 
    local radrange = 40
    local magrange = 10 
    return min((radrange * ballmag()) / magrange, radrange)
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

function ballmag()
    return vecmag(ball.vel)
end

function ball_spr()
    local ang = get_ball_rot()
    return spr_8(ang, 8, 9, 10)
end

function flame_spr()
    local f = {}
    local ang = get_ball_rot()
    local s = spr_8(ang, 11, 12, 13)
    local facing = ball_facing(ang)
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

    if ball.flipflame then
        if (facing == 2 or facing == 6) f.flipx = not f.flipx
        if (facing == 4 or facing == 8) f.flipy = not f.flipy
    end

    return f
end

function boostvec()
    return polarvec(get_ball_rot(), 0.11)
end

function start_planet()
    return get_planets(level)[1]
end

function planet_dist(i)
    local planet = get_planets(level)[i]
    return dist(ball.pos, planet.pos) - planet.rad
end

function ball_facing(angle)
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
00000000000000000000000000000000000000000000000000000000000000000005600000000556000000000000000000000000000000000000000000000000
00000000000900000009999000009000000000000000000000000000000000000055660000005566155000000000000000000000000000000000000000000000
0070070000999000000199900000990000500100000005000000000000500000005566000005566601555550000a000000000000000000000000000000000000
00077000099999000000999009999990000510000005500000010000000000000055660015556660005555550009a000000a000000099a000000000000000000
000770000119110000091190011199100005100000055000000050000000000005556660015666000066666600099000009aa0000099a0000000000000000000
00700700000900000091001000009100005001000010000000000000000001000555666000066000056666600000900000990000000000000000000000000000
00000000000100000010000000001000000000000000000000000000000000000510056000056000566000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000100005000005000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09090900000cc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9090900000cc6c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0909090000cccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
90909000000cc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00019610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00145691000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00140191000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00014410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
012800201855018055185611803224521245350c51624000240261a0001a53611000150461a0001c5371c0271f5141e6121d5321c61718057170770e1700e0700517700000000000000000000000000000000000
010c0000180001c0001a0002400000000000000000000000000000000000000180571c0571a057240550000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011e000000045000000057500000000050000000075000000704500000075750000007145000001003610046000450000000575000000000500000000750000007045000000e575186150f125000001152110511
011e00001c1101f1111f1111f115181141812624616107131e546240001800024000000000000000000000001c1101f1111f1111f115181141812624616107130000000000000000000000000000000000000000
010c00200004000010000111200000050000100000000000000400001500000000000005000014000000000000040000150000000000000500001400000000000004000015000000000000050000140000000000
010c00000004000010000111200000050000150000000000000400001100000000000005000015000000000000040000110000000000000500001500000000000004000011000000000000050000150000000000
010c00000004000010000111200000050000150000000000020400201100000000000405004015000000000005040050110000000000050500501500000000000504005011000000000005050050150000000000
010c00000404004010040111200004050040150000000000040400401100000000000405004015000000000009040090110000000000090500901500000000000804008011000000000007050070150000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000000000000000000000000000000000000000000000000000000000001e0500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 02034344
00 06464344
00 07424344

