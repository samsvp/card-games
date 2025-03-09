const std = @import("std");

pub const Suit = enum {
    hearts,
    clubs,
    spades,
    diamonds,
};

pub const Card = struct {
    suit: Suit,
    // e.g. A, 2, 3 ..., Q, K
    short_name: []const u8,
    // e.g. Ace, two, three, ..., queen, king
    long_name: []const u8,
};

fn getFrenchShortName(value: i32) []const u8 {
    if (value == 0) return "A";
    if (value == 1) return "2";
    if (value == 2) return "3";
    if (value == 3) return "4";
    if (value == 4) return "5";
    if (value == 5) return "6";
    if (value == 6) return "7";
    if (value == 7) return "8";
    if (value == 8) return "9";
    if (value == 9) return "10";
    if (value == 10) return "J";
    if (value == 11) return "Q";
    if (value == 12) return "K";
    unreachable;
}

fn getFrenchLongName(value: i32) []const u8 {
    if (value == 0) return "Ace";
    if (value == 1) return "2";
    if (value == 2) return "3";
    if (value == 3) return "4";
    if (value == 4) return "5";
    if (value == 5) return "6";
    if (value == 6) return "7";
    if (value == 7) return "8";
    if (value == 8) return "9";
    if (value == 9) return "10";
    if (value == 10) return "Jack";
    if (value == 11) return "Queen";
    if (value == 12) return "King";
    unreachable;
}

pub const french_cards = blk: {
    var cards: [52]Card = undefined;

    for (0..13) |v| {
        for (0..4) |suit_i| {
            const index = v + suit_i * 13;
            cards[index] = Card{
                .suit = @enumFromInt(suit_i),
                .short_name = getFrenchShortName(v),
                .long_name = getFrenchLongName(v),
            };
        }
    }

    break :blk cards;
};
