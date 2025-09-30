# Bee Hive — Design Doc (Rev B)

## Core Loop

- Pick 1 of 3 Queen cards → place Queen Seat (center).
- Expand with Specialized Cells; form Complexes (contiguous same-type groups).
- Run Harvests/Item Quests via Gathering Huts; brew at Honey Vats; build Wax Workshops; generate Defense with Guard Posts.
- Candle Halls auto-create single-use Abilities.
- Brood forms by enclosure; hatch bees via trait draft.
- Survive threats and the boss.

## Controls (keyboard/controller only)

- Arrows = move | Space = confirm/context | Z = cancel/back | Tab/Start = panels. No mouse.

## Grid & Complexes

- Hex, flat-topped, axial (q,r).
- Complex = contiguous same-type Specialized Cells (visual shared outline).
- The old generic “−0.5s per neighbor” rule is removed.

## Resources & Items

- Resources (cap-limited): Honey, Comb, Pollen, three Nectar grades (Common/Sweet/Rich), and six Petal colors (White/Pink/Yellow/Red/Blue/Purple).
- Items (inventory): RoyalJelly (RJ). (Eggs are a hidden Queen counter, not items.)

## Queen

- Base eggs: lays +1 egg every 20/19/18/17/16s (tiers 1→5).
- Tiers: unlocked by spending Royal Jelly (T2..T5 costs 1/2/3/4 RJ).
- Queen cards (total 3, no duplicates): offered 3, pick 1 at run start and on each tier-up.
  - RareBias20 (+20% rare-family bias)
  - ExtraDraftCard (+1 draft card)
  - PickTwo (pick 2 traits)
- HUD shows a small egg counter.

## Brood (enclosure system)

- Create: Any void hex fully enclosed by Specialized cells becomes Brood (no build cost/menu).
- Eggs: Auto-assigned 1:1 from Queen’s pool when available; hatch timer starts.
- Hatch: 10s (configurable). On finish, cell shows READY until player selects → Trait Draft.
- Draft: 3 cards base; +1 if you have the Queen card; Pick 2 if you have that card.
- Neighbor influence (edges only):
  - Guard Post → Guard
  - Gathering Hut → Gather
  - Wax → Construction
  - Honey Vat → Brewer
  - Candle Hall → Arcanist
- If ≥2 distinct families present, 50% chance the draft restricts to those families.
- Break enclosure (future-proof): Brood → Damaged, egg lost.
- Repair Damaged → not needed here (Damaged arises only from enclosure break; repair rules can reuse global repair if later added).
- Config:

```json
{ "Brood": { "hatch_seconds": 10, "mixed_neighbors_restrict_chance": 0.5 } }
```

## Wax Workshop

- Build: 2 Comb + 10 Pollen.
- Bee cap: 1/cell.
- Tick: every 5s, 2 Pollen → 1 Comb per cell.
- Merge: output × (1 + 0.6·(size−1)) per complex.
- Adjacency (same type): +10% output per adjacent Wax edge (both sides benefit).
- Trait – Construction: +5% output per Construction bee assigned anywhere in that Wax complex (no cap).

## Honey Vat

- Build: 2 Comb + 5 Nectar.
- Bee cap: 1/cell.
- Batch: 2 Nectar → 1 Honey.
- Batch time (complex trade-off): 5s + 1s × (complex_size−1).
- Local buffer: +5 Honey × complex_size (adds to caps from Storage; used to hold short bursts).
- Purity → Royal Jelly (per complex):
  - +1 Purity per batch;
  - +10 more per batch if any Vat tile touches a Candle Hall;
  - at 100 Purity ⇒ +1 RJ, reset to 0.

## Storage (cell-scoped caps)

- Build: 1 Comb.
- Each Storage edge gives +5 capacity to the linked resource(s) of the adjacent producer:
  - Wax → Comb;
  - Vat → Honey;
  - Gathering Hut → Pollen and Nectar.
- Total cap per resource = sum of all linked per-cell caps across producers.
- Overflow: Production/harvest continues; overflow is binned (no pause).

## Gathering Hut (offers, auto-routing, virtual bees)

- Build: 2 Comb + 10 Honey.
- No passive output. Used to run Harvests and Item Quests.
- Offer slots: base 2 Harvest + 2 Item Quests, then +1 of each per extra Hut complex.
- Start job UX: player selects an offer; system auto-picks the smallest eligible Hut complex, ties → earliest built.
- Complex reservation: chosen complex is reserved for that job; different jobs need different complexes.
- Virtual bees: +⌊complex_size / 2⌋ bees to requirement (min 0 workers after virtuals).
- Trickle: 5% delay then even/sec; overflow binned.
- No manual override of auto pick.

## Guard Post (per-cell defense, adjacency model)

- Build: 3 Comb + 2 Honey + 5 Pollen.
- Bee cap: 1/cell.
- Tick: every 5s, add floor(1 × (1 + 0.10 × adj_guard_neighbors)) to this cell’s Stored Defense.
- Cap: max(20, 200 − 20 × adj_guard_neighbors) per cell.
- Global Defense: sum of all Stored Defense values (no decay).

## Candle Hall (auto rituals)

- Build: 1 Comb + 1 Honey + 1 Pollen (configurable).
- Bee cap: 1/cell (required).
- Rituals: automatic every 20s, no cost; each interval adds 1 random single-use ability to a shared list.
- Adjacency A (Hall↔Hall): if touching ≥1 Hall, ritual interval −5s (floor 10s, does not stack).
- Adjacency B (diversity): +4% rare-ability chance per unique non-Hall neighbor type (Wax, Vat, Guard, Gathering, Storage, Brood, QueenSeat).

## Abilities (single-use)

- Listed in Abilities Panel (right slide).
- Each shows costs (resources/items) and effect; Space to activate → pay → effect applies immediately → ability consumed.
- Example effects: Honey +50% for 10s, Summon Common Bee, Replenish active harvest +50%.

## Threats & Boss

- Regular threats: 1:00 warning, 3:00 min gap, power ×2 on each reappearance (per ID). Single resolve: Global Defense ≥ Threat Power → defend; else loss.
- Boss: 30:00 cap, 3:00 warning, phases 1000 / 1300 / 1700 one minute apart.
- Resolve UI: bottom panel slides up, shows DEFENDED/DESTROYED, Defense vs Power, previews next threat (name + countdown), slides down.

## Panels / UI

- Panels: Resources, Inventory (items), Abilities, Offers — slide from right; arrows to navigate; Space confirm; Z close.
- Assign Bee: stylized list; 1 bee per cell limit; shows trait chips.
- Tooltips: show per-cell caps, complex size, adjacency bonuses, Purity, Stored/Cap defense, etc.
- HUD: Global Defense, Swarm/Boss timers, Active Jobs cards, Queen egg count.

## Data / JSON (high-level keys)

- `cells.json` — per role costs, caps, adjacency/synergy knobs, timers.
- `queens.json` — [20,19,18,17,16], RJ tier costs.
- `queen_cards.json` — 3 cards (RareBias20, ExtraDraftCard, PickTwo).
- `offers.json` — base slots, per-complex increments, pools, durations, yields.
- `abilities.json` — pool, costs, effects.
- `traits.json` — includes Construction (+5% Wax output per such bee in complex, no cap).
- `storage_linked.json` — maps producer types → linked resources.
- `threats.json`, `boss.json` — timings, powers.

## Acceptance (golden path)

- Building/assignment uses 1 bee/cell across all roles.
- Brood forms only via enclosure; eggs auto-assign; manual hatch + draft.
- Wax/Vat produce per specs; Vat purity outputs RJ; RJ upgrades Queen tiers; Queen cards chosen at start/tier-up.
- Storage caps are adjacent, per-producer; overflow is binned (no pause).
- Gathering offers scale with Hut complexes; auto-routes to the smallest eligible complex; virtual bees apply.
- Guard Posts store defense with adjacency cap/speed; threats/boss resolve against the sum.
- Candle Halls auto-generate abilities; Hall↔Hall and diversity bonuses apply.
