# TimerModules

> ⏱ A snap-together Gantt chart for timers — iOS / iPadOS / macOS

TimerModules is a Gantt of labeled timers connected by snap-together connector bricks. Most timer apps just list countdown timers with no relationships between them. TimerModules lets you wire timers together with boolean logic gates (AND, OR, NOT, NOR, NAND, XOR, XNOR) **and** project-management dependency types (FS, SS, FF, SF, Lag/Lead, Splitter) — both as draggable bricks on the same canvas.

## 📖 Documentation

- **Support manual** (Chilton/Haynes-style owner's guide): [`fluharty.me/timermodules-support`](https://fluharty.me/timermodules-support)
- **Privacy policy:** [`fluharty.me/privacy`](https://fluharty.me/privacy)
- **GitHub Wiki:** [Quick Start and developer notes](https://github.com/fluhartyml/TimerModules/wiki)

## ✨ The brick palette

**Functional**
- **Timer module** — runs time, doubles as the clock; prominent user-notation text field on the brick face

**Connectors — Logic gates** (the unique twist)
- AND, OR, NOT, NOR, NAND, XOR, XNOR

**Connectors — PM dependency types**
- FS (Finish-to-Start), SS (Start-to-Start), FF (Finish-to-Finish), SF (Start-to-Finish), Lag/Lead, Splitter/Fan-out

**Supplemental**
- Note, Marker, Trigger, Action, Group, Variable, Webhook, Conditional, Loop

## 🚀 Quick Start (Xcode 26)

1. In Xcode 26, open the **Welcome** window
2. Choose **Clone Git Repository…**
3. Paste: `https://github.com/fluhartyml/TimerModules`
4. Pick a local folder and click **Clone**
5. When the project opens, select your team in **Signing & Capabilities**
6. ▶ Run on your iPhone, iPad, or Mac

## 🏗 Lineage

TimerModules is rooted from the Timer module of [OPerationsHOS](https://github.com/fluhartyml/OPerationsHOS) — Michael's universal home operations app. The Timer dial, start/stop/reset pattern, elapsed-time math, and analog face are inherited; the Gantt + Lego + boolean-logic architecture is TimerModules-specific.

## 📜 License

GPL v3 — share and share alike with attribution required. See [LICENSE](LICENSE) (added at ship-prep milestone).

## ✍️ Contact

Michael Fluharty — michael@fluharty.com

🤖 Engineered with [Claude](https://claude.ai) (Anthropic) · Architected by Michael
