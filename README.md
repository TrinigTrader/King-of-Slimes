# King of Slimes

A Roblox slime-collecting simulator. Run into zones, collect orbs before the
zone monster catches you, then sell them for Coins or feed them to your
partner slime to make it grow. Find wild eggs, hatch new slimes, and upgrade
your shoes to reach faster zones.

## First-time setup (Windows or Mac)

1. Install [Roblox Studio](https://create.roblox.com/landing) and sign in.
2. Install [Rokit](https://github.com/rojo-rbx/rokit) (the toolchain manager), then in this folder run:
   ```
   rokit install
   ```
   This installs Rojo, Selene, StyLua and luau-lsp at the versions in `rokit.toml`.
3. Install the Rojo plugin for Studio:
   ```
   rojo plugin install
   ```

## Playing it in Studio

1. In this folder run `rojo serve`.
2. Open Roblox Studio, create a new **Baseplate** place, and **delete the Baseplate part** (the game builds its own map).
3. In the **Plugins** tab click **Rojo**, then **Connect**. The code appears in Studio.
4. Press **Play**.

To test saving in Studio, publish the place and turn on
**Game Settings > Security > Enable Studio Access to API Services**.
Without it the game still runs, but progress does not save (you'll see a message).

### Studio test commands (type in chat, Studio only)

- `/coins 5000`: give Coins
- `/maxupgrades`: max every upgrade
- `/egg Canyon`: carry an egg (`Meadow`, `Cavern`, `Canyon`)
- `/hatchnow`: finish all incubating eggs

## How the game works (MVP)

- **Hub:** 6 fenced plots (one per player), the Sell pad and the Upgrade Shop.
- **Zones:** Dewdrop Meadow, Glowmoss Caverns, Cinder Canyon. Each has a monster that chases you, slightly slower than the zone's recommended speed. The glowing strip at each zone entrance is safe.
- **Caught?** You drop 30% of your backpack orbs (anyone can grab them) and any egg you carry, and go back to the zone gate.
- **Orbs:** fill your backpack, then **Sell** at the hub or **Feed** your partner at your plot's bowl.
- **Slimes:** your partner follows you and gives a bonus (pickup range, backpack, sell price, monster slow or speed). Other slimes wander in your pen and earn Coins.
- **Eggs:** pick up a wild egg in a zone, carry it home to your incubator, wait, then use the incubator again to hatch it.
- **Shop:** Shoes (speed), Backpack, Pen size and Incubators.

## Code layout

- `src/shared` (ReplicatedStorage.Shared): types, config tables, pure formulas, remotes, map layout
- `src/server` (ServerScriptService.Server): server-authoritative systems in `Systems/`, helpers in `Modules/`
- `src/client` (StarterPlayerScripts.Client): HUD, shop and slimes UI
- `tests/`: unit tests for the pure formulas

All gameplay values (zones, slimes, eggs, upgrade prices) live in `src/shared/Config`.

## Checks

```
stylua src            # format
selene src            # lint
luau tests/Formulas.spec.luau   # unit tests (Luau CLI)
```

CI runs formatting, lint, a strict Luau type check and the unit tests on every pull request.
