package main

import "core:fmt"
import "core:os"
import "base:runtime"
import "core:math"
import "core:math/linalg"

import rl "vendor:raylib"
import "vendor:raylib/rlgl"

Vector2 :: rl.Vector2

CURSOR_SIZE :: 10

SCALE: f32 : 100
WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

// World Value
SCREEN_WIDTH: f32 : WINDOW_WIDTH/SCALE
SCREEN_HEIGHT: f32 : WINDOW_HEIGHT/SCALE
GRAVITY :: 10
AIR_FRICTION_FACTOR :: 0.5
FRICTION_THRESH :: 1
ELAST :: 0.8

Body :: struct {
    mass: f32,
    radius: f32,
    color: rl.Color,
    pos: Vector2,
    vel: Vector2,
    accel: Vector2,
}

bodies: [dynamic]Body
selected_body: ^Body
hud_active := true

draw_body :: proc(body: Body) {
    using body 
    rl.DrawCircle(i32(pos.x * SCALE),  i32(pos.y * SCALE), radius * SCALE, color)
    rl.DrawCircleLines(i32(pos.x * SCALE),  i32(pos.y * SCALE), radius * SCALE, rl.ColorBrightness(color, -0.2))
}

collide_with_borders :: proc(body: ^Body) {
    using body
    if pos.x + radius > SCREEN_WIDTH && vel.x > 0 {
        vel.x *= -ELAST
    } else if pos.x - radius < 0 && vel.x < 0 {
        vel.x *= -ELAST
    }

    if pos.y + radius > SCREEN_HEIGHT && vel.y > 0 {
        vel.y *= -ELAST
    }
    if pos.y - radius < 0 && vel.y < 0 {
        vel.y *= -ELAST
    }

}

// Drawing
update_draw_frame :: proc() {
    rl.BeginDrawing()
    defer rl.EndDrawing()        

    rl.ClearBackground(rl.SKYBLUE)

    for &body, i in bodies {
        draw_body(body)
        
        if hud_active {
            using body
            rl.DrawText(rl.TextFormat("%d", i), 10, 10 + i32(i)*30, 32, rl.BLACK)
            str := fmt.caprintf("| Speed: %4.1f", linalg.length(vel))
            defer delete(str)
            rl.DrawText(str, 40, 10 + i32(i)*30, 32, rl.BLACK)

            if (&body == selected_body) {
                mouse_pos := rl.GetMousePosition()
                rl.DrawLineEx(mouse_pos, pos*SCALE, 3, rl.WHITE)
            }

            // Friction
            friction := accel - Vector2{0, GRAVITY}
            rl.DrawLineV(pos * SCALE, (pos + friction) * SCALE, rl.RED)
        }
    }

    rl.DrawCircleV(rl.GetMousePosition(), CURSOR_SIZE, rl.WHITE)
    rl.DrawCircleLinesV(rl.GetMousePosition(), CURSOR_SIZE, rl.DARKGRAY)

}

update_bodies :: proc(dt: f32) {
    for &body in bodies {

        speed := linalg.length(body.vel)
        if speed > FRICTION_THRESH {  
            force := speed * AIR_FRICTION_FACTOR
            dir := -linalg.normalize(body.vel)
            air_friction_force := dir * force/body.mass

            body.accel = Vector2{0, GRAVITY} + air_friction_force
        } else {
            body.accel = Vector2{0, GRAVITY}
        }

        body.vel += body.accel * dt

        collide_with_borders(&body)

        body.pos += body.vel * dt
    }
}

interact_with_bodies :: proc(dt: f32) {
    PULL_FORCE :: 10

    mouse_pos := rl.GetMousePosition()/SCALE
    if rl.IsMouseButtonReleased(.LEFT) {
        selected_body = nil
        return
    }
    if !rl.IsMouseButtonDown(.LEFT) do return

    if selected_body == nil { 
        for &body in bodies {
            if rl.CheckCollisionPointCircle(mouse_pos, body.pos, body.radius) {
                selected_body = &body
                break
            }
        }
    }

    if selected_body != nil {
        displacement := mouse_pos - selected_body.pos
        selected_body.vel += displacement * PULL_FORCE * dt
    }

}

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Momentum")
    defer rl.CloseWindow()
   
    rl.SetTargetFPS(144)
    rl.HideCursor()
    rlgl.SetLineWidth(2)

    // Make some bodies
    body1: Body = {
        mass = 10,
        radius = 1,
        color = rl.GREEN,
        pos = Vector2{SCREEN_WIDTH/2, SCREEN_HEIGHT/2},
    }
    body2: Body = {
        mass = 3,
        radius = 0.4,
        color = rl.ORANGE,
        pos = Vector2{SCREEN_WIDTH/4, SCREEN_HEIGHT/4},
    }
    append(&bodies, body1)
    append(&bodies, body2)


    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()

        rl.SetWindowTitle(rl.TextFormat("%d", rl.GetFPS()))

        interact_with_bodies(dt)

        update_bodies(dt)
        update_draw_frame()

    }

}