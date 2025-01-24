package main

import "core:fmt"
import "core:math"
import "core:math/linalg"

import rl "vendor:raylib"
import "vendor:raylib/rlgl"

Vector2 :: rl.Vector2

CURSOR_SIZE :: 10
BREEZE :: rl.Color{27, 30, 32, 255}

SCALE: f32 : 100
WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

// World Value
SCREEN_WIDTH: f32 : WINDOW_WIDTH / SCALE
SCREEN_HEIGHT: f32 : WINDOW_HEIGHT / SCALE
GRAVITY :: 10
DYNAMIC_FRICTION :: 0.2

AIR_FRICTION_FACTOR :: 0.5
FRICTION_THRESH :: 1


Body :: struct {
	mass:   f32,
	radius: f32,
	elast:  f32,
	color:  rl.Color,
	pos:    Vector2,
	vel:    Vector2,
	accel:  Vector2,
}

// global
bodies: [dynamic]Body
selected_body: ^Body
hud_active := true
quit := false

draw_body :: proc(body: Body) {
	using body
	rl.DrawCircle(i32(pos.x * SCALE), i32(pos.y * SCALE), radius * SCALE, color)
	rl.DrawCircleLines(
		i32(pos.x * SCALE),
		i32(pos.y * SCALE),
		radius * SCALE,
		rl.ColorBrightness(color, -0.2),
	)
}

collide_with_borders :: proc(body: ^Body) {
	MIN_VEL_THRESH :: 0.65

	using body
	if pos.x + radius > SCREEN_WIDTH && vel.x > 0 {
		pos.x = SCREEN_WIDTH - radius
		vel.x *= -elast
	} else if pos.x - radius < 0 && vel.x < 0 {
		pos.x = radius
		vel.x *= -elast
	}
	if pos.y + radius > SCREEN_HEIGHT && vel.y > 0 {
		pos.y = SCREEN_HEIGHT - radius
		vel.y *= -elast
		if abs(vel.y) < MIN_VEL_THRESH do vel.y = 0
	}
	if pos.y - radius < 0 && vel.y < 0 {
		pos.y = radius
		vel.y *= -elast
	}

}

// calculate resulting velociy from elastic
// collision given mass and velocities of 2 bodies and line of impact.
// Returns final velocity of body 1
collision_result :: proc(n, v1, v2: Vector2, m1, m2: f32) -> Vector2 {
	// n is line of impact
	return v1 - ((2 * m2 / (m1 + m2)) * (linalg.dot(v1 - v2, n)) * n)

}

collide_with_bodies :: proc(body: ^Body) {


	for &other in bodies {
		if (&other == body) do continue

		if (rl.CheckCollisionCircles(
				   body.pos * SCALE,
				   body.radius * SCALE,
				   other.pos * SCALE,
				   other.radius * SCALE,
			   )) {

			line_of_impact := linalg.normalize(other.pos - body.pos)
			// seperate
			dr := (other.radius + body.radius) - linalg.length(other.pos - body.pos) // intersection depth
			body.pos -= line_of_impact * dr

			body.vel = collision_result(line_of_impact, body.vel, other.vel, body.mass, other.mass)
			other.vel = collision_result(
				line_of_impact,
				other.vel,
				body.vel,
				other.mass,
				body.mass,
			)
		}

	}
}


// Drawing
update_draw_frame :: proc() {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(BREEZE)

	for &body, i in bodies {
		draw_body(body)

		if hud_active {
			using body
			rl.DrawText(rl.TextFormat("%d", i), 10, 10 + i32(i) * 30, 32, body.color)
			str := fmt.caprintf("| Speed: %4.1f", linalg.length(vel))
			defer delete(str)
			rl.DrawText(str, 40, 10 + i32(i) * 30, 32, body.color)


			// Friction
			// friction := accel - Vector2{0, GRAVITY}
			// rl.DrawLineV(pos * SCALE, (pos + friction) * SCALE, rl.RED)
		}
	}
	mouse_pos := rl.GetMousePosition()
	if selected_body != nil {
		rl.DrawCircleV(
			selected_body.pos * SCALE,
			CURSOR_SIZE * 0.5,
			rl.ColorBrightness(selected_body.color, -0.2),
		)
		rl.DrawLineEx(
			mouse_pos,
			selected_body.pos * SCALE,
			5,
			rl.ColorBrightness(selected_body.color, -0.2),
		)
		rl.DrawCircleV(mouse_pos, CURSOR_SIZE, rl.ColorBrightness(selected_body.color, -0.2))
	}

}

update_bodies :: proc(dt: f32) {
	FLOOR_DELTA :: 0.1 // meters

	for &body in bodies {
		acceleration := Vector2{0, GRAVITY}
		speed := linalg.length(body.vel)

		if speed > FRICTION_THRESH {
			force := speed * AIR_FRICTION_FACTOR
			dir := -linalg.normalize(body.vel)
			acceleration += dir * (force / body.mass)
		}

		// Floor friction
		if body.pos.y + body.radius > SCREEN_HEIGHT - FLOOR_DELTA {
			dir := Vector2{-math.sign(body.vel.x), 0}
			normal_force := body.mass * GRAVITY
			friction_force := normal_force * DYNAMIC_FRICTION
			acceleration += dir * (friction_force / body.mass)
		}

		body.accel = acceleration
		body.vel += body.accel * dt

		collide_with_bodies(&body)
		collide_with_borders(&body)

		body.pos += body.vel * dt


	}
}

interact_with_bodies :: proc(dt: f32) {
	PULL_FORCE :: 10

	mouse_pos := rl.GetMousePosition() / SCALE
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

add_bodies :: proc() {
	// Make some bodies
	body1: Body = {
		mass   = 20,
		radius = 1.2,
		elast  = 0.75,
		color  = rl.GREEN,
		pos    = Vector2{SCREEN_WIDTH / 7, SCREEN_HEIGHT / 2},
	}
	body2: Body = {
		mass   = 5,
		radius = 0.6,
		elast  = 0.85,
		color  = rl.ORANGE,
		pos    = Vector2{SCREEN_WIDTH / 4, SCREEN_HEIGHT / 2},
	}
	body3: Body = {
		mass   = 1,
		radius = 0.3,
		elast  = 0.8,
		color  = rl.YELLOW,
		pos    = Vector2{SCREEN_WIDTH / 3, SCREEN_HEIGHT / 4},
	}
	body4: Body = {
		mass   = 10,
		radius = 0.8,
		elast  = 0.92,
		color  = rl.RED,
		pos    = Vector2{SCREEN_WIDTH / 2, SCREEN_HEIGHT / 4},
	}
	append(&bodies, body1)
	append(&bodies, body2)
	append(&bodies, body3)
	append(&bodies, body4)
}

// called every frame from platform
update :: proc() {
	dt := rl.GetFrameTime()

	when ODIN_OS != .JS {
		if rl.IsCursorHidden() && selected_body == nil do rl.ShowCursor()
		else if !rl.IsCursorHidden() && selected_body != nil do rl.DisableCursor()
	}

	interact_with_bodies(dt)

	update_bodies(dt)
	update_draw_frame()
}


// we call this from respective platform
init :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Momentum")
	rl.SetTargetFPS(500)
	rlgl.SetLineWidth(2)

	add_bodies()
}

shutdown :: proc() {rl.CloseWindow()}

parent_window_size_changed :: proc(w, h: i32) {rl.SetWindowSize(w, h)}

should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			quit = true
		}
	}

	return !quit
}
