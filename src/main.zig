const std = @import("std");
const rl = @import("raylib");
const rlgl = @import("raylib").gl;

const screenWidth = 1280;
const screenHeight = 720;
const shipAcceleration = 0.05;
const asteroidAcceleration = 0.01;
const shipTurnRate = 2;

const Ship = struct { pos: rl.Vector2, angle: f32 = 0, v: rl.Vector2 };
const Asteroid = struct { pos: rl.Vector2, angle: f32 = 0, v: rl.Vector2 };

pub fn main() anyerror!void {
    rl.initWindow(screenWidth, screenHeight, "Baiteroids!");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var ship: Ship = .{ .pos = .{ .x = screenWidth / 2, .y = screenHeight / 2 }, .angle = 0, .v = .{ .x = 0.2, .y = 0 } };
    // const a: Asteroid = .{ .pos = .{ .x = 0, .y = 0 }, .angle = 0, .v = .{ .x = 0.2, .y = 0 } };
    var asteroids: [1]Asteroid = .{.{ .pos = .{ .x = 0, .y = 0 }, .angle = 0, .v = .{ .x = 0.2, .y = 0 } }};

    while (!rl.windowShouldClose()) {
        // Input
        if (rl.isKeyDown(.up)) ship.v = updateShipVelocity(ship.v, ship.angle);
        if (rl.isKeyDown(.left)) ship.angle -= shipTurnRate;
        if (rl.isKeyDown(.right)) ship.angle += shipTurnRate;

        // Update velocities
        for (asteroids, 0..) |_, i| {
            asteroids[i].v = updateAsteroidVelocity(asteroids[i].v, asteroids[i].pos, ship.pos);
            asteroids[i].v = asteroids[i].v.clampValue(0.0, 2.0);
        }
        // Update positions
        ship.pos = ship.pos.add(ship.v);
        for (asteroids, 0..) |_, i| {
            asteroids[i].pos = asteroids[i].pos.add(asteroids[i].v);
        }

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.dark_gray);
        rl.drawText("Congrats! You created your first window!", 0, 0, 20, .light_gray);
        drawShip(ship.pos, ship.angle);
        for (asteroids, 0..) |_, i| {
            drawAsteroid(asteroids[i].pos);
        }
    }
}

fn drawShip(pos: rl.Vector2, rot: f32) void {
    const x = pos.x;
    const y = pos.y;
    rlgl.rlPushMatrix();
    defer rlgl.rlPopMatrix();
    rlgl.rlTranslatef(x, y, 0);
    rlgl.rlRotatef(rot, 0, 0, 1);
    const p1: rl.Vector2 = .{ .x = -10, .y = -8 };
    const p2: rl.Vector2 = .{ .x = 10, .y = 0 };
    const p3: rl.Vector2 = .{ .x = -10, .y = 8 };
    // not working... but drawTriangleLines works!???
    // rl.drawTriangle(p1, p2, p3, .white);
    rl.drawTriangleLines(p1, p2, p3, .white);
    // NOTE for debugging hitbox
    rl.drawCircleLines(0, 0, 10, .white);
}

fn drawAsteroid(pos: rl.Vector2) void {
    const x = pos.x;
    const y = pos.y;
    rlgl.rlPushMatrix();
    defer rlgl.rlPopMatrix();
    rlgl.rlTranslatef(x, y, 0);
    rl.drawCircleLines(0, 0, 40, .white);
}

fn updateShipVelocity(v: rl.Vector2, r: f32) rl.Vector2 {
    var moment: rl.Vector2 = .{ .x = shipAcceleration, .y = 0 };
    return v.add(moment.rotate(degreesToRadians(r)));
}

fn updateAsteroidVelocity(v: rl.Vector2, asteroid: rl.Vector2, ship: rl.Vector2) rl.Vector2 {
    const moment: rl.Vector2 = ship.subtract(asteroid).normalize().scale(asteroidAcceleration);
    return v.add(moment);
}

fn degreesToRadians(degrees: f32) f32 {
    return degrees * (std.math.pi / 180.0);
}
