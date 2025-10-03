# 🖱️ MX MASTER 3S - APP-SPECIFIC PROFILES GUIDE

**Platform:** macOS  
**Software:** Logi Options+ for Mac  
**Mouse:** Logitech MX Master 3S  
**Purpose:** Optimize button mappings per application for forge velocity ⚔️

---

## 📋 PROFILE STRATEGY

### Core Profiles to Create:
1. **VS Code** - Command palette, explorer, terminal
2. **Terminal.app/iTerm2** - Directory navigation, tab switching
3. **Browser (Chrome/Firefox)** - Tab management, navigation
4. **Default** - Standard macOS gestures

---

## 🎯 PROFILE 1: VISUAL STUDIO CODE

**Application Path:** `/Applications/Visual Studio Code.app`

### Button Configuration:

| Button | Action | Keystroke | Purpose |
|--------|--------|-----------|---------|
| **Thumb Forward** | Command Palette | `Cmd+Shift+P` | Access all commands |
| **Thumb Back** | File Explorer | `Cmd+Shift+E` | Show project sidebar |
| **Gesture Button** | Toggle Terminal | `Cmd+J` | Terminal panel on/off |
| **Top Button** | Workspace Switcher | `Cmd+K` then `Cmd+O` | Switch projects |
| **Thumb Wheel Left** | Previous Tab | `Cmd+Shift+[` | Navigate tabs |
| **Thumb Wheel Right** | Next Tab | `Cmd+Shift+]` | Navigate tabs |
| **Scroll Wheel Tilt Left** | Search in Files | `Cmd+Shift+F` | Global search |
| **Scroll Wheel Tilt Right** | Git Panel | `Cmd+Shift+G` | Source control |

### Setup in Logi Options+:
```
1. Open Logi Options+
2. Click "Applications" tab
3. Click "+ Add Application"
4. Navigate to /Applications/Visual Studio Code.app
5. Select and click "Open"
6. Configure each button using "Customize Buttons"
7. For Thumb Forward: Click → "Keystroke Assignment" → Press Cmd+Shift+P
8. For Gesture Button: Click → "Keystroke Assignment" → Press Cmd+J
9. Repeat for all buttons
10. Click "Save"
```

### Advanced VS Code Mappings:
```
OPTIONAL ALTERNATIVES:

Top Button → Project Manager
- Keystroke: Cmd+Shift+P then type "project"
- Requires: Project Manager extension

Gesture Button → Zen Mode
- Keystroke: Cmd+K then Z
- Full immersion coding

Scroll Wheel Tilt → Split Editor
- Tilt Left: Cmd+\  (split editor)
- Tilt Right: Cmd+K Cmd+W (close editor)
```

---

## 🖥️ PROFILE 2: TERMINAL (iTerm2 / Terminal.app)

**Application Path:** 
- iTerm2: `/Applications/iTerm.app`
- Terminal: `/System/Applications/Utilities/Terminal.app`

### Button Configuration:

| Button | Action | Keystroke | Purpose |
|--------|--------|-----------|---------|
| **Thumb Forward** | New Tab | `Cmd+T` | Fresh terminal |
| **Thumb Back** | Previous Tab | `Cmd+Shift+[` | Switch tabs |
| **Gesture Button** | Clear Screen | `Cmd+K` | Clean terminal |
| **Top Button** | Split Pane (iTerm) | `Cmd+D` | Horizontal split |
| **Thumb Wheel Left** | Previous Tab | `Cmd+Shift+[` | Navigate tabs |
| **Thumb Wheel Right** | Next Tab | `Cmd+Shift+]` | Navigate tabs |

### iTerm2-Specific:
```
PROFILE HOTKEYS (if using iTerm2):

Gesture Button → Dropdown Terminal
- Go to: Preferences → Keys → Hotkey Window
- Check "Show/hide all windows with a system-wide hotkey"
- Set to: Cmd+Option+T
- Map gesture button to: Cmd+Option+T

This creates a Quake-style dropdown terminal!
```

---

## 🌐 PROFILE 3: WEB BROWSER (Chrome/Firefox)

**Application Path:**
- Chrome: `/Applications/Google Chrome.app`
- Firefox: `/Applications/Firefox.app`
- Safari: `/Applications/Safari.app`

### Button Configuration:

| Button | Action | Keystroke | Purpose |
|--------|--------|-----------|---------|
| **Thumb Forward** | Next Tab | `Cmd+Option+→` | Forward in tabs |
| **Thumb Back** | Previous Tab | `Cmd+Option+←` | Back in tabs |
| **Gesture Button** | New Tab | `Cmd+T` | Fresh tab |
| **Top Button** | Reopen Closed Tab | `Cmd+Shift+T` | Undo close |
| **Thumb Wheel Left** | Back in History | `Cmd+[` | Browser back |
| **Thumb Wheel Right** | Forward in History | `Cmd+]` | Browser forward |

### Developer Tools Mode:
```
ALTERNATIVE FOR WEB DEVELOPMENT:

Gesture Button → DevTools
- Keystroke: Cmd+Option+I
- Instant inspector

Top Button → Console
- Keystroke: Cmd+Option+J
- Console panel

Thumb Forward → Elements
- Keystroke: Cmd+Shift+C
- Element picker
```

---

## 🎨 PROFILE 4: DEFAULT (macOS System)

**Application:** All other applications

### Button Configuration:

| Button | Action | Type | Purpose |
|--------|--------|------|---------|
| **Thumb Forward** | Forward | Gesture | Navigate forward |
| **Thumb Back** | Back | Gesture | Navigate back |
| **Gesture Button** | Mission Control | System | View all windows |
| **Top Button** | Application Windows | System | App Exposé |
| **Thumb Wheel** | Horizontal Scroll | Native | Scroll left/right |

### macOS Native Gestures:
```
Keep these as DEFAULTS for non-dev apps:
- Thumb forward/back = Browser navigation
- Gesture button = Mission Control (F3)
- Top button = Show Desktop (F11)
```

---

## 🔧 LOGI OPTIONS+ SETUP PROCEDURE

### Step-by-Step Configuration:

#### 1. Install Logi Options+
```bash
# Download from:
https://www.logitech.com/en-us/software/logi-options-plus.html

# Or install via Homebrew:
brew install --cask logi-options-plus
```

#### 2. Grant Permissions
```
System Settings → Privacy & Security → Accessibility
✓ Enable Logi Options+

System Settings → Privacy & Security → Input Monitoring
✓ Enable Logi Options+
```

#### 3. Connect Your MX Master 3S
```
1. Turn on mouse (switch underneath)
2. Pair via Bluetooth or USB Bolt receiver
3. Options+ should detect automatically
4. Select "MX Master 3S" in Options+ interface
```

#### 4. Create VS Code Profile
```
1. Open Logi Options+
2. Click "Applications" tab at top
3. Click "+ Add Application" button (bottom left)
4. Navigate to: /Applications/Visual Studio Code.app
5. Click "Open"
6. VS Code now appears in app list
7. Click "Visual Studio Code" to configure
```

#### 5. Configure Buttons
```
For each button you want to customize:

1. Click the button diagram (e.g., "Thumb Button Forward")
2. Select "Keystroke Assignment" from dropdown
3. Click in the field and press your key combo (e.g., Cmd+Shift+P)
4. Options+ captures the keystroke
5. Click "Save" or just click away
6. Button now mapped!

IMPORTANT: Test in VS Code immediately after saving
```

#### 6. Enable Smart Actions (Optional)
```
Smart Actions = Multi-key macros

Example: Thumb Forward → Git Commit Flow
1. Options+ → Smart Actions tab
2. Create new Smart Action
3. Name: "Quick Git Commit"
4. Steps:
   - Keystroke: Cmd+Shift+G (open Git panel)
   - Wait: 100ms
   - Keystroke: Cmd+Enter (commit)
5. Assign to button
6. Now one click = git commit!
```

---

## 🎯 RECOMMENDED PROFILE WORKFLOW

### Development Workflow (Primary):
```
ACTIVE PROFILE: VS Code
├── Thumb Forward    → Cmd+Shift+P (Command Palette)
├── Thumb Back       → Cmd+Shift+E (Explorer)
├── Gesture Button   → Cmd+J (Terminal)
├── Top Button       → Cmd+K Cmd+O (Workspace)
├── Wheel Left       → Cmd+Shift+[ (Previous Tab)
└── Wheel Right      → Cmd+Shift+] (Next Tab)

RESULT: 95% of navigation = mouse only
```

### Terminal Workflow (Secondary):
```
ACTIVE PROFILE: iTerm2
├── Thumb Forward    → Cmd+T (New Tab)
├── Thumb Back       → Cmd+Shift+[ (Previous Tab)
├── Gesture Button   → Cmd+K (Clear)
├── Top Button       → Cmd+D (Split Pane)
├── Wheel Left       → Cmd+Shift+[ (Previous Tab)
└── Wheel Right      → Cmd+Shift+] (Next Tab)

RESULT: Terminal ops without keyboard
```

### Research Workflow (Tertiary):
```
ACTIVE PROFILE: Chrome/Firefox
├── Thumb Forward    → Cmd+Option+→ (Next Tab)
├── Thumb Back       → Cmd+Option+← (Previous Tab)
├── Gesture Button   → Cmd+T (New Tab)
├── Top Button       → Cmd+Shift+T (Reopen)
├── Wheel Left       → Cmd+[ (Back)
└── Wheel Right      → Cmd+] (Forward)

RESULT: Browse docs at forge speed
```

---

## 🔥 ADVANCED PROFILE TRICKS

### 1. Profile Auto-Switching
```
Logi Options+ automatically switches profiles when you:
- Click into VS Code window → VS Code profile active
- Cmd+Tab to Chrome → Browser profile active
- Switch to Terminal → Terminal profile active

NO MANUAL SWITCHING NEEDED!
```

### 2. Multi-Action Buttons (Smart Actions)
```
Create complex workflows:

EXAMPLE: "Full Git Push"
1. Cmd+Shift+G (Git panel)
2. Wait 100ms
3. Type: "git push origin main"
4. Wait 50ms
5. Enter

Assign to: Top Button in VS Code profile
Result: One click = commit + push
```

### 3. Context-Sensitive Mappings
```
Same button, different action based on context:

VS Code Explorer Open:
- Thumb Forward → Cmd+Shift+P (Command Palette)

VS Code Terminal Focused:
- Thumb Forward → Ctrl+R (Reverse search)

Use Options+ conditions or separate profiles
```

### 4. Easy-Switch Button Profiles
```
MX Master 3S has 3-device Easy-Switch:

Button 1 (Default): Mac → VS Code profile
Button 2 (Middle):  Linux Workstation → Terminal profile
Button 3 (Bottom):  iPad → Default gestures

One mouse, three computers, auto-profiles!
```

---

## 🧪 TESTING YOUR PROFILES

### Quick Validation Checklist:
```bash
# Open VS Code
code ~/sovereign

# Test each button:
□ Thumb Forward → Command Palette opens (Cmd+Shift+P works)
□ Thumb Back → Explorer sidebar visible (Cmd+Shift+E works)
□ Gesture Button → Terminal toggles (Cmd+J works)
□ Top Button → Workspace switcher appears (Cmd+K Cmd+O works)
□ Thumb Wheel Left → Previous tab selected
□ Thumb Wheel Right → Next tab selected

# Switch to Terminal
open -a iTerm

# Test terminal profile:
□ Thumb Forward → New tab created
□ Thumb Back → Previous tab selected
□ Gesture Button → Screen clears (Cmd+K works)

# Switch to Browser
open -a "Google Chrome"

# Test browser profile:
□ Thumb Forward → Next tab
□ Thumb Back → Previous tab
□ Gesture Button → New tab opens
```

---

## 🐛 TROUBLESHOOTING

### Profile Not Switching:
```
Issue: Buttons don't change when switching apps

Fix:
1. Logi Options+ → Settings → Enable "Application Detection"
2. Grant Accessibility permissions (System Settings)
3. Restart Logi Options+
4. Test again
```

### Keystroke Not Registering:
```
Issue: Button click does nothing in VS Code

Fix:
1. Options+ → VS Code profile → Click button diagram
2. Delete existing keystroke
3. Re-record: Click field → Press Cmd+Shift+P
4. Make sure "Cmd" appears in the field (not "Ctrl")
5. Save and test

Mac Gotcha: Use Cmd, not Ctrl!
```

### Thumb Wheel Not Working:
```
Issue: Thumb wheel doesn't scroll horizontally

Fix:
1. This should work by DEFAULT on Mac
2. No configuration needed in Options+
3. If not working: Check macOS settings
   System Settings → Trackpad → Scroll & Zoom
   ✓ Enable "Scroll direction: Natural"
4. Test in VS Code with wide file open
```

### Profile Conflicts:
```
Issue: VS Code profile activating in wrong app

Fix:
1. Options+ → Applications tab
2. Check application paths are correct
3. Remove duplicate entries
4. Ensure only ONE "Visual Studio Code.app"
5. Delete and recreate profile if needed
```

---

## 📊 PROFILE PERFORMANCE METRICS

### Forge Velocity Improvements:
```
WITHOUT PROFILES (Keyboard Only):
- Command Palette: Move hand to keyboard → Cmd+Shift+P → 0.8s
- Explorer: Move hand → Cmd+Shift+E → 0.8s
- Terminal: Move hand → Cmd+J → 0.8s
Total Context Switch: ~2.4s per action

WITH PROFILES (MX Master 3S):
- Command Palette: Thumb forward → 0.1s
- Explorer: Thumb back → 0.1s
- Terminal: Gesture button → 0.1s
Total Context Switch: ~0.3s per action

SPEED INCREASE: 8x faster navigation!
TIME SAVED: ~2.1s per action × 200 actions/day = 7 minutes/day = 42 hours/year
```

---

## 🎮 GAMING-STYLE MUSCLE MEMORY

### Training Routine:
```
Week 1: VS Code Profile Only
- Focus: Thumb forward = Command Palette
- Practice: 50 command palette invocations/day
- Goal: Reflex action (no thinking)

Week 2: Add Terminal Profile
- Focus: All thumb buttons
- Practice: 30 terminal operations/day
- Goal: Context switching without looking

Week 3: Add Browser Profile
- Focus: Tab management
- Practice: Research sessions with mouse only
- Goal: Full workflow integration

Result: Forge velocity at maximum 🔥
```

---

## 🏆 FORGE-OPTIMIZED PROFILE SET

### Final Recommended Setup:

#### VS Code (Primary - 80% of time)
```
Thumb Forward    → Cmd+Shift+P (Command Palette)
Thumb Back       → Cmd+Shift+E (Explorer)
Gesture Button   → Cmd+J (Terminal)
Top Button       → Cmd+K Cmd+O (Workspace Switcher)
Thumb Wheel      → Tab Navigation (Native)
```

#### Terminal (Secondary - 15% of time)
```
Thumb Forward    → Cmd+T (New Tab)
Thumb Back       → Cmd+Shift+[ (Previous Tab)
Gesture Button   → Cmd+K (Clear)
Top Button       → Cmd+D (Split Pane)
```

#### Browser (Tertiary - 5% of time)
```
Thumb Forward    → Cmd+Option+→ (Next Tab)
Thumb Back       → Cmd+Option+← (Previous Tab)
Gesture Button   → Cmd+T (New Tab)
Top Button       → Cmd+Shift+T (Reopen Tab)
```

#### Default (Everything Else)
```
Standard macOS gestures
No custom mappings needed
```

---

## 📚 RESOURCES

### Official Documentation:
- Logi Options+ User Guide: https://support.logi.com/hc/en-us/articles/360035037273
- MX Master 3S Specs: https://www.logitech.com/en-us/products/mice/mx-master-3s.html

### VS Code Keybindings:
- Mac Shortcuts: https://code.visualstudio.com/shortcuts/keyboard-shortcuts-macos.pdf
- Custom Keybindings: `Code → Settings → Keyboard Shortcuts`

### Related Files in Sovereign:
- Main Setup Guide: `~/sovereign/docs/MX_MASTER_3S_VSCODE_SETUP.md`
- Workspace Config: `~/vaultmesh-ecosystem.code-workspace`
- Keybindings: `~/.config/Code/User/keybindings.json`

---

## ✅ QUICK START CHECKLIST

```bash
□ Install Logi Options+ for macOS
□ Grant Accessibility + Input Monitoring permissions
□ Pair MX Master 3S (Bluetooth or Bolt)
□ Create VS Code profile (/Applications/Visual Studio Code.app)
□ Map thumb forward → Cmd+Shift+P
□ Map thumb back → Cmd+Shift+E
□ Map gesture button → Cmd+J
□ Map top button → Cmd+K Cmd+O
□ Test all buttons in VS Code
□ Create Terminal profile (optional)
□ Create Browser profile (optional)
□ Practice for 1 week until reflex
```

---

**Steel focused. Profile configured. Forge velocity maximized. ⚔️🖱️**

*Last Updated: October 3, 2025*
