const std = @import("std");
const card = @import("../../core/card.zig");

pub const Card = struct {
    card: card.Card,
    value: i32,
};

pub const Type = enum {
    normal,
    easy,
};

fn StackBuffer(comptime T: type, N: comptime_int) type {
    return struct {
        buf: [N]T,
        size: usize,

        const Self = @This();

        pub fn init() Self {
            return Self{
                .buf = undefined,
                .size = 0,
            };
        }

        pub fn initFrom(buf: []const T) Self {
            var s = init();
            std.mem.copyForwards(T, &s.buf, buf);
            s.size = buf.len;
            return s;
        }

        pub fn last(self: Self) !T {
            if (self.size == 0) {
                return error.EmptyBuffer;
            }
            return self.buf[self.size - 1];
        }

        pub fn add(self: *Self, value: T) void {
            self.buf[self.size] = value;
            self.size += 1;
        }

        pub fn pop(self: *Self, idx: usize) !T {
            if (idx >= self.size) {
                return error.IndexOutOfRange;
            }

            const value = self.buf[idx];
            self.remove(idx);
            return value;
        }

        pub fn clear(self: *Self) void {
            self.size = 0;
        }

        pub fn remove(self: *Self, idx: usize) void {
            for (idx..self.size - 1) |i| {
                self.buf[i] = self.buf[i + 1];
            }
            self.size -= 1;
        }
    };
}

pub const Player = struct {
    health: i32,
    score: i32,
};

pub const Table = struct {
    weapon: ?Card,
    slain_monsters: StackBuffer(Card, 13),
    room: StackBuffer(Card, 4),
    dungeon: StackBuffer(Card, 44),
    discard: StackBuffer(Card, 44),
};

pub const Game = struct {
    table: Table,
    player: Player,

    turn: usize = 0,
    healed: bool = false,
    skipped_turn: bool = false,

    r: std.Random.Xoshiro256,
    const room_max_size = 4;

    fn getValue(name: []const u8, t: Type) i32 {
        if (std.mem.eql(u8, name, "A")) {
            return switch (t) {
                .normal => 14,
                .easy => 1,
            };
        }
        if (std.mem.eql(u8, name, "K")) return 13;
        if (std.mem.eql(u8, name, "Q")) return 12;
        if (std.mem.eql(u8, name, "J")) return 11;
        return std.fmt.parseInt(i32, name, 10) catch unreachable;
    }

    pub fn init(t: Type) Game {
        var cards = getCards: {
            var _cards: [44]Card = undefined;
            var i: usize = 0;
            for (0..13) |v| for (0..4) |suit_i| {
                const index = v + suit_i * 13;
                const c = card.french_cards[index];
                const value = getValue(c.short_name, t);
                const suit: card.Suit = @enumFromInt(suit_i);
                if ((suit == .hearts or suit == .diamonds) and (value > 10 or value == 1))
                    continue;

                _cards[i] = Card{
                    .card = c,
                    .value = value,
                };
                i += 1;
            };
            break :getCards _cards;
        };
        var r = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        std.Random.shuffle(r.random(), Card, &cards);
        const dungeon = StackBuffer(Card, 44).initFrom(&cards);
        return Game{
            .table = .{
                .weapon = null,
                .slain_monsters = StackBuffer(Card, 13).init(),
                .room = StackBuffer(Card, 4).init(),
                .dungeon = dungeon,
                .discard = StackBuffer(Card, 44).init(),
            },
            .player = .{ .health = 20, .score = 20 },
            .r = r,
        };
    }

    pub fn canSkipTurn(self: Game) bool {
        return !self.skipped_turn and
            self.table.room.size == room_max_size;
    }

    pub fn skipTurn(self: *Game) !void {
        if (!self.canSkipTurn()) return error.CanNotSkipTurn;

        // add to the back of the dungeon
        std.Random.shuffle(self.r.random(), Card, &self.table.room.buf);
        for (0..room_max_size) |i| {
            self.table.dungeon.add(self.table.room.buf[i]);
        }
        self.table.room.clear();

        // new room
        self.nextTurn();
        self.skipped_turn = true;
    }

    pub fn nextTurn(self: *Game) void {
        self.skipped_turn = false;
        self.healed = false;

        while (self.table.room.size < room_max_size) {
            const c = self.table.dungeon.pop(0) catch {
                return;
            };
            self.table.room.add(c);
        }
    }

    // Plays the card at the given index. Playing clubs or spades means taking direct damage.
    pub fn play(self: *Game, i: usize) !void {
        if (i >= self.table.room.size)
            return error.OutOfRange;

        const target_card = try self.table.room.pop(i);
        switch (target_card.card.suit) {
            .hearts => {
                if (!self.healed) {
                    self.player.health = @min(20, self.player.health + target_card.value);
                }
                self.table.discard.add(target_card);
                self.healed = true;
            },
            .clubs, .spades => {
                self.player.health -= target_card.value;
                self.table.discard.add(target_card);
            },
            .diamonds => {
                if (self.table.weapon) |weapon| {
                    self.table.discard.add(weapon);
                }
                for (0..self.table.slain_monsters.size) |m_i| {
                    self.table.discard.add(self.table.slain_monsters.buf[m_i]);
                }
                self.table.slain_monsters.clear();
                self.table.weapon = target_card;
            },
        }
        self.player.score = self.getScore();
    }

    pub fn canSlainMonster(self: *Game, i: usize) bool {
        if (self.table.weapon == null)
            return false;

        const target_card = self.table.room.buf[i];
        const value = blk: {
            const m = self.table.slain_monsters.last() catch break :blk 100;
            break :blk m.value;
        };
        if (target_card.value >= value)
            return false;

        return i < self.table.room.size;
    }

    pub fn slainMonster(self: *Game, i: usize) !void {
        if (!self.canSlainMonster(i)) return error.CanNotSlainMonster;

        const target_card = try self.table.room.pop(i);
        const damage = target_card.value - self.table.weapon.?.value;
        if (damage > 0) {
            self.player.health -= damage;
        }
        self.table.slain_monsters.add(target_card);
        self.player.score = self.getScore();
    }

    pub fn hasWon(self: Game) bool {
        return self.table.dungeon.size == 0 and
            self.table.room.size == 0 and
            self.player.health > 0;
    }

    pub fn hasLost(self: Game) bool {
        return self.player.health <= 0;
    }

    pub fn getScore(self: Game) i32 {
        if (self.table.dungeon.size == 0 and self.table.room.size == 1) {
            const c = self.table.room.buf[0];
            if (c.card.suit == .hearts and self.player.health == 20) {
                return self.player.health + c.value;
            }
        }
        return self.player.health;
    }
};
