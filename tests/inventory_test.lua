-- Consumable counts (pet food, ninja tools, oils) gate and label ability rows in the
-- config window, one row per ability, every frame. A count is a walk of every slot in
-- nine containers, so it is remembered for half a second instead of re-walked per call.
local fake = require('tests.ashita');
local common = require('lib.core.common');

local now = 100;
local real_clock = os.clock;
os.clock = function() return now; end

local PET_FOOD = { { id = 4372, name = 'Pet Food Zeta' }, { id = 4371, name = 'Pet Food Epsilon' } };
local TOOLS = { { id = 1161, name = 'Shihei' } };

test('a consumable count is not re-read from the inventory within 0.5s', function()
    fake.reset();
    now = 100;
    fake.state.inventory[0] = { { Id = 4372, Count = 12 } };
    assert_eq(common.count_equippable_items(PET_FOOD), 12, 'first count');
    local reads = fake.state.inventory_reads;
    now = 100.2;
    assert_eq(common.count_equippable_items(PET_FOOD), 12, 'second count');
    assert_eq(fake.state.inventory_reads, reads, 'no container walk within 0.5s');
end);

test('a consumable count is re-read after 0.5s', function()
    fake.reset();
    now = 200;
    fake.state.inventory[0] = { { Id = 4372, Count = 12 } };
    assert_eq(common.count_equippable_items(PET_FOOD), 12, 'first count');
    fake.state.inventory[0][1].Count = 11;
    now = 200.6;
    assert_eq(common.count_equippable_items(PET_FOOD), 11, 'count after use');
end);

test('two consumables keep separate counts', function()
    fake.reset();
    now = 300;
    fake.state.inventory[0] = { { Id = 4372, Count = 12 }, { Id = 1161, Count = 99 } };
    assert_eq(common.count_equippable_items(PET_FOOD), 12, 'pet food');
    assert_eq(common.count_equippable_items(TOOLS), 99, 'tools');
end);

os.clock = real_clock;
