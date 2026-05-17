# QuickTasks ⚡️

QuickTasks is a lightning-fast macOS menu bar application designed to let you create Jira Data Center tasks instantly from anywhere on your Mac. Instead of breaking your flow to open a browser, navigate to Jira, and fill out a slow form, you can simply press a global hotkey, type your task, and get back to work.

![QuickTasks Menu Bar App](.agents/artifacts/quicktasks_app_icon_1778953989360.png) <!-- Update with actual screenshot if desired -->

## Features 🚀

- **Always Available:** Lives in your macOS menu bar. Summon the Quick Entry panel globally from any application using a customizable hotkey (default: `⌥⌘J`).
- **Offline Queueing:** If your network goes down or you're on a flight, QuickTasks queues your tasks locally using SwiftData and automatically pushes them to Jira as soon as your connection is restored.
- **Smart Inline Commands:** Override default project settings on the fly using intuitive slash and mention commands.
  - `/PROJECTKEY` to specify a Jira project (e.g., `/EA`, `/INFRA`)
  - `/bug`, `/story`, `/task`, `/subtask` to override the issue type
  - `@username` to assign the ticket directly to someone
- **Native & Lightweight:** Built entirely in Swift & SwiftUI for macOS 14+. No Electron, no web views, zero bloat.
- **Secure:** Stores your Jira Personal Access Token (PAT) securely inside the macOS Keychain.

---

## Installation 💾

### Prerequisites
- macOS 14.0 or later
- Xcode 16.0 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (can be installed via Homebrew: `brew install xcodegen`)

### Building from Source
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/QuickTasks.git
   cd QuickTasks
   ```
2. Generate the Xcode project using XcodeGen:
   ```bash
   xcodegen generate
   ```
3. Open `QuickTasks.xcodeproj` in Xcode.
4. Select the **QuickTasks** scheme and your Mac as the destination.
5. To install locally on your Mac:
   - Go to **Product** → **Archive** in the Xcode menu bar.
   - Once archived, click **Distribute App** in the Organizer window.
   - Choose **Custom** → **Copy App**, pick a location (like your Desktop), and click **Export**.
   - Drag the exported `QuickTasks.app` into your Mac's `/Applications` folder.
   - Run it from Applications and optionally add it to your Login Items (System Settings → General → Login Items) so it starts with your Mac.

---

## Configuration ⚙️

When you first launch QuickTasks, you'll see a lightning bolt (`⚡️`) in your macOS menu bar. Click it and select **Settings** (or use the `⌥⌘K` shortcut while the menu is open).

### 1. Jira Credentials
- **Jira Base URL:** Enter your company's Jira Data Center URL (e.g., `https://jira.yourcompany.com`).
- **Personal Access Token:** Go to your Jira Profile → Personal Access Tokens and generate a new token. Paste it here.
- Your credentials are automatically saved as you type.

### 2. Defaults
Set up your default behavior for quick task entry:
- **Project Keys:** Add the short project keys you frequently use (e.g., `EA`, `INFRA`). Note: This must be the short prefix used in Jira issue numbers (like `EA-123`), not the full project name. Click one to set it as your default.
- **Default Issue Type:** Choose between Task, Story, Bug, or Sub-task.
- **Assignee:** Choose whether tasks default to you, or set a custom default username.

---

## Usage 📝

1. Press `⌥⌘J` anywhere on your Mac to summon the Quick Entry panel.
2. Type your task summary. 
3. (Optional) Use inline commands to route the task to a specific place or person:
   ```text
   Fix the database connection leak /INFRA /bug @john.doe
   ```
   *In the example above, QuickTasks will create a "Bug" in the "INFRA" project assigned to "john.doe" with the title "Fix the database connection leak".*
4. Press `Enter` to submit. The window immediately disappears so you can resume your work. QuickTasks handles the API request in the background and will send you a macOS Notification upon success (or failure).

---

## Technology Stack 🛠

- **UI Framework:** SwiftUI
- **Architecture:** MVVM (Model-View-ViewModel)
- **Local Database:** SwiftData (Offline Queueing)
- **Networking:** Native `URLSession` actor
- **Dependencies:** `KeyboardShortcuts` (for global hotkey registration)

## License
Copyright © 2026 Malidya Tech. All rights reserved.
