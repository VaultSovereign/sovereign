# ⚔️ MX MASTER 3S + VS Code Configuration Guide ⚔️

**Logitech MX Master 3S Mouse → VaultMesh Forge Velocity**

---

## 🎯 Button Mapping Strategy

Your MX Master 3S has these programmable buttons:
- **Thumb Button (Forward)** - Near thumb rest
- **Thumb Button (Back)** - Near thumb rest  
- **Side Scroll Wheel** - Thumb wheel
- **Gesture Button** - Under thumb
- **Top Button** - Above main scroll wheel

---

## 🔥 Recommended Button Configuration

### Via Logitech Options+ Software

**Install Logitech Options+:**
```bash
# Download from: https://www.logitech.com/en-us/software/logi-options-plus.html
# Or via Ubuntu/Debian:
sudo apt install solaar  # Open-source alternative
```

---

## ⚡ OPTIMAL BUTTON MAPPINGS FOR VS CODE

### **Thumb Forward Button → Open Command Palette**
- **Action:** `Ctrl+Shift+P`
- **Why:** Instant access to any VS Code command
- **Use:** Open file, run task, git commit, anything

### **Thumb Back Button → Open File Explorer**
- **Action:** `Ctrl+Shift+E`
- **Why:** Jump to sidebar, select repo folder
- **Use:** Switch between sovereign/VaultMesh/forge instantly

### **Thumb Scroll Wheel → Switch Tabs**
- **Scroll Left:** Previous tab (`Ctrl+PageUp`)
- **Scroll Right:** Next tab (`Ctrl+PageDown`)
- **Why:** Navigate open files without keyboard

### **Gesture Button → Toggle Terminal**
- **Action:** `Ctrl+\`` (backtick)
- **Why:** Show/hide terminal with one thumb press
- **Use:** Quick terminal access, stays in current folder

### **Top Button (above scroll) → Workspace Switcher**
- **Action:** `Ctrl+K Ctrl+O` (Open Workspace)
- **Why:** Switch entire workspace with one click
- **Use:** Jump between VaultMesh ecosystem and other projects

---

## 🖱️ Configuration Steps in Logitech Options+

### 1. Install & Launch Options+
```bash
# Open Logitech Options+ app
# Select "MX Master 3S" from devices
```

### 2. Configure Buttons

**Point & Click Tab:**

**Forward Button:**
- Click "Customize"
- Select "Keystroke Assignment"
- Enter: `Ctrl+Shift+P`
- Name: "VS Code Command Palette"

**Back Button:**
- Click "Customize"  
- Select "Keystroke Assignment"
- Enter: `Ctrl+Shift+E`
- Name: "VS Code Explorer"

**Gesture Button:**
- Click "Customize"
- Select "Keystroke Assignment"  
- Enter: `Ctrl+\`` (Ctrl+backtick)
- Name: "VS Code Terminal"

**Top Button:**
- Click "Customize"
- Select "Keystroke Assignment"
- Enter: `Ctrl+K` then `Ctrl+O` (sequence)
- Name: "Open Workspace"

**Thumb Wheel:**
- Horizontal Scrolling: Default (Left/Right)
- Or override:
  - Left: `Ctrl+PageUp` (Previous Tab)
  - Right: `Ctrl+PageDown` (Next Tab)

---

## 🎯 App-Specific Configuration

Logitech Options+ allows **per-application settings**:

**1. Create "Visual Studio Code" profile:**
- In Options+: Click "+" to add application
- Find: `/usr/share/code/code` (or `which code`)

**2. Set these buttons ONLY for VS Code:**
- Keeps your normal browsing/OS buttons unchanged
- Activates forge-mode buttons when VS Code focused

**3. Default profile for other apps:**
- Forward/Back = Browser navigation
- Gesture = Mission Control / Exposé
- Normal productivity buttons

---

## ⚡ ALTERNATIVE: VS Code "Project Manager" Extension

If you want **one-click project switching:**

### Install Extension
```
1. Ctrl+Shift+X (Extensions)
2. Search: "Project Manager"
3. Install: "Project Manager" by Alessandro Fragnani
```

### Save Projects
```
1. Open sovereign: Ctrl+Shift+P → "Project Manager: Save Project"
2. Open VaultMesh: Ctrl+Shift+P → "Project Manager: Save Project"  
3. Open forge: Ctrl+Shift+P → "Project Manager: Save Project"
... repeat for all 7 repos
```

### Map Mouse Button
```
MX Master 3S Top Button → Ctrl+Alt+P
Keybinding: Ctrl+Alt+P → "Project Manager: List Projects"
Result: One click → project list → instant switch
```

---

## 🔥 ULTIMATE FORGE MODE SETUP

### Mouse Buttons (MX Master 3S)
- **Thumb Forward** → Command Palette (`Ctrl+Shift+P`)
- **Thumb Back** → Explorer (`Ctrl+Shift+E`)
- **Thumb Wheel Left** → Previous Tab
- **Thumb Wheel Right** → Next Tab
- **Gesture Button** → Toggle Terminal (`Ctrl+\``)
- **Top Button** → Project Switcher (`Ctrl+Alt+P`)

### Keyboard Shortcuts (VS Code)
- **Ctrl+1-7** → Focus repo 1-7 in workspace
- **Ctrl+Alt+T** → New terminal
- **Ctrl+Alt+G** → Git panel
- **Ctrl+K Z** → Zen mode (distraction-free)
- **Ctrl+Shift+F** → Search in files

### Workflow
1. **Open workspace:** File → Open `~/vaultmesh-ecosystem.code-workspace`
2. **Switch repos:** Click folder name OR use mouse thumb back button → Explorer
3. **Terminal:** Press gesture button (thumb) → terminal opens in repo folder
4. **Search:** `Ctrl+Shift+F` → searches current repo only
5. **Git:** `Ctrl+Alt+G` → commit/push with mouse in left hand, type with right

---

## 🎮 GAMING-STYLE EFFICIENCY

**Think of it like game controls:**
- **Left Hand:** Mouse (MX Master 3S) - navigation, quick actions
- **Right Hand:** Keyboard - typing, multi-key shortcuts
- **Eyes:** Screen - never leave to look at keyboard

**Common Forge Actions (One-Handed Mouse):**
- Open command palette (thumb forward)
- Switch to explorer (thumb back)
- Toggle terminal (gesture button)
- Switch tabs (thumb scroll)
- All while typing with right hand!

---

## 📊 Solaar Alternative (Open Source)

If you prefer open-source over Logitech Options+:

```bash
# Install Solaar
sudo apt install solaar

# Launch
solaar

# Configure buttons via GUI
# - Detects MX Master 3S automatically
# - Assign keystrokes to buttons
# - Per-app configurations supported
```

---

## 🔧 Testing Your Setup

**1. Test Mouse Buttons:**
```
Open VS Code
Press thumb forward → Command palette appears?
Press thumb back → Explorer sidebar appears?
Press gesture button → Terminal toggles?
```

**2. Test Keyboard Shortcuts:**
```
Ctrl+Shift+P → Command palette?
Ctrl+Shift+E → Explorer?
Ctrl+` → Terminal?
Ctrl+Alt+G → Git panel?
```

**3. Test Workspace:**
```
File → Open Workspace → ~/vaultmesh-ecosystem.code-workspace
All 7 repos visible in sidebar?
Click sovereign → Terminal shows ~/sovereign?
Click VaultMesh → Terminal shows ~/VaultMesh?
```

---

## 🎯 Ergonomics

**MX Master 3S is PERFECT for this workflow because:**
- ✅ Thumb wheel = horizontal scroll = tab switching (natural)
- ✅ Gesture button = terminal toggle (most used action)
- ✅ Forward/back buttons = command palette / explorer (instant access)
- ✅ Wireless = clean desk, no cable drag
- ✅ Multi-device = switch between Linux workstation + Mac if needed

**With this setup:**
- ⚡ 80% of actions = mouse only
- ⚡ 20% of actions = keyboard shortcuts
- ⚡ 0% menu clicking = forge velocity maximized

---

## 🔥 FINAL CONFIGURATION CHECKLIST

- [ ] Install Logitech Options+ (or Solaar)
- [ ] Map MX Master 3S buttons as above
- [ ] Copy keybindings.json to VS Code config
- [ ] Open vaultmesh-ecosystem.code-workspace
- [ ] Test all mouse buttons in VS Code
- [ ] Test keyboard shortcuts
- [ ] Practice: Open command palette with thumb, search file, switch tab, toggle terminal
- [ ] Achieve forge velocity

---

**Steel focused. Mouse optimized. Forge accelerated.** ⚔️🖱️

*The MX Master 3S becomes an extension of your will.*  
*The forge responds instantly to every gesture.*  
*Context switching becomes muscle memory.*
