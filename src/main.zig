const std = @import("std");
const rl = @import("raylib");
const rlgl = @import("raylib").gl;

const WINDOW_WIDTH = 1280;
const WINDOW_HEIGHT = 720;
const SPAWN_RATE = 60 * 5;
const foreground = rl.Color.light_gray;
const background = rl.Color.dark_gray;
const shipAcceleration = 0.05;
const asteroidAcceleration = 0.01;
const asteroidVelocityMax = 2.00;
const shipTurnRate = 4;

const Game = struct {
    const Self = @This();
    state: enum { title, play, end } = .title,
    score: i32 = 0,
    spawn_rate: i32 = SPAWN_RATE,
    spawn_timer: i32 = SPAWN_RATE,
    next_id: u32 = 0,
    rng: std.Random.DefaultPrng,
    ship: Ship = undefined,
    gpa: std.mem.Allocator,
    asteroids: std.ArrayList(Asteroid),
    pub fn init(gpa: std.mem.Allocator) Game {
        const seed: u64 = @intCast(std.time.timestamp());
        return Game{
            .rng = std.Random.DefaultPrng.init(seed),
            .gpa = gpa,
            .asteroids = std.ArrayList(Asteroid).initCapacity(gpa, 100) catch unreachable,
        };
    }
    fn deinit(self: *Self) void {
        self.asteroids.deinit(self.gpa);
    }
    fn restart(self: *Self) void {
        self.state = .play;
        self.score = 0;
        self.spawn_rate = SPAWN_RATE;
        self.spawn_timer = self.spawn_rate;
        // self.next_id = 0; // don't reset the ids, no point in it, really
        self.resetShip();
        self.asteroids.clearRetainingCapacity();
        self.spawnAsteroid();
    }
    fn resetShip(self: *Self) void {
        const angle: f32 = @floatFromInt(self.rng.random().intRangeAtMost(u32, 0, 359));
        const v = rl.Vector2.init(0.2, 0).rotate(degreesToRadians(angle));
        self.ship = .{
            .pos = .{ .x = WINDOW_WIDTH / 2, .y = WINDOW_HEIGHT / 2 },
            .angle = angle,
            .v = v,
        };
    }
    fn spawnAsteroid(self: *Self) void {
        const x: f32 = if (self.rng.random().boolean()) WINDOW_WIDTH else 0;
        const y: f32 = if (self.rng.random().boolean()) WINDOW_HEIGHT else 0;
        self.asteroids.append(self.gpa, .{
            .id = self.next_id,
            .pos = .{ .x = x, .y = y },
        }) catch unreachable;
        self.next_id += 1;
    }
};

const Ship = struct {
    pos: rl.Vector2,
    angle: f32 = 0,
    v: rl.Vector2 = .{ .x = 0, .y = 0 },
    hit: bool = false,
};

const Asteroid = struct {
    id: u32,
    pos: rl.Vector2,
    angle: f32 = 0,
    v: rl.Vector2 = .{ .x = 0, .y = 0 },
    hit: bool = false,
};

pub fn main() !void {
    rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Baiteroids!");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // TODO use arena allocator or fixed allocator and free memory on each play?
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var scoreBuffer: [20:0]u8 = undefined;
    var asteroidsBuffer: [20:0]u8 = undefined;

    var game = Game.init(allocator);
    defer game.deinit();

    while (!rl.windowShouldClose()) {
        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(background);

        if (game.state == .play or game.state == .end) {
            // Input
            if (game.state == .play) {
                if (rl.isKeyDown(.up)) game.ship.v = updateShipVelocity(game.ship.v, game.ship.angle);
                if (rl.isKeyDown(.left)) game.ship.angle -= shipTurnRate;
                if (rl.isKeyDown(.right)) game.ship.angle += shipTurnRate;
            }

            // Update velocities
            for (game.asteroids.items, 0..) |_, i| {
                game.asteroids.items[i].v = updateAsteroidVelocity(game.asteroids.items[i].v, game.asteroids.items[i].pos, game.ship.pos);
                game.asteroids.items[i].v = game.asteroids.items[i].v.clampValue(0.0, asteroidVelocityMax);
            }
            // Update positions
            if (game.state == .play) game.ship.pos = game.ship.pos.add(game.ship.v);
            for (game.asteroids.items, 0..) |_, i| {
                game.asteroids.items[i].pos = game.asteroids.items[i].pos.add(game.asteroids.items[i].v);
            }

            // // Check collisions
            // if (game.state == .play) {
            //     for (game.asteroids.items, 0..) |asteroid, i| {
            //         // PERF: skip any already hit during this process
            //         if (asteroid.hit == true) continue;
            //         for (game.asteroids.items, 0..) |other, j| {
            //             if (asteroid.id == other.id) continue;
            //             if (asteroid.pos.distance(other.pos) <= 80) {
            //                 game.asteroids.items[i].hit = true;
            //                 game.asteroids.items[j].hit = true;
            //                 break;
            //             }
            //         }
            //     }
            // }
            // // Remove collided asteroids
            // for (game.asteroids.items, 0..) |asteroid, i| {
            //     if (asteroid.hit == true) {
            //         _ = game.asteroids.orderedRemove(i);
            //     }
            // }
            // Check for collision with ship
            if (game.state == .play) {
                for (game.asteroids.items) |asteroid| {
                    if (asteroid.pos.distance(game.ship.pos) <= 45) {
                        game.ship.hit = true;
                        game.state = .end;
                    }
                }
            }

            // Spawn asteroids
            if (game.state == .play) {
                if (game.spawn_timer <= 0) {
                    game.spawnAsteroid();
                    game.spawn_timer = game.spawn_rate;
                }
                game.spawn_timer -= 1;
            }

            // Update score
            if (game.state == .play) game.score += 1;

            // Draw
            const formattedScore = std.fmt.bufPrint(&scoreBuffer, "SCORE: {d}", .{game.score}) catch "SCORE ERR";
            scoreBuffer[formattedScore.len] = 0;
            rl.drawText(
                scoreBuffer[0..formattedScore.len :0],
                20,
                20,
                40,
                foreground,
            );
            const formattedAsteroids = std.fmt.bufPrint(&asteroidsBuffer, "BAITEROIDS: {d}", .{game.asteroids.items.len}) catch "AST. COUNT ERR";
            asteroidsBuffer[formattedAsteroids.len] = 0;
            rl.drawText(
                asteroidsBuffer[0..formattedAsteroids.len :0],
                20,
                60,
                40,
                foreground,
            );
            if (game.state == .play) drawShip(game.ship.pos, game.ship.angle);
            for (game.asteroids.items, 0..) |_, i| {
                drawAsteroid(game.asteroids.items[i].pos);
            }
        }
        if (game.state == .title) {
            if (rl.isKeyDown(.enter)) game.restart();
            const title_text = "BAITEROIDS";
            rl.drawText(
                title_text,
                (WINDOW_WIDTH / 2) - @divTrunc(rl.measureText(title_text, 60), 2),
                WINDOW_HEIGHT / 2 - 65,
                60,
                foreground,
            );
            const subtitle_text = "press enter to play";
            rl.drawText(
                subtitle_text,
                (WINDOW_WIDTH / 2) - @divTrunc(rl.measureText(subtitle_text, 60), 2),
                WINDOW_HEIGHT / 2 + 5,
                60,
                foreground,
            );
        }
        if (game.state == .end) {
            if (rl.isKeyDown(.enter)) {
                game.restart();
            }
            const destroyedText = "YOU ARE DESTROYED";
            rl.drawText(
                destroyedText,
                (WINDOW_WIDTH / 2) - @divTrunc(rl.measureText(destroyedText, 60), 2),
                WINDOW_HEIGHT / 2 - 30,
                60,
                foreground,
            );
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
    const moment: rl.Vector2 = ship
        .subtract(asteroid)
        .normalize()
        .scale(asteroidAcceleration);
    return v.add(moment);
}

fn degreesToRadians(degrees: f32) f32 {
    return degrees * (std.math.pi / 180.0);
}
