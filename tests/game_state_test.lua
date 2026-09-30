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

-- Tracked targets (outside-party players) are re-resolved by server id on every refresh.
-- A full walk of the 2303 entity slots per tracked target per refresh is the cost to
-- avoid; the last known index is tried first.
local function count_entity_reads(fn)
    local calls, real = 0, GetEntity;
    GetEntity = function(i) calls = calls + 1; return real(i); end
    fn();
    GetEntity = real;
    return calls;
end

test('a tracked target still at its last entity index is not looked for across every slot', function()
    fake.reset();
    now = 400;
    local buddy = fake.entity({ ServerId = 0x777, Name = 'Buddy', TargetIndex = 0x4A0 });
    fake.state.entities[0x4A0] = buddy;
    assert_eq(common.add_tracked_target(buddy), true, 'tracked');
    common.refresh_game_state();
    now = 401;
    local reads = count_entity_reads(common.refresh_game_state);
    local resolved = common.game_state.tracked[0x777].target_index;
    common.remove_tracked_target(0x777);
    assert_eq(resolved, 0x4A0, 'still resolved');
    assert(reads < 100, 'entity slots walked: ' .. reads);
end);

test('a tracked target that moved to another entity index is found there', function()
    fake.reset();
    now = 500;
    local buddy = fake.entity({ ServerId = 0x778, Name = 'Buddy', TargetIndex = 0x50 });
    fake.state.entities[0x50] = buddy;
    common.add_tracked_target(buddy);
    common.refresh_game_state();
    fake.state.entities[0x50] = fake.entity({ ServerId = 0x999, Name = 'Stranger', TargetIndex = 0x50 });
    fake.state.entities[0x60] = fake.entity({ ServerId = 0x778, Name = 'Buddy', TargetIndex = 0x60 });
    now = 501;
    common.refresh_game_state();
    local resolved = common.game_state.tracked[0x778].target_index;
    common.remove_tracked_target(0x778);
    assert_eq(resolved, 0x60, 'found at the new index, not the stranger at the old one');
end);

os.clock = real_clock;
