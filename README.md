# Radio Unbound Menubar

A simple macOS menu bar app that shows the currently playing track on **Radio Unbound** and allows in-app streaming without opening a browser or external player.

Built as a personal hobby project.

---

## Features

- Displays current **Title — Artist** in the macOS menu bar  
- Polls the Live365 API every 30 seconds  
- Detects stale metadata and indicates when a song has ended but new data hasn’t arrived yet  
- Built-in audio streaming (HLS with MP3 fallback)  
- Volume control  
- Copy current track info to clipboard  
- Runs as a menu bar–only app (no Dock icon)  
- Works on both Intel and Apple Silicon Macs  

---

## Requirements

- macOS 12.0 (Monterey) or newer  
- Intel or Apple Silicon Mac  

---

## Installation

1. Download the latest release from the **Releases** section.
2. Unzip the file.
3. Drag `Radio Unbound Menubar.app` into your **Applications** folder.
4. Right-click the app and choose **Open**.
5. Click **Open** again in the confirmation dialog.

After the first launch, you can open it normally.

---

## Important: About Code Signing

This app is **self-signed** and not notarized through the Apple Developer Program.

I am a hobbyist developer and do not currently pay for Apple’s $99/year Developer ID program. Because of this:

- macOS will display a warning the first time you open the app.
- You may need to right-click → Open the first time.
- In some cases, you may need to allow it in:
  - System Settings → Privacy & Security → “Open Anyway”

If you are uncomfortable running a self-signed app, you are encouraged to:

- Review the source code in this repository  
- Build the app yourself in Xcode  

The full source code is included here for transparency.

---

## Launch at Login

To start the app automatically when you log in:

1. Open **System Settings**
2. Go to **General → Login Items**
3. Under “Open at Login”, click **+**
4. Select `Radio Unbound Menubar.app`

---

## Building from Source

1. Clone the repository:
`git clone https://github.com/yourusername/radio-unbound-menubar.git`
2. Open the `.xcodeproj` file in Xcode.
3. Ensure:
   - Deployment Target is set to macOS 12.0 or newer.
   - Architectures are set to Standard (Intel + Apple Silicon).
4. Press Run.

No paid Apple Developer account is required to build and run locally.

---

## How It Works

The app polls:
`https://api.live365.com/station/a94197`

It reads the `current-track` object and displays:
`Now Playing on Radio Unbound: Artist - Title`

If the track’s expected end time has passed and the API has not updated yet, it displays:
`Song ended at {time}. Awaiting new data.`

Streaming is handled internally using AVFoundation.

---

## License

MIT License (see LICENSE file).

---

## Disclaimer

This project is not affiliated with Radio Unbound or Live365.  
It is an independent hobby project created for personal use.


