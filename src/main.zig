const std = @import("std");
const rl = @import("raylib");
const rlgui = @import("raygui");

const c = @import("core/card.zig");
const scoundrel = @import("games/scoundrel/frontend.zig");

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 450;

    const fscreenWidth: f32 = @floatFromInt(screenWidth);
    const fscreenHeight: f32 = @floatFromInt(screenHeight);

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow();

    rlgui.guiLoadStyle("resources/style_terminal.rgs");

    var game = try scoundrel.Game.init(.normal);

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        rl.beginDrawing();
        defer rl.endDrawing();

        game.update(fscreenWidth, fscreenHeight);
    }
}
