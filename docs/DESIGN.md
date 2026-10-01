# Coral Reef Builder: Game Design & Development Plan

> The game is called "Grow a Reef" (it was "Reef Keepers" while in development).

## Vision

A cozy co-op game where players grow a living coral reef, attract rare sea creatures, and visit each other's reefs. The plan below takes it from a one-person prototype to a live game in about 16 weeks.

**One-line pitch:** Grow a reef with friends, collect rare sea creatures, and build the most beautiful reef on the server.

**Why it could work:** it combines the calm, come-back-daily loop of the idle-grow hits with a visual, shareable result (a reef you are proud of) and a built-in reason to invite friends (shared reef growth and trading).

**Target outcome for launch:** 1,000 concurrent players within 60 days of release, with day-1 retention at or above 30% and day-7 retention at or above 10%. These are working goals to adjust once real data arrives.

## Why this game, why now

Cozy idle-grow games have the strongest proof of demand on Roblox, and a reef theme is still open. Evidence from public trackers and articles gathered on 2026-09-30:

| Signal | What it shows | Source |
|---|---|---|
| Grow a Garden reached 1 billion visits in 33 days | A calm, idle farming loop can grow faster than any other game | Wikipedia |
| Social experiences grew 19% and 31% quarter over quarter in 2025 | The platform is moving toward social, narrative play | RoLearn |
| Simulators are called the most reliably profitable genre | Collect-upgrade loops monetize well | Kitsblox |
| Co-op design is rewarded by the 2026 algorithm | Games played in pairs or groups get a discovery boost | Ejaw |
| Obbies continue a multi-year decline | Simple skill games are a weak bet | RoLearn |

**Gap we target:** most cozy hits use farming or pets. An ocean theme offers fresh visuals and natural collectibles (fish, corals, rare creatures) without copying any existing game's mechanics.

**Caveat:** the figures come from aggregator sites that sometimes disagree, and viral hits are hard to predict. Treat this as a reasoned bet, which is why the roadmap includes a cheap early test.

## Audience and design pillars

The core audience is casual players aged roughly 9 to 16, mostly on phones, who want a relaxing game they can check in on several times a day and play with friends.

Every feature must serve at least one pillar, and anything that hurts one gets cut.

1. **Understood in 10 seconds.** Place a coral, watch it grow, collect coins. No tutorial text wall.
2. **Always something to come back to.** Corals grow on real-time timers, so a daily check-in always pays off.
3. **Better with friends.** Shared reefs and visiting boost growth, and the game invites players to bring someone.
4. **Beautiful and shareable.** Reefs should look good in a screenshot or short clip, because that is our free marketing.
5. **Phone first.** Big buttons, short sessions, low memory use, and no required keyboard.

**Explicit non-goals for launch:** no combat, no complex AI, no player-versus-player, and no heavy story. These keep the scope small enough for a solo developer or small team.

## Core gameplay loop

The loop works at four time scales, so a player always has a next step.

| Time scale | What the player does | What pulls them forward |
|---|---|---|
| Seconds | Plant a coral fragment, tap to collect pearls from mature corals | Instant sound, particles, and a number going up |
| Minutes | Spend pearls on new corals, decorations, and reef upgrades while timers run | "One more upgrade" before the next coral finishes |
| Session (5–15 min) | Visit a friend's reef, feed creatures, complete 3 small daily goals | Friend bonuses and visible progress |
| Days and weeks | Unlock rare creatures, expand the reef, prestige for a permanent bonus | Collection book, rarity chase, seasonal events |

**A typical first session:**

1. The player spawns on a small reef plot with one starter coral already growing.
2. A glowing arrow shows them how to plant a second coral and collect their first pearls.
3. Within 60 seconds the first fish arrives, showing that the reef is alive.
4. Within 3 minutes they unlock a second plot slot and see a timer for their next coral.
5. A gentle prompt invites a friend to visit and gives both players a bonus.

**Return hook:** when a player leaves, the game tells them what will be ready when they are back (for example, "Your pink brain coral matures in 4 hours").

## Systems and progression

Six systems make up the game. Build them in this order.

| System | What it does | Launch scope |
|---|---|---|
| Reef plot | A personal space with grid slots for corals and decorations | 6 starting slots, expandable to 40 |
| Corals | Plantable items that grow on timers and produce pearls | 20 types across 5 rarities |
| Creatures | Fish and sea animals that appear when the reef meets conditions | 30 creatures, each tied to a reef condition |
| Reef health | A score from coral variety, density, and care that boosts income | One meter, three visible tiers |
| Collection book | Tracks every coral and creature discovered, with rewards per page | 50 entries at launch |
| Prestige (Tide Reset) | Reset the reef for a permanent multiplier and a special coral | Unlocks after first 10 hours |

**Creature conditions are the depth.** For example, a clownfish needs an anemone and 3 coral types nearby, while a rare seahorse needs reef health above 80%. Players must experiment with layouts, which gives the game a puzzle-like layer without any combat.

**Upgrade tracks:**

- Growth speed: corals mature faster.
- Pearl yield: more pearls per harvest.
- Offline storage: the reef holds more pearls while the player is away.
- Plot size: more slots.

**Progression pacing target:** a new player should reach the first prestige option in about 10 hours of total play, spread over about 1 to 2 weeks.

## Social and co-op features

Social features are the growth engine, so each one gives both players something. Ship the first three at launch and the rest in later updates.

| Feature | How it works | Launch? |
|---|---|---|
| Reef visits | Anyone can visit a friend's reef. Visitors can feed creatures, and both players earn a small pearl bonus (capped daily) | Yes |
| Shared growth boost | Friends on the same server give each other a growth speed bonus that scales with party size up to 4 | Yes |
| Reef likes and showcase | Players can like reefs. A "Top Reefs" board on the spawn island shows the weekly best | Yes |
| Gifting and trading | Trade duplicate corals and creatures with friends, with limits to stop scams | Update 2 |
| Group reef projects | A server-wide reef restoration goal everyone contributes to, with a shared reward | Update 2 |
| Reef photo mode | Hide the UI, pick a camera angle, and save a screenshot | Update 3 |

**Anti-scam design for trading:** two-step confirmation, a visible value summary on both sides, no trading of Robux-purchased items in the first version, and a short cooldown on new accounts.

**Moderation:** use Roblox's built-in text filtering for every player-typed name or message, and keep free-text limited to reef names.

## Economy design

Three currencies keep the economy simple to balance. All numbers are starting values to tune in playtests, not final. The live values are in [`src/shared/Balance.json`](../src/shared/Balance.json).

| Currency | Earned by | Spent on |
|---|---|---|
| Pearls (soft) | Harvesting corals, feeding creatures, daily goals | Corals, plot slots, upgrades |
| Shells (mid) | Rare creature visits, milestones, events | Rare corals, cosmetics, prestige shop |
| Robux (premium) | Real-money purchase | Speed-ups, boosts, exclusive cosmetics, gamepasses |

**Coral rarity tiers and starting values:**

| Rarity | Example | Growth time | Pearls per harvest | Drop source |
|---|---|---|---|---|
| Common | Staghorn coral | 2 min | 5 | Shop, always |
| Uncommon | Brain coral | 15 min | 40 | Shop, unlocked by level |
| Rare | Fan coral | 2 hr | 400 | Shop rotation, refreshes every 30 min |
| Epic | Glowing tube coral | 8 hr | 2,500 | Rare creature drops, events |
| Legendary | Crystal coral | 24 hr | 15,000 | Prestige shop, seasonal events |

**Balance rules:**

- **Faucets and sinks must match.** Every new income source needs a matching place to spend, such as plot expansions that scale up steeply in price.
- **Cost growth:** each plot slot costs about 1.5 times the previous one, so progress slows gradually and prestige feels worth it.
- **Offline earnings cap:** pearls stop accumulating after 8 hours away (raised by an upgrade), which encourages daily check-ins without punishing missed days.
- **Rotating shop:** rare corals appear on a timer, creating a "check the shop" habit.

**Tuning method:** model the economy first, simulate a day-1, day-7, and day-30 player, and check that time-to-next-unlock stays between 2 and 30 minutes early on. See [`tools/economy_sim.py`](../tools/economy_sim.py).

## Monetization plan

The game is free to play, and spending should speed things up or add style, never block progress. Roblox's creator ecosystem supports gamepasses, developer products, and rewarded ads together, so the plan uses all three.

| Product | Type | Idea | Starting price (Robux) |
|---|---|---|---|
| 2x Pearls | Gamepass | Permanent double income | 399 |
| Auto-Harvest | Gamepass | Collects pearls automatically | 249 |
| Extra Plot Slots | Gamepass | +10 slots | 199 |
| VIP Reef Pack | Gamepass | Exclusive coral, name tag, small bonus | 599 |
| Growth Speed-Up | Developer product | Instantly finish one coral, sold in 1, 5, 20 packs | 25 / 99 / 349 |
| Rare Coral Bundle | Developer product | 3 random rare corals | 149 |
| Cosmetics | Developer product | Reef decorations, glow effects, pets | 49 to 199 |
| Rewarded ad | Ad | Watch to double a harvest or get a free speed-up | Free |

**Principles:**

- **Fair to free players.** Everything important can be earned. Paid items save time or add cosmetic flair.
- **No pressure tactics.** No countdown scare tricks, and clear prices before every purchase, since the audience is young.
- **First purchase within reach.** Include a low-priced item (25 to 49 Robux) so a first-time buyer has an easy entry.
- **Test prices.** Try two price points for each gamepass during soft launch and keep the one with better revenue per player.

All prices are placeholders to be tested. Check Roblox's current monetization and advertising policies before launch, because rules for young audiences change.

## Live ops: events, seasons, updates

A steady update rhythm matters more than any single feature. Plan for one meaningful update every 2 weeks and one larger event each month.

| Cadence | Content | Example |
|---|---|---|
| Daily | 3 small goals, rotating shop, login streak reward | "Feed 5 creatures" |
| Weekly | Top Reefs board reset, limited creature visit | A rare seahorse visits for 7 days |
| Every 2 weeks | Update with new corals or creatures | 3 new corals and 5 creatures |
| Monthly | Themed event with its own currency and exclusive items | "Bioluminescence Week" with glowing corals |
| Quarterly | Major feature | Trading, group projects, new reef zone |

**First 6 months of content themes (planned):**

1. Launch: Tropical Reef
2. Month 1: Deep Sea (glowing creatures)
3. Month 2: Kelp Forest
4. Month 3: Arctic Waters
5. Month 4: Sunken Ruins (decoration-heavy)
6. Month 5: Mangrove Nursery (baby creatures)

**Event rules:** events must reward both free and paying players, run for 5 to 14 days, and never remove content that players already own. Announce events in-game 24 hours ahead to build anticipation.

## Technical architecture in Roblox Studio

Clients show the game and send requests; the server checks each request, changes the state, and saves it. This keeps currency, growth, and trades safe from exploits.

**Build practices:**

- **Server-authoritative logic.** The client never decides currency, growth, or rewards. Every remote event is validated and rate-limited on the server.
- **Timers from timestamps.** Store each coral's planted time and compute progress from the current time. This handles offline growth and avoids per-coral loops running every frame.
- **Reliable saving.** Use DataStore with retries and a session lock so two servers cannot overwrite one save, or a vetted community save library. Save on an interval, on leaving, and on server shutdown.
- **Config in one place.** Keep coral, creature, and price values in data modules so balance changes do not need code changes.
- **Phone performance.** Turn on content streaming, keep part counts low, pool and reuse effects, and avoid updating every creature every frame.
- **Organized code.** Split into small services (reef, economy, creatures, trade), use Luau type checking, and keep the project in version control.
- **Logging.** Send custom analytics events for the funnel steps listed in the metrics section.

See the [README](../README.md) for how the prototype in this repo implements these.

## Art direction, audio, and UI

The look is bright, soft, and readable on a small phone screen. Reefs should glow and feel alive even when nothing is happening.

**Art**

- **Style:** stylized low-poly with soft gradients and rounded shapes, not realistic. Cheap to produce and runs well on phones.
- **Colors:** one saturated palette per reef theme, with a calm blue-green base so coral colors pop.
- **Coral design:** each coral has a clear silhouette and a distinct color, so players recognize rarity at a glance. Rarer corals add glow, particles, and animation.
- **Creatures:** simple swim loops with a few idle animations. Reuse one skeleton across many fish with different meshes and colors.
- **Asset plan:** 20 corals, 30 creatures, 40 decorations, and 1 spawn island for launch. Use the Creator Store for base pieces only where licensing allows, and custom-make anything that defines the look.

**Audio**

- Soft ambient ocean loop, a distinct soft chime for each rarity, and a satisfying "pop" on harvest.
- Keep music optional and low volume, with a mute toggle.

**UI**

- Five buttons on screen at most: Shop, Collection, Friends, Settings, Daily Goals.
- Large touch targets (at least 48 px), and a layout that respects phone safe areas.
- Clear timers on every coral, plus a "ready" sparkle so players can spot what to collect.
- Test on a small phone, a large phone, a tablet, and a PC before each release.

## Launch and growth plan

Roblox discovery depends on how well players engage, so the plan is to earn good numbers with a small audience first, then scale.

**Discovery levers**

- **Thumbnail and icon:** test 3 to 5 versions during soft launch and keep the one with the best click-through rate.
- **Title and description:** short, clear, and searchable (for example, "grow a coral reef").
- **Retention:** day-1 and day-7 retention drive recommendations more than raw visits, so early tuning matters.
- **Group play:** shared bonuses give players a reason to invite friends, which the platform tends to reward.

**Launch steps**

1. **Private playtest (week 10):** 10 to 20 players from friends and family, focused on whether the first 5 minutes make sense.
2. **Soft launch (weeks 12–13):** publish publicly with low promotion. Watch retention, session length, and crash rates.
3. **Fix and tune (weeks 13–14):** act on the data before spending effort on promotion.
4. **Public launch (week 15):** a launch event with a limited reward, plus creator outreach.
5. **Sustain (week 16 onward):** follow the live ops calendar.

**Creator and community**

- Short clips of reef reveals and rare creature spawns suit TikTok, Shorts, and Reels.
- Offer small Roblox creators an early code or a free exclusive coral to try the game. Follow Roblox's rules for paid promotion and disclosure.
- Start a Discord or Roblox community group, and post update notes and upcoming events there.
- Add in-game codes for community milestones (for example, at 1,000 group members).

## Metrics and go/no-go thresholds

Track a small set of numbers from the first playtest. The thresholds are working targets to tighten once real data arrives, and they drive the decision to keep investing.

| Metric | Where to read it | Soft-launch target | Red flag |
|---|---|---|---|
| Day-1 retention | Creator Hub analytics | 30% or higher | Below 15% |
| Day-7 retention | Creator Hub analytics | 10% or higher | Below 4% |
| Average session length | Creator Hub analytics | 8 minutes or more | Under 4 minutes |
| Tutorial completion | Custom event log | 80% or higher | Below 60% |
| Friend invites per player | Custom event log | 0.3 or higher | Under 0.1 |
| Payer conversion | Creator Hub monetization | 2% or higher | Under 0.5% |
| Crash and error rate | Output logs, custom logging | Under 1% of sessions | Over 3% |
| Mobile share of players | Creator Hub analytics | Expected 60%+, performing well | Mobile retention far below PC |

**Decision rules**

- **Continue and scale:** day-1 at or above 30% and day-7 at or above 10% after the tuning pass.
- **Iterate:** day-1 between 15% and 30%. Fix the first 5 minutes and the return hook, then retest.
- **Pause or pivot:** day-1 below 15% after two tuning rounds. Reuse the systems for a different theme.

**Custom events to log:** tutorial steps, first coral planted, first purchase, first friend visit, each upgrade bought, and session end reason.

## Risks and mitigations

The biggest risk is a crowded genre where a good game still goes unnoticed, so the plan tests cheaply before committing.

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Crowded idle-grow genre, game is overlooked | High | High | Distinct ocean theme, creature-condition puzzle layer, early thumbnail testing |
| Weak retention after day 1 | Medium | High | Strong return hook, daily goals, tune the first 5 minutes before any promotion |
| Economy breaks (too fast or too slow) | Medium | Medium | Simulation first, server-side tuning values that can change without an update |
| Data loss from saving bugs | Low | High | DataStore retries, session locking, backups, and careful testing before launch |
| Exploits and cheating (auto-click, duplication) | Medium | High | All currency and growth logic on the server, rate limits, trade protections |
| Scope creep delays launch | High | Medium | Fixed launch scope, post-launch list for extras, weekly check against the roadmap |
| Looking too similar to an existing hit | Medium | Medium | Original mechanics and art, no copied names, assets, or layouts |
| Mobile performance problems | Medium | Medium | Limit part counts, stream content in, and test on a low-end phone early |
| Team burnout on live updates | Medium | Medium | Reusable content templates, a 2-week cadence, and a buffer of finished content |

## Safety, compliance, and next steps

Most players are children, so safety and policy compliance are part of the design, not an afterthought. Check Roblox's current Community Standards, monetization, and advertising rules before launch, since they change.

- Use Roblox's text filtering for all player-visible text.
- Fill out the age and content questionnaire honestly.
- Avoid misleading purchase prompts, and show prices clearly.
- Do not copy names, art, or mechanics from existing games. Use original assets or properly licensed ones.
- Keep trading and gifting protected against scams, with clear limits.
- Publish a short in-game note on how to report a player or a bug.

**Next steps (this week)**

- [ ] Pick the final game name and check it is not taken
- [ ] Install Roblox Studio and build a one-coral prototype — *scaffolded in this repo, see README*
- [ ] Build the economy model and simulate the first 7 days — *see `tools/economy_sim.py`*
- [ ] Sketch the spawn island and first-session screens
- [ ] Decide solo or team, and list the skills missing (art, scripting, UI)

## Sources

The market data came from web search results on 2026-09-30, and the pages were not opened in full, so treat the figures as approximate.

- Grow a Garden, Wikipedia
- 2025 Roblox Annual Review, RoLearn
- Most Popular Roblox Game Genres in 2026, Kitsblox
- Roblox Charts 2026, Ejaw
- Top Roblox Games August 2026, StudioKrew
