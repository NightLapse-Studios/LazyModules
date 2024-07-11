# Full release

The "development environment" we use at NLS for starting all our games.

Supplies minimal + base functionality as well as:
* __ui stage
  * Packages Pumpkin, our Roact wrapper, but still lets you use Roact by simply bypassing Pumpkin
* __get_gamestate (server) & __load_gamestate (client) stages
  * On player join, __get_gamestate is used to acquire state from collected server modules registering the event. The collected state is then passed to the associated module on the client. Order of __load_gamestate can be customized on the client.
* Loading sequence for DataStores associated with players
  * The specifics can be found in `src/full/Modules/Players`
  * An invasive change, but a good one in our opinion, the client will not finish the startup process until the server has loaded a `PlayerDataModule` and the associated data has been loaded on the client.
  * The mock `PlayerDataModule` is called `Stats`, as in "player-specific stats" like in an RPG. Keeping it in sync across clients/server is easy but is a task left up to the user for now.
* Player object which is accessible via `Game[<plr>]` on client and server, it should contain all `PlayerDataModule`s but does not have to
* Debug menu & library
  * The menu lets you easily register input boxes or sliders to bind to runtime constructs, making it easy to adjust parameters of behavior at runtime
  * Debug Library provides functions such as `TempMarkSpot`, `DebugModelAxis`, `VisualizeCFrame`, `DebugHighlight`, `VisualizePlane`, and some more.
* An expression parsing library for text input at runtime