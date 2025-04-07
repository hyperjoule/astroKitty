# 🌌 astroKitty
### by hyperjoule for hyLite studios 🐱🚀

**astroKitty** is a cosmic cat-blasting arcade shooter for the [Playdate](https://play.date) handheld console. Pilot your nimble spaceship through deep space and defend yourself from a never-ending swarm of cat-shaped asteroids! 😼💥

---

## 🎮 Gameplay

- Steer your ship using the **crank** or **D-pad**
- Press **B** to fire cosmic blasts!
- Dodge adorable but deadly **cat-asteroids**
- Collect yarn balls for extra points ✨
- Survive long enough to beat your high score!

Each asteroid has a unique kitty face that scales with its size—larger cats sport bigger ears and features. Dodge, blast, and collect yarn as you aim for a new high score!

---

## 🕹 Controls

| Button             | Action                            |
|--------------------|------------------------------------|
| `D-Pad / Crank`    | Rotate the ship                   |
| `Up / Down`        | Thrust forward / backward         |
| `B Button`         | Fire weapon                       |
| `A Button`         | Pause / Unpause / Start game      |

---

## 💾 Installation

To sideload **astroKitty** to your Playdate:

1. **Build the game:**
   - With the [Playdate SDK](https://developer.play.date/), run:
     ```sh
     pdc . astroKitty.pdx
     ```
   - This will generate an `astroKitty.pdx` folder (the game bundle).

2. **Create a ZIP:**
   - On Windows:
     - Right-click `astroKitty.pdx` → "Send to > Compressed (zipped) folder"
   - On Mac/Linux:
     ```sh
     zip -r astroKitty.zip astroKitty.pdx
     ```

3. **Sideload:**
   - Go to [https://play.date/account](https://play.date/account)
   - Upload your `astroKitty.zip`
   - On your Playdate, go to:
     ```
     Settings → Games → Check for Games
     ```

---

## 📝 Project Files

Your project should include the following files and folders:

astroKitty/ ├── main.lua ├── pdxinfo <-- Contains metadata, including icon reference (image=/icon.png) ├── icon.png <-- This image appears as your game icon in the Playdate menu ├── assets/ │ ├── logos/ │ │ └── astrokitty_logo.png │ ├── sounds/ │ │ ├── fire.wav │ │ ├── explosion.wav │ │ └── meow.wav │ └── music/ │ └── music.wav └── README.md

---

## ✨ Features

- Two randomized cat face types 😺
- Procedurally generated asteroid movement with collision physics
- Screen shake and debris explosion effects
- Yarn power-ups 🧶 for bonus points
- Retro vector-style graphics
- Ambient background music and sound effects
- High score saving across sessions

---

## 🧑‍🚀 Credits

Developed with love by **hyperjoule**  
Published by **hyLite studios**

---

**astroKitty** is a tribute to classic space shooters, retro vector graphics, and, of course, our feline friends. Enjoy blasting through cosmic cat chaos! 😽💫
