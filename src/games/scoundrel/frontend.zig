const std = @import("std");
const rl = @import("raylib");
const rlgui = @import("raygui");
const c = @import("../../core/card.zig");
const backend = @import("scoundrel.zig");

pub const Game = struct {
    game: backend.Game,
    cards_texture: rl.Texture2D,
    back_texture: rl.Texture2D,
    weapon_area_texture: rl.Texture2D,
    t: backend.Type,

    const card_w = 64;
    const card_h = 89;

    pub fn init(t: backend.Type) !Game {
        var game = backend.Game.init(t);
        game.nextTurn();
        return .{
            .game = game,
            .cards_texture = try rl.loadTexture("resources/sprites/52-card-deck.png"),
            .back_texture = try rl.loadTexture("resources/sprites/deck-backs.png"),
            .weapon_area_texture = try rl.loadTexture("resources/sprites/weapon-area.png"),
            .t = t,
        };
    }

    fn isPointInsideRect(rect: rl.Rectangle, point: rl.Vector2) bool {
        return rect.x < point.x and
            rect.x + rect.width > point.x and
            rect.y < point.y and
            rect.y + rect.height > point.y;
    }

    pub fn update(self: *Game, screen_width: f32, screen_height: f32) void {
        rl.clearBackground(rl.Color.dark_gray);
        // draw room
        const room = self.game.table.room;
        if (room.size == 1) {
            self.game.nextTurn();
        }

        if (rl.getKeyPressed() == rl.KeyboardKey.r) {
            self.restart();
        }

        if (self.game.hasWon()) {
            rl.drawText(
                rl.textFormat(
                    "You won! Press 'R' to play again\nScore: %02i",
                    .{self.game.player.score},
                ),
                @intFromFloat(screen_width / 4),
                @intFromFloat(screen_height / 2),
                20,
                rl.Color.green,
            );
            return;
        }
        if (self.game.hasLost()) {
            rl.drawText(
                "You lost! Press 'R' to try again",
                @intFromFloat(screen_width / 4),
                @intFromFloat(screen_height / 2),
                20,
                rl.Color.red,
            );
            return;
        }

        const mouse_pos = rl.getMousePosition();
        const left_mouse_pressed = rl.isMouseButtonPressed(rl.MouseButton.left);
        const right_mouse_pressed = rl.isMouseButtonPressed(rl.MouseButton.right);
        for (0..room.size) |r| {
            const card = room.buf[r];
            const rect = getCardTexturePos(card.card);
            var pos = rl.Vector2{
                .x = 0.3 * screen_width + 1.1 * @as(f32, @floatFromInt(r * card_w)),
                .y = 0.4 * screen_height,
            };
            const box_rect = rl.Rectangle{
                .x = pos.x,
                .y = pos.y,
                .width = rect.width,
                .height = rect.height,
            };
            if (isPointInsideRect(box_rect, mouse_pos)) {
                pos.y -= 20;
                switch (card.card.suit) {
                    .clubs, .spades => {
                        if (self.game.canSlainMonster(r) and left_mouse_pressed)
                            self.game.slainMonster(r) catch unreachable
                        else if (right_mouse_pressed)
                            self.game.play(r) catch unreachable;
                    },
                    else => if (left_mouse_pressed)
                        self.game.play(r) catch unreachable,
                }
            }
            rl.drawTextureRec(self.cards_texture, rect, pos, rl.Color.ray_white);
        }
        // draw dungeon
        if (self.game.table.dungeon.size > 0) {
            const i: f32 = @floatFromInt(3 - self.game.table.dungeon.size / 11);
            const rect = rl.Rectangle{ .x = i * card_w, .y = 0, .width = card_w, .height = 105 };
            const pos = rl.Vector2{
                .x = 0.1 * screen_width,
                .y = 0.37 * screen_height,
            };
            rl.drawTextureRec(self.back_texture, rect, pos, rl.Color.ray_white);
        }
        // draw weapon
        {
            const pos = rl.Vector2{
                .x = 0.3 * screen_width,
                .y = 0.7 * screen_height,
            };
            rl.drawTextureV(self.weapon_area_texture, pos, rl.Color.ray_white);
            if (self.game.table.weapon) |weapon| {
                const rect = getCardTexturePos(weapon.card);
                rl.drawTextureRec(self.cards_texture, rect, pos, rl.Color.ray_white);

                const slain = self.game.table.slain_monsters;
                for (0..slain.size) |s| {
                    const s_rect = getCardTexturePos(slain.buf[s].card);
                    const offset: f32 = @floatFromInt((s + 1) * 20);
                    const s_pos = rl.Vector2{
                        .x = pos.x + offset,
                        .y = pos.y,
                    };
                    rl.drawTextureRec(self.cards_texture, s_rect, s_pos, rl.Color.ray_white);
                }
            }
        }
        // draw discard
        blk: {
            const card = self.game.table.discard.last() catch break :blk;
            const rect = getCardTexturePos(card.card);
            const pos = rl.Vector2{
                .x = 0.8 * screen_width,
                .y = 0.4 * screen_height,
            };
            rl.drawTextureRec(self.cards_texture, rect, pos, rl.Color.ray_white);
        }
        // skip turn button
        {
            defer rlgui.guiEnable();
            if (!self.game.canSkipTurn()) {
                rlgui.guiDisable();
            }
            const rect = rl.Rectangle{
                .x = 0.8 * screen_width,
                .y = 0.3 * screen_height,
                .width = 128,
                .height = 32,
            };
            if (rlgui.guiButton(rect, "#131#Skip Turn") > 0) {
                self.game.skipTurn() catch unreachable;
            }
        }
        // draw health
        {
            rl.drawText(
                rl.textFormat("Health: %02i", .{self.game.player.health}),
                @intFromFloat(0.1 * screen_width),
                @intFromFloat(0.1 * screen_height),
                20,
                rl.Color.ray_white,
            );
        }
    }

    pub fn restart(self: *Game) void {
        var game = backend.Game.init(self.t);
        game.nextTurn();
        self.game = game;
    }

    pub fn getCardTexturePos(card: c.Card) rl.Rectangle {
        const y: f32 = switch (card.suit) {
            .spades => 0,
            .hearts => card_h,
            .diamonds => 2 * card_h,
            .clubs => 3 * card_h,
        };
        const name = card.short_name;
        const x: f32 =
            if (std.mem.eql(u8, name, "A"))
                0
            else if (std.mem.eql(u8, name, "J"))
                10
            else if (std.mem.eql(u8, name, "Q"))
                11
            else if (std.mem.eql(u8, name, "K"))
                12
            else blk: {
                const v = std.fmt.parseFloat(f32, name) catch unreachable;
                break :blk v - 1;
            };

        return rl.Rectangle{
            .x = x * card_w,
            .y = y * card_h,
            .width = card_w,
            .height = card_h,
        };
    }
};
