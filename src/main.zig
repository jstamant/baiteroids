const std = @import("std");
const rl = @import("raylib");
const rlgl = @import("raylib").gl;

const screenWidth = 1280;
const screenHeight = 720;
const shipAcceleration = 0.05;
const asteroidAcceleration = 0.01;
const asteroidSpawnRate: i32 = 60 * 5;
const shipTurnRate = 2;

const Ship = struct { pos: rl.Vector2, angle: f32 = 0, v: rl.Vector2 };

const EntityType = enum { ship, asteroid };

const Entity = struct { id: u32, t: EntityType, pos: rl.Vector2, angle: f32 = 0, v: rl.Vector2, hit: bool = false };
var idCounter: u32 = 0;

const destroyed = "YOU ARE DESTROYED";

pub fn main() anyerror!void {
    rl.initWindow(screenWidth, screenHeight, "Baiteroids!");
    defer rl.closeWindow();
    rl.setTargetFPS(60);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var entities = try std.ArrayList(Entity).initCapacity(allocator, 100);
    defer entities.deinit(allocator);

    try entities.append(allocator, .{ .id = idCounter, .t = .asteroid, .pos = .{ .x = 0, .y = 0 }, .v = .{ .x = 0.2, .y = 0 } });
    idCounter += 1;
    var asteroidSpawnTimer: i32 = asteroidSpawnRate;
    var ship: Ship = .{ .pos = .{ .x = screenWidth / 2, .y = screenHeight / 2 }, .v = .{ .x = 0.2, .y = 0 } };
    var shipHit = false;

    var score: u32 = 0;
    // var scoreBuffer = allocator.alloc(u8, 10) catch "SCORE ERR";
    var scoreBuffer: [10:0]u8 = undefined;

    while (!rl.windowShouldClose()) {
        // Input
        if (rl.isKeyDown(.up)) ship.v = updateShipVelocity(ship.v, ship.angle);
        if (rl.isKeyDown(.left)) ship.angle -= shipTurnRate;
        if (rl.isKeyDown(.right)) ship.angle += shipTurnRate;

        // Update velocities
        for (entities.items, 0..) |_, i| {
            entities.items[i].v = updateAsteroidVelocity(entities.items[i].v, entities.items[i].pos, ship.pos);
            entities.items[i].v = entities.items[i].v.clampValue(0.0, 2.0);
        }
        // Update positions
        ship.pos = ship.pos.add(ship.v);
        for (entities.items, 0..) |_, i| {
            entities.items[i].pos = entities.items[i].pos.add(entities.items[i].v);
        }

        // Check collisions
        for (entities.items, 0..) |asteroid, i| {
            // PERF: skip any already hit during this process
            if (asteroid.hit == true) continue;
            for (entities.items, 0..) |other, j| {
                if (asteroid.id == other.id) continue;
                if (asteroid.pos.distance(other.pos) <= 80) {
                    entities.items[i].hit = true;
                    entities.items[j].hit = true;
                    break;
                }
            }
        }
        // Remove collided asteroids
        for (entities.items, 0..) |asteroid, i| {
            if (asteroid.hit == true) {
                _ = entities.orderedRemove(i);
                score += 1;
            }
        }
        // Check for collision with ship
        for (entities.items) |asteroid| {
            if (asteroid.pos.distance(ship.pos) <= 45) {
                shipHit = true;
            }
        }

        // Spawn asteroids
        if (asteroidSpawnTimer == 0) {
            try entities.append(allocator, .{ .id = idCounter, .t = .asteroid, .pos = .{ .x = 0, .y = 0 }, .v = .{ .x = 0.2, .y = 0 } });
            idCounter += 1;
            asteroidSpawnTimer = asteroidSpawnRate;
        }
        asteroidSpawnTimer -= 1;

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.dark_gray);
        const formattedScore = std.fmt.bufPrint(&scoreBuffer, "SCORE: {d}", .{score}) catch "SCORE ERR";
        scoreBuffer[formattedScore.len] = 0;
        rl.drawText(
            scoreBuffer[0..formattedScore.len :0],
            20,
            20,
            40,
            .light_gray,
        );
        if (shipHit) rl.drawText(
            destroyed,
            (screenWidth / 2) - @divTrunc(rl.measureText(destroyed, 60), 2),
            screenHeight / 2 - 30,
            60,
            .light_gray,
        );
        drawShip(ship.pos, ship.angle);
        for (entities.items, 0..) |_, i| {
            drawAsteroid(entities.items[i].pos);
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
    const p1: rl.Vector2 = .{ .x = -8, .y = -8 };
    const p2: rl.Vector2 = .{ .x = 12, .y = 0 };
    const p3: rl.Vector2 = .{ .x = -8, .y = 8 };
    rl.drawTriangleLines(p1, p2, p3, .white);
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
