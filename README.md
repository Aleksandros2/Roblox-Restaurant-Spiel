# Food Truck Frenzy: Viral Kitchen

Playable MVP for a Roblox multiplayer food truck simulator built with Rojo and Luau. Players select trendy recipes, prepare steps at festival stations, serve customers, earn Money and ViralPoints, and buy simple upgrades. Trend foods pay double, influencer orders pay triple, and influencer success starts a temporary Viral Rush.

## Setup

Build the place from scratch:

```bash
rojo build -o "RobloxRojoSync.rbxlx"
```

Open the place in Roblox Studio and run:

```bash
rojo serve
```

Then connect Studio to the Rojo server. The project creates required remotes through `default.project.json`; `Main.server.luau` also creates any missing remotes and a fallback festival map at runtime.

## Testing In Studio

1. Press Play.
2. Confirm `Workspace.FoodTruck` appears with Counter, IngredientStation, CookingStation, DrinkStation, UpgradeStation, queue pads, and prompts.
3. Select a recipe in the UI.
4. Use the matching stations in step order.
5. Select a customer and use the Counter prompt or Serve Selected button.
6. Check Money and ViralPoints leaderstats after correct serves.
7. Serve the current Trend of the Day to confirm 2x rewards.
8. Serve an Influencer to confirm 3x rewards and Viral Rush.
9. Buy upgrades after earning enough Money.

## Architecture

Rojo maps the project into standard Roblox services:

- `src/shared` -> `ReplicatedStorage.Shared`
- `src/server` -> `ServerScriptService`
- `src/client/Main.client.luau` -> `StarterGui.FoodTruckGui.Main`

The server is authoritative for recipe progress, customer state, rewards, trend selection, influencer rewards, Viral Rush, and upgrades. The client only renders UI and sends request payloads.

## Services

- `PlayerDataService`: Creates leaderstats, stores session upgrade levels, adds/spends currency.
- `TrendService`: Chooses a random trend every 300 seconds and sends it to clients.
- `RecipeService`: Validates recipe IDs, step order, station type, and dish completion.
- `CustomerService`: Spawns customer NPC placeholders, times out customers, validates serving, calculates rewards.
- `UpgradeService`: Validates and purchases FasterCooking, BetterMarketing, and BiggerCounter.
- `ViralRushService`: Starts and ends global Viral Rush after influencer serves.
- `Main.server.lua`: Ensures remotes, creates fallback map, initializes services.

## RemoteEvents

- `TrendChanged`
- `DishStateChanged`
- `CustomerSpawned`
- `CustomerRemoved`
- `ServeRequest`
- `StartRecipeRequest`
- `AddRecipeStepRequest`
- `UpgradeRequest`
- `NotificationEvent`
- `ViralRushChanged`

## Gameplay Notes

- Recipe IDs are exactly `SpicyRamen`, `BubbleTea`, and `KoreanCornDog`.
- Wrong orders give no reward. The completed dish is discarded, but the customer stays in line for another attempt.
- BetterMarketing adds ViralPoints after trend/influencer multipliers.
- BiggerCounter uses the highest active player level to reduce the global customer spawn interval.
- FasterCooking reduces the server-side station step cooldown.

## Known Limitations

- Data is session-only; no DataStore persistence yet.
- Customer NPCs are simple anchored placeholders.
- The queue is capped at three active customers for MVP clarity.
- Upgrade levels are shown locally after successful purchase notifications rather than through a dedicated upgrade-state remote.
- Viral Rush is global for the whole server.
