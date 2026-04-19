# ClipList Manager

ClipList Manager is a beautifully polished, ultra-lightweight macOS Menu Bar utility designed to instantly track, manage, and retrieve your clipboard history. Built purely with native SwiftUI and SwiftData, it completely bypasses the macOS Dock and lives quietly in your top Menu Bar.

## ✨ Features
- **Lightning Fast Native UI:** Built entirely in modern SwiftUI for zero lag, optimized memory usage, and native macOS styling.
- **Menu Bar Utility:** Runs completely in the background as an `LSUIElement`. Doesn't clutter your Dock.
- **Smart Pinned Vault:** Pin important clips to permanently protect them from auto-deletion.
- **Auto-Pruning Engine:** Automatically deletes the oldest copied items the exact millisecond your queue exceeds your customized history limit.
- **Deep Customization:** Force Light/Dark modes, toggle Launch at Login, and customize your maximum history capacity effortlessly.
- **Pixel-Perfect Aesthetics:** Features fluid micro-animations, glassmorphic headers, and a premium icon design.

## 🚀 Installation & Usage
1. Download the latest `.dmg` from the Releases page.
2. Drag and drop **ClipList Manager** into your `Applications` folder.
3. Open the app. The paperclip icon will appear in your top right Menu Bar.
4. Copy any text anywhere on your Mac—it will instantly appear in the dropdown!

## 🛠️ Tech Stack
- **Framework:** SwiftUI
- **Database:** SwiftData
- **Architecture:** MVVM, Native App Lifecycle (`NSApplicationDelegate`)
- **Background Logic:** Swift Concurrency (`Task`) for zero-overhead background polling

## 🤝 Contributing
Contributions, issues, and feature requests are welcome! Feel free to check the issues page.

## 📝 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
