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

        const mouse_pos = rl.getMousePosition();
        const mouse_pressed = rl.isMouseButtonPressed(rl.MouseButton.left);
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
                if (mouse_pressed) {
                    self.game.play(r) catch unreachable;
                }
            }
            rl.drawTextureRec(self.cards_texture, rect, pos, rl.Color.ray_white);
        }
        // draw dungeon
        {
            const rect = rl.Rectangle{ .x = 0, .y = 0, .width = card_w, .height = 105 };
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
            }
        }
        // skip turn button
        {
            defer rlgui.guiEnable();
            if (!self.game.canSkipTurn()) {
                rlgui.guiDisable();
            }
            const rect = rl.Rectangle{
                .x = 0.8 * screen_width,
                .y = 0.37 * screen_height,
                .width = 128,
                .height = 32,
            };
            if (rlgui.guiButton(rect, "#131#Skip Turn") > 0) {
                self.game.skipTurn() catch unreachable;
            }
        }
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
            else if (std.mem.eql(u8, name, "K"))
                10
            else if (std.mem.eql(u8, name, "Q"))
                11
            else if (std.mem.eql(u8, name, "J"))
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
