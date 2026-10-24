# 🚀 Master AI Prompt: Mobile UI/UX Design Concepts & Prototypes for Na7la IoT
> **How to use this file:**  
> انسخ النص بالكامل في هذا الملف وأرسله إلى أي نموذج ذكاء اصطناعي تفضله (مثل Claude 3.5 Sonnet, ChatGPT-4o, v0.dev, أو Bolt.new).  
> سيقوم الذكاء الاصطناعي بدراسة المتطلبات بالكامل وتوليد 3 تصميمات UI/UX مختلفة ومقترحات تفاعلية لتختار من بينها الأنسب لذوقك قبل البدء في الكود!

---

```markdown
# Context & Persona:
You are a World-Class Principal Mobile UI/UX Designer and Lead Product Architect specializing in modern Smart Home & IoT applications (similar to Apple HomeKit, Nothing OS, Aqara, and Tesla App). 

You are tasked with designing the complete Mobile UI/UX Architecture and Visual Mockups for **"Na7la IoT" (نحلة)** — a high-performance, intelligent smart power strip application controlling multi-outlet hardware (4 AC sockets with individual relays, precision energy metering, compressor protection, and per-socket PIN security).

---

## 🎯 Project Overview & Brand Identity:
- **App Name:** Na7la IoT (نحلة للتحكم الذكي في الطاقة)
- **Target Platform:** Native Mobile App (Android & iOS / Flutter / React Native) & Progressive Web App (PWA).
- **Core Audience:** Smart home owners, tech enthusiasts, and families in Egypt & the Middle East who demand absolute appliance safety, electrical protection, and real-time energy bill awareness.
- **Language & Orientation:** Native Arabic (RTL-First) with full English toggle support.
- **Typography:** **Cairo** font family (clean, modern, highly legible Arabic typography) paired with **JetBrains Mono** or **Inter** for precision numeric telemetry (Watts, Volts, Amperes, kWh).
- **Visual Aesthetic:** Premium, futuristic, ultra-responsive, and clean. Dark mode OLED-optimized by default with rich micro-interactions and tactile feedback.

---

## 🏆 Key Unique Features of Na7la IoT (To Highlight in UX):
1. **Precision Live Telemetry Hub:** Real-time Voltage (V), Current (A), Active Power (W), and Accumulated Energy (kWh) with live cost estimation in Egyptian Pounds (EGP).
2. **Per-Socket Independent PIN Lock (قفل مستقل لكل فيشة):** Users can lock specific sensitive sockets with a custom 4-digit PIN. Unlocking can also use biometric fingerprint / Face ID.
3. **Smart Router Safeguard (حماية الراوتر الذكية):** The socket connected to the internet router is automatically flagged; it is immune to "Turn All OFF" commands and reboots immediately after blackouts without delay.
4. **Compressor & Inrush Protection (حماية أجهزة الكمبريسور):** Automatic 3-to-10-minute staggered boot delay after power outages to protect refrigerators and AC compressors from burning out.
5. **Smart Charger Auto-Cutoff (فصل الشاحن الذكي):** Monitors phone charging; automatically shuts off the socket when power drops below 3W for 10 minutes to protect battery health.
6. **Smart Overload Shedding (تخفيف الأحمال في الطوارئ):** If overall load exceeds 16A, it automatically sheds the highest-consuming socket while strictly keeping the router socket ON.
7. **Android Home Screen Widgets:** 1x1 instant toggle widgets and 4x2 interactive power telemetry widgets.
8. **Granular Family Sharing:** 3 roles (Full Control, Partial Control, View Only) with single-use guest invite codes.
9. **Excel Energy Export:** 1-click download of detailed consumption reports in `.xlsx` format.

---

## 📱 Required Screens to Design & Specify:

### 1. Main Dashboard (شاشة التحكم الرئيسية)
- **Top Header:** User greeting, connection status indicator ("متصل ومستقر" with green pulse dot), Quick Theme switcher, and notification bell.
- **Hero Master Card (المشترك الرئيسي):**
  - Live summary: Total Active Watts (e.g., `1,420 W`), Live Mains Voltage (`224 V`), Today's Energy (`3.4 kWh`), Estimated Cost (`7.50 ج.م`).
  - Master Quick Actions: "⚡ تشغيل الكل (Turn All ON)" & "🛑 إطفاء الكل الذكي (Smart All OFF - Keeps Router Safe)".
- **4-Socket Dynamic Grid (شبكة المخارج الأربعة):**
  - Each socket card must prominently display:
    - Custom Socket Name & Appliance Icon (e.g., ❄️ تلاجة، 🌐 راوتر، 📱 شاحن، 📺 شاشة).
    - Status Badge (ON / OFF / Locked 🔒 / Compressor Delay ⏳).
    - Real-time Wattage meter (e.g., `120 W`).
    - Primary Switch Toggle Button.
    - Special indicator if it's protected as Router or Locked with PIN.
  - **Interaction:**
    - Quick tap on toggle: Immediate power switch (or PIN prompt if locked).
    - Long-press on socket card: Opens the **Socket Deep-Dive Bottom Sheet**.

### 2. Socket Deep-Dive Bottom Sheet (النافذة التفصيلية للمخرج)
- Opened by long-pressing any socket card.
- **Controls & Features:**
  - Timer selector (e.g., Turn OFF after 15m, 30m, 1h, 2h, or custom).
  - Repeating Cycles (e.g., Run 15m every 1 hour for water heaters or fans).
  - Smart Charger Mode toggle (Auto shut-off when battery is full).
  - Post-Blackout Recovery Rule: (Resume previous state / Stay OFF / Delayed Compressor Start).
  - Per-Socket PIN Lock manager (Set PIN, Change PIN, Lock/Unlock).
  - Appliance Preset Picker (Select icon and auto-apply manufacturer safety guidelines: Refrigerator, AC, TV, Heater, Charger, Router).

### 3. Energy Analytics & Cost Calculator (شاشة الاستهلاك والفاتورة)
- Historical consumption charts (Day, Week, Month).
- Peak usage hours breakdown.
- Cost breakdown in EGP according to Egyptian electricity tariff tiers (الشرائح).
- Per-outlet consumption comparison (Who is consuming the most power?).
- **"📊 تصدير تقرير Excel (Download .xlsx Report)"** action button.

### 4. Smart Protection & Automation (الأتمتة والحماية الذكية)
- Voltage Guard sliders (Cut off if below 180V or above 250V).
- High-Current Alert & Auto-Shedding thresholds.
- Staggered Startup delays configuration (e.g., Fridge first, AC +2 minutes later).
- Smart Scenes (e.g., "Cinema Mode", "Sleep Mode", "Leaving Home").

### 5. Family & Guest Sharing (أهل البيت والضيوف)
- List of members with badges: "تحكم كامل", "تحكم جزئي", "مشاهدة بس".
- "➕ إضافة فرد جديد (Add Member)" button: Generates an instant single-use 6-digit invite code or QR code.
- Member permissions editor (toggle which specific sockets they can control).

### 6. Add Strip Wizard (معالج ربط مشترك جديد)
- 3-step visual onboarding:
  1. Put strip in pairing mode (LED blinking rapidly).
  2. Auto-detect `TONLY_TAP_*` SoftAP network.
  3. Select home 2.4 GHz Wi-Fi and transfer credentials.
  4. Immediate prompt: *"هل هذا المشترك متصل به راوتر البيت؟ (Is your home router plugged into this strip?)"* to auto-activate zero-disconnection safeguards.

---

## 🎨 Deliverable Request: Provide 3 Competing Design Concepts:

Please propose **THREE (3) distinctly different UI/UX Design Concepts** for Na7la IoT:

### Option A: The "Modern Bento Grid & Frosted Glass" (Apple & Nothing Style)
- Focus: Asymmetrical Bento-grid cards, subtle blur glassmorphism, glowing ambient accents (Amber `#F59E0B` & Cyan `#06B6D4`), tactile toggles with smooth spring physics, ultra-clean minimalism.

### Option B: The "Tactile Dark Neumorphism" (Sleek High-End Audiophile/Automotive Aesthetic)
- Focus: Deep OLED blacks (`#0B0D13`), soft embossed 3D switch buttons that visually press inward when active, warm glowing LED indicators, radial energy dial gauges.

### Option C: The "Futuristic Cyber-IoT HUD" (Data-Dense Dashboard for Power Enthusiasts)
- Focus: Sleek dark technical aesthetic, real-time waveform sparklines for voltage and watts, glowing emerald green (`#10B981`) and electric cyan accents, modular tiles with rapid 1-tap toggles and live power flow animations.

---

## 📋 What to include in your output:
1. **Design System & Tokens:**
   - Exact Color Palette (Hex codes for Backgrounds, Cards, Borders, Statuses, Text).
   - Typography specifications (Cairo font weights and sizes).
   - Iconography style (Lucide / Phosphor icons).
2. **ASCII or Markdown Visual Layout Wireframes:**
   - Detailed ASCII mockups for the **Main Dashboard** and the **Socket Card** for each of the 3 design options so I can clearly visualize the layout on a mobile screen.
3. **Interactive Component Code Mockups (Tailwind CSS + React / HTML):**
   - Provide a complete, fully styled responsive component for the **Socket Card** and the **Live Master Power Card** representing the best recommended design concept, ready to test or paste in a browser.
4. **UX Micro-Interactions & Gestures:**
   - Define exact transitions, haptic feedback triggers (e.g., medium impact buzz on socket toggle, error double buzz on wrong PIN), and state animations.
5. **Comparison & Recommendation:**
   - A concluding verdict comparing Option A, B, and C with your expert recommendation for maximum user delight and retention.
```
