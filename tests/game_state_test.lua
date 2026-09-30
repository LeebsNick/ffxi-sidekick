-- refresh_game_state rebuilds the whole party snapshot (closures per member, entity
-- scans for tracked targets). Every per-frame caller must go through the stale guard
-- so the rebuild happens at most ten times a second, not once per rendered frame.
local fake = require('tests.ashita');
local common = require('lib.core.common');

local now = 100;
local real_clock = os.clock;
os.clock = function() return now; end

test('a snapshot younger than 0.1s is reused instead of rebuilt', function()
    fake.reset();
    now = 100;
    common.refresh_game_state();
    now = 100.05;
    common.refresh_game_state_if_stale();
    assert_eq(common.game_state.refreshed_at, 100, 'snapshot kept');
end);

test('a snapshot older than 0.1s is rebuilt', function()
    fake.reset();
    now = 200;
    common.refresh_game_state();
    now = 200.2;
    common.refresh_game_state_if_stale();
    assert_eq(common.game_state.refreshed_at, 200.2, 'snapshot rebuilt');
end);

os.clock = real_clock;
