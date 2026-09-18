# AGENTS.md — Burmalgram Project Context & Guidelines

This document provides complete instructions and architectural context for AI assistants and CLI tools working on the **Burmalgram** project.

---

## 1. Project Overview

- **App Name**: Burmalgram (`Burmalgram`)
- **Bundle Identifier**: `org.burmalgram.Telegram`
- **Base Version**: Telegram-iOS v12.9.2 (build 3731) / Swiftgram fork base
- **Architecture**: Modular iOS application written in Swift and Objective-C, compiled with **Bazel**.
- **Host Environment**: Windows 11 (PowerShell / `pwsh`). Local compilation is not supported on Windows; all builds run via **GitHub Actions** on macOS runners.
- **Root Directories**:
  - Workspace Root: `c:\Users\dmitr\Desktop\burmalgramm`
  - Source Repository: `c:\Users\dmitr\Desktop\burmalgramm\burmalgram-src`
  - Output IPA: `c:\Users\dmitr\Desktop\burmalgramm\Burmalgram.ipa`

---

## 2. Git & CI/CD Infrastructure

- **Remote URL**: `https://github.com/dimonchik235/burmalgram.git`
- **Default Branch**: `main`
- **GitHub Token**: Use `$env:GH_TOKEN` or personal access token with `repo` and `workflow` scopes.
- **CI Pipeline**: `.github/workflows/build.yml` runs on `macos-14` with Xcode 15.4.
  - Automatically triggered on `push` to `main` or manual `workflow_dispatch`.
  - Takes ~12–15 minutes to compile and link via Bazel with caching.
  - Uploads artifacts and updates the GitHub Release tag `v12.9.2-b3731`.
  - Download URL: `https://github.com/dimonchik235/burmalgram/releases/download/v12.9.2-b3731/Burmalgram.ipa`

---

## 3. Critical Architectural Invariants (DO NOT BREAK)

### A. MTProto API ID Validation & Bundle ID Spoofing
- **File**: `submodules/BuildConfig/Sources/BuildConfig.m` (around line 139)
- **Invariant**:
  ```objc
  if (baseAppBundleId != nil) {
      _dataDict[@"bundleId"] = @"ph.telegra.Telegraph";
  }
  ```
- **Why this is critical**: Telegram MTProto backend strictly verifies that `api_id: 8` is sent with `bundleId: "ph.telegra.Telegraph"`. If `_dataDict[@"bundleId"]` is set to `org.burmalgram.Telegram`, Telegram's servers reject auth requests or silently hang, producing the error: *"нет инета проверь инет или попробуй прокси"*.

### B. Configuration Profile
- **File**: `build-system/burmalgram-configuration.json`
- **Invariant**:
  - `"bundle_id": "org.burmalgram.Telegram"`
  - `"app_name": "Burmalgram"`
  - `"is_appstore_build": "true"` (prevents hanging on missing Firebase tokens in non-AppStore environments)

### C. Authorization & Push Timeouts
- **File**: `submodules/TelegramCore/Sources/Authorization.swift`
- **Invariants**:
  - Network timeout on `account.network.request(Api.functions.auth.sendCode(...))` is set to `60.0` seconds (to prevent premature client aborts).
  - In `sendAuthorizationCodeVerificationPush`, Firebase push token timeout is capped: `min(pushTimeout ?? 15, 2)` seconds.

### D. Payment Flow & Auth Codes
- **Files**: `submodules/TelegramCore/Sources/Authorization.swift` and `submodules/AuthorizationUI/Sources/AuthorizationSequenceController.swift`
- **Invariant**: When Telegram returns `sentCodePaymentRequired`, it MUST transition to `.payment(...)` and show `AuthorizationSequencePaymentController`. Do NOT spoof it into `.confirmationCodeEntry(.otherSession(length: 5))` — Telegram backend DOES NOT issue a code when payment is required, and spoofing leaves the client awaiting a code that is never sent.

---

## 4. Key File Map

| Path | Purpose |
|---|---|
| `build-system/burmalgram-configuration.json` | Core build definitions (bundle_id, app_name, build flags) |
| `.github/workflows/build.yml` | GitHub Actions CI build & release workflow |
| `submodules/BuildConfig/Sources/BuildConfig.m` | Client configuration, system code, MTProto bundleId spoofing |
| `submodules/TelegramCore/Sources/Authorization.swift` | MTProto authorization logic, sendCode, resend, push handling |
| `submodules/AuthorizationUI/Sources/AuthorizationSequenceController.swift` | Navigation and screen flow controller for authorization |
| `submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryController.swift` | Phone number entry screen |
| `submodules/AuthorizationUI/Sources/AuthorizationSequenceCodeEntryController.swift` | Code input screen |
| `submodules/AuthorizationUI/Sources/AuthorizationSequencePaymentController.swift` | Login fee / payment screen |

---

## 5. Standard CLI Workflows

### 1. Committing and Pushing Changes
```powershell
cd c:\Users\dmitr\Desktop\burmalgramm\burmalgram-src
git add <files>
git commit -m "Commit message"
# Using GitHub CLI or access token:
git push origin main
# or:
git push "https://x-access-token:$env:GH_TOKEN@github.com/dimonchik235/burmalgram.git" main
```

### 2. Checking GitHub Actions Build Status
```powershell
$headers = @{ "Authorization" = "token $env:GH_TOKEN"; "Accept" = "application/vnd.github.v3+json" }
$runs = Invoke-RestMethod -Uri "https://api.github.com/repos/dimonchik235/burmalgram/actions/runs?per_page=1" -Headers $headers
$runs.workflow_runs | Select-Object id, name, status, conclusion, html_url
```

### 3. Downloading Fresh `Burmalgram.ipa` to Desktop
```powershell
$headers = @{ "Authorization" = "token $env:GH_TOKEN"; "Accept" = "application/vnd.github.v3+json" }
$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/dimonchik235/burmalgram/releases/tags/v12.9.2-b3731" -Headers $headers
$assetId = $rel.assets[0].id
curl.exe -L -H "Authorization: token $env:GH_TOKEN" -H "Accept: application/octet-stream" -o "c:\Users\dmitr\Desktop\burmalgramm\Burmalgram.ipa" "https://api.github.com/repos/dimonchik235/burmalgram/releases/assets/$assetId"
```

### 4. Verifying Downloaded IPA
```powershell
tar -xOf "c:\Users\dmitr\Desktop\burmalgramm\Burmalgram.ipa" Payload/Burmalgram.app/Info.plist | Select-String -Pattern "CFBundleIdentifier|CFBundleDisplayName"
```