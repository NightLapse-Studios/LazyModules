# Base release

Supplies minimal functionality as well as:
* __ui stage
  * Packages Pumpkin, our Roact wrapper, but still lets you use Roact by simply bypassing Pumpkin
* Debug menu & library
  * The menu lets you easily register input boxes or sliders to bind to runtime constructs, making it easy to adjust parameters of behavior at runtime
  * Debug Library provides functions such as `TempMarkSpot`, `DebugModelAxis`, `VisualizeCFrame`, `DebugHighlight`, `VisualizePlane`, and some more.
* An expression parsing library for text input at runtime* Lib/UserInput