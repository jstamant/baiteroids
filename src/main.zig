const std = @import("std");
const rl = @import("raylib");
const rlgl = @import("raylib").gl;

const shipAcceleration = 0.05;
const shipTurnRate = 2;

pub fn main() anyerror!void {
    const screenWidth = 1280;
    const screenHeight = 720;

    rl.initWindow(screenWidth, screenHeight, "Baiteroids!");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var pos: rl.Vector2 = .{ .x = screenWidth / 2, .y = screenHeight / 2 };
    var rot: f32 = 0;
    var vel: rl.Vector2 = .{ .x = 0.2, .y = 0 };

    while (!rl.windowShouldClose()) {
        // Input
        if (rl.isKeyDown(.up)) vel = updateShipVelocity(vel, rot);
        if (rl.isKeyDown(.left)) rot -= shipTurnRate;
        if (rl.isKeyDown(.right)) rot += shipTurnRate;

        // Update
        pos = pos.add(vel);

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.dark_gray);

        rl.drawText("Congrats! You created your first window!", 0, 0, 20, .light_gray);

        drawShip(pos, rot);
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

fn updateShipVelocity(v: rl.Vector2, r: f32) rl.Vector2 {
    var moment: rl.Vector2 = .{ .x = shipAcceleration, .y = 0 };
    return v.add(moment.rotate(degreesToRadians(r)));
}

fn degreesToRadians(degrees: f32) f32 {
    return degrees * (std.math.pi / 180.0);
}
