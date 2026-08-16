# PrivateAgent

PrivateAgent is an open-source Android automation agent built with Flutter. It utilizes the OpenRouter API and native Android Accessibility Services to interpret screen layouts and execute multi-step tasks across any installed application via natural language commands.

## Architecture

The system operates on a continuous feedback loop:
1. The user issues a command (via voice, text, or Telegram remote access).
2. The agent captures the current screen hierarchy, calculating the exact spatial coordinates of all interactive elements.
3. The layout data is transmitted to the AI provider alongside the current task context and the result of the previous action.
4. The AI determines the next optimal action (e.g., clicking specific coordinates, inputting text, scrolling).
5. The native Android layer executes the action.
6. The loop repeats until the task is marked as complete.

## Capabilities

- **Screen Reading:** Parses the Android UI tree to map clickable, scrollable, and editable elements.
- **Coordinate-Based Interaction:** Simulates physical screen taps based on coordinate geometry, mitigating issues with missing text labels or inaccessible icons.
- **Remote Access:** Integrates with the Telegram Bot API via background polling, allowing users to issue commands and monitor task execution progress remotely.
- **Voice Control:** Native speech-to-text integration for hands-free operation.

## Installation

Download the latest APK directly from the [Releases Page](https://github.com/orailnoor/private-agent/releases).

Choose `app-universal-release.apk` when it is available. It supports ARM64,
32-bit ARM, and x86_64 devices in one package. If a release only provides split
APKs, most modern Android phones—including Snapdragon devices—must use
`app-arm64-v8a-release.apk`.

PrivateAgent supports Android 8.0 (API 26) and newer. Current release builds are
also checked for Android 15/16's 16 KB native-library alignment requirement.

## Setup Instructions

This app requires an AI brain to operate. The AI engine is **preconfigured to
use OpenRouter** — there is no API key or Base URL to enter in the app. The
API key is embedded at build time from the `OPENROUTER_API_KEY` GitHub secret.

### Building with your OpenRouter key

1. Go to [OpenRouter.ai](https://openrouter.ai/) and create a free account.
2. Generate an API key.
3. In your GitHub repository, add it as a repository **Secret** named `OPENROUTER_API_KEY`
   (Settings → Secrets and variables → Actions → New repository secret).
4. Trigger the **"Android release artifacts"** workflow (or push a `v*` tag).
   The built APK already contains your key — no manual configuration needed.

To build locally with your key:

```bash
flutter build apk --release --dart-define=OPENROUTER_API_KEY="sk-or-..."
```

### Using the app

1. Install the APK on your Android device (API 30+ recommended).
2. Launch PrivateAgent and complete the quick onboarding (Welcome + Permissions).
3. The default model is `nvidia/nemotron-nano-12b-v2-vl:free`. You can switch
   it at any time in **Settings → AI Model** — the quick-select chips list the
   three supported free OpenRouter models (you can still type any other model
   ID manually).
4. Enable the **"PrivateAgent Screen Control"** service in your Android Accessibility Settings.

> **Note:** Because the key is compiled into the APK, anyone who has the APK
> can extract it. Do not distribute APKs built with your personal key.

### “Restricted setting” when enabling Screen Control

Android may block accessibility access for apps installed from an APK. This is
an operating-system safety restriction:

1. Open **Settings → Apps → PrivateAgent**.
2. Open the three-dot menu in the top-right corner.
3. Tap **Allow restricted settings** and confirm.
4. Return to PrivateAgent and open **Accessibility Settings** again.
5. Enable **PrivateAgent Screen Control**.

PrivateAgent now shows these instructions and provides shortcuts to both App
Info and Accessibility Settings during onboarding.

## Telegram Integration

To enable remote access:
1. Acquire a bot token from BotFather on Telegram.
2. Input the token in the PrivateAgent Settings screen and enable the integration toggle.
3. The application will maintain a background polling connection to the Telegram API to receive commands.

## License

This project is open-source and available for modification.
