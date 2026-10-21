# Water Cat 🐈‍⬛💧

A tiny macOS menu-bar app. Every 30 minutes your screens dim and a sassy black cat pops up in the bottom-right corner to remind you to drink water. She stays until you click her.

- She blinks, twitches her ears and whiskers, sways, and follows your mouse with her eyes.
- Clicks on your apps are blocked while she's up. Click **her** to dismiss.
- Around noon (11:30–1:00) and 4pm (3:30–5:00) she comes back more often, at random 10–20 minute gaps.
- The menu bar cat icon shows when she's next due and lets you remind now, pause, or open at login.

## Build

Full step-by-step instructions are in [INSTALL.html](INSTALL.html).

Needs macOS 13+ and the Xcode command line tools.

```bash
bash build.sh
open "build/Water Cat.app" --args --now
```

`--now` makes her appear a second after launch. Copy `build/Water Cat.app` to `/Applications` to keep it, and turn on **Open at Login** from the menu.

## Customise

- `Sources/Messages.swift`: what she says, and the rush-hour schedule
- `Sources/Cat.swift`: her drawing and animations
- `Sources/Overlay.swift`: the dim layer, glow, speech bubble and placement
- `Sources/main.swift`: menu bar and timer
