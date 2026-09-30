-- The config window drops selected songs the player can no longer sing (level sync).
-- That check walks every ability for every party-buff key and asks the client whether
-- each song is known, so it runs on a timer, not on every rendered frame.
local fake = require('tests.ashita');
local ui = require('lib.ui.components');

local now = 100;
local real_clock = os.clock;
os.clock = function() return now; end

-- Known-spell reads, so a test can tell whether the check ran.
local spell_reads = 0;
local function counting_spells(known)
    return setmetatable({}, { __index = function(_, id)
        spell_reads = spell_reads + 1;
        return known[id];
    end });
end

local function bard_ctx()
    local saves = 0;
    local ctx = {
        settings = { party_buffs = { ['Valor Minuet'] = { [1] = true } } },
        party_buffs = { ['Valor Minuet'] = { [1] = true } },
        job_def = {
            job_name = 'Bard', resource_type = 'mp',
            abilities = { buff = {
                { name = 'Valor Minuet', level = 3, spell_id = 399, magic = 'song', buff_id = 195,
                  command = '/ma "Valor Minuet" <me>' },
            } },
        },
        save_callback = function() saves = saves + 1; end,
    };
    return ctx, function() return saves; end
end

test('a selected song the player has not learned is deselected and saved', function()
    fake.reset();
    now = 100;
    fake.state.player.spells = counting_spells({});
    local ctx, saves = bard_ctx();
    ui.disable_uncastable_songs(ctx);
    assert_eq(ctx.party_buffs['Valor Minuet'][1], false, 'session selection dropped');
    assert_eq(ctx.settings.party_buffs['Valor Minuet'][1], false, 'saved selection dropped');
    assert_eq(ctx.settings.disabled_Valor_Minuet, true, 'ability disabled');
    assert_eq(saves(), 1, 'saved once');
end);

test('a selected song the player knows is kept', function()
    fake.reset();
    now = 150;
    fake.state.player.spells = counting_spells({ [399] = true });
    local ctx, saves = bard_ctx();
    ui.disable_uncastable_songs(ctx);
    assert_eq(ctx.party_buffs['Valor Minuet'][1], true, 'selection kept');
    assert_eq(saves(), 0, 'nothing to save');
end);

test('the song check is not repeated within 0.5s', function()
    fake.reset();
    now = 200;
    fake.state.player.spells = counting_spells({ [399] = true });
    local ctx = bard_ctx();
    ui.disable_uncastable_songs(ctx);
    local reads = spell_reads;
    assert(reads > 0, 'first call checked the song');
    now = 200.2;
    ui.disable_uncastable_songs(ctx);
    assert_eq(spell_reads, reads, 'no known-spell read within 0.5s');
end);

test('the song check runs again after 0.5s', function()
    fake.reset();
    now = 300;
    fake.state.player.spells = counting_spells({ [399] = true });
    local ctx = bard_ctx();
    ui.disable_uncastable_songs(ctx);
    local reads = spell_reads;
    now = 300.6;
    ui.disable_uncastable_songs(ctx);
    assert(spell_reads > reads, 'song checked again after 0.5s');
end);

os.clock = real_clock;
