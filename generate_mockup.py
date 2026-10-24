import os, subprocess

html_content = """<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Na7la IoT - Proposed UI v1.3</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;800;900&family=Inter:wght@400;600;700;900&display=swap" rel="stylesheet">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Cairo', sans-serif; -webkit-font-smoothing: antialiased; }
  body {
    background: #080D1A;
    display: flex;
    justify-content: center;
    align-items: flex-start;
    padding: 10px;
  }
  
  /* Modern Smartphone Frame */
  .phone-frame {
    width: 395px;
    height: 840px;
    background: #0F172A;
    border-radius: 44px;
    box-shadow: 0 25px 60px rgba(0,0,0,0.9), 0 0 0 8px #1E293B, 0 0 0 10px #334155;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    position: relative;
    border: 1px solid rgba(255,255,255,0.12);
  }

  /* Status Bar */
  .status-bar {
    height: 36px;
    padding: 10px 22px 0;
    display: flex;
    justify-content: space-between;
    align-items: center;
    color: #94A3B8;
    font-size: 12px;
    font-weight: 700;
    font-family: 'Inter', sans-serif;
  }
  .status-icons { display: flex; gap: 6px; align-items: center; font-size: 11px; }

  /* App Bar Header */
  .app-header {
    padding: 8px 16px 6px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .strip-title-box { display: flex; align-items: center; gap: 6px; }
  .strip-title { color: #FFFFFF; font-size: 16px; font-weight: 800; }
  .online-badge {
    background: rgba(16, 185, 129, 0.15);
    color: #10B981;
    border: 1px solid rgba(16, 185, 129, 0.4);
    font-size: 10px;
    font-weight: 700;
    padding: 2px 7px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .online-dot { width: 5px; height: 5px; background: #10B981; border-radius: 50%; box-shadow: 0 0 6px #10B981; }

  /* Child Lock Toggle Header Button */
  .child-lock-btn {
    background: rgba(245, 158, 11, 0.15);
    border: 1px solid rgba(245, 158, 11, 0.45);
    color: #FBBF24;
    padding: 4px 10px;
    border-radius: 14px;
    font-size: 10px;
    font-weight: 700;
    display: flex;
    align-items: center;
    gap: 4px;
    box-shadow: 0 0 10px rgba(245, 158, 11, 0.15);
  }

  /* Slim KPI Bar (Zero-Scroll Masterpiece) */
  .kpi-container {
    padding: 4px 14px 10px;
  }
  .kpi-bar {
    background: linear-gradient(135deg, rgba(30, 41, 59, 0.85) 0%, rgba(15, 23, 42, 0.95) 100%);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 16px;
    padding: 9px 12px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    backdrop-filter: blur(14px);
    box-shadow: 0 6px 20px rgba(0, 0, 0, 0.35);
  }
  .kpi-item { display: flex; flex-direction: column; align-items: center; flex: 1; }
  .kpi-item:not(:last-child) { border-left: 1px solid rgba(255, 255, 255, 0.08); }
  .kpi-label { color: #64748B; font-size: 10px; font-weight: 600; margin-bottom: 1px; }
  .kpi-value { font-size: 15px; font-weight: 800; display: flex; align-items: baseline; gap: 3px; font-family: 'Inter', 'Cairo', sans-serif; }
  .kpi-value.watt { color: #F59E0B; text-shadow: 0 0 12px rgba(245, 158, 11, 0.4); }
  .kpi-value.volt { color: #38BDF8; }
  .kpi-value.cost { color: #10B981; }
  .kpi-unit { font-size: 9px; font-weight: 700; color: #94A3B8; }

  /* 2x2 Grid - The Core Viewport (Zero Scroll) */
  .grid-container {
    padding: 0 14px;
    flex: 1;
    display: grid;
    grid-template-columns: 1fr 1fr;
    grid-template-rows: 1fr 1fr;
    gap: 10px;
  }

  /* Socket Card */
  .socket-card {
    background: #1E293B;
    border-radius: 18px;
    padding: 10px 12px 10px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    position: relative;
    border: 1.5px solid transparent;
    box-shadow: 0 4px 14px rgba(0,0,0,0.25);
  }
  .socket-card.active.emerald {
    background: linear-gradient(150deg, #1E293B 0%, #06281D 100%);
    border-color: rgba(16, 185, 129, 0.45);
    box-shadow: 0 6px 18px rgba(16, 185, 129, 0.18), inset 0 0 12px rgba(16, 185, 129, 0.08);
  }
  .socket-card.active.amber {
    background: linear-gradient(150deg, #1E293B 0%, #2E1A08 100%);
    border-color: rgba(245, 158, 11, 0.5);
    box-shadow: 0 6px 18px rgba(245, 158, 11, 0.18), inset 0 0 12px rgba(245, 158, 11, 0.08);
  }
  .socket-card.muted {
    background: #141C2B;
    border-color: rgba(255, 255, 255, 0.04);
    opacity: 0.65;
  }

  /* Socket Top Row */
  .sock-top { display: flex; justify-content: space-between; align-items: center; }
  .sock-voltage { font-size: 10px; font-weight: 700; color: #64748B; font-family: 'Inter', sans-serif; }
  .active .sock-voltage { color: #94A3B8; }
  .sock-badge {
    font-size: 9px;
    font-weight: 700;
    padding: 2px 6px;
    border-radius: 8px;
    display: flex;
    align-items: center;
    gap: 3px;
  }
  .badge-router { background: rgba(239, 68, 68, 0.2); color: #F87171; border: 1px solid rgba(239, 68, 68, 0.35); }
  .badge-fridge { background: rgba(56, 189, 248, 0.2); color: #38BDF8; border: 1px solid rgba(56, 189, 248, 0.35); }
  .badge-pc { background: rgba(16, 185, 129, 0.18); color: #34D399; }

  /* Socket Middle Content */
  .sock-middle { display: flex; flex-direction: column; gap: 2px; margin: 2px 0; }
  .sock-icon-box {
    width: 36px;
    height: 36px;
    border-radius: 12px;
    display: flex;
    justify-content: center;
    align-items: center;
    font-size: 20px;
    margin-bottom: 2px;
  }
  .active.emerald .sock-icon-box { background: rgba(16, 185, 129, 0.22); box-shadow: 0 0 12px rgba(16, 185, 129, 0.35); }
  .active.amber .sock-icon-box { background: rgba(245, 158, 11, 0.22); box-shadow: 0 0 12px rgba(245, 158, 11, 0.35); }
  .muted .sock-icon-box { background: rgba(255, 255, 255, 0.05); }

  .sock-name { color: #FFFFFF; font-size: 14px; font-weight: 800; line-height: 1.2; }
  .muted .sock-name { color: #94A3B8; font-weight: 600; }
  .sock-hint { color: #64748B; font-size: 10px; font-weight: 600; }

  /* Socket Bottom Row */
  .sock-bottom {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    padding-top: 6px;
    border-top: 1px solid rgba(255, 255, 255, 0.05);
  }
  .sock-watt-box { display: flex; flex-direction: column; }
  .sock-watt-val { font-size: 18px; font-weight: 900; color: #FFFFFF; font-family: 'Inter', sans-serif; line-height: 1; }
  .active.emerald .sock-watt-val { color: #10B981; }
  .active.amber .sock-watt-val { color: #F59E0B; }
  .muted .sock-watt-val { color: #475569; }
  .sock-watt-unit { font-size: 9px; font-weight: 700; color: #64748B; }

  /* Power Toggle Switch Button */
  .switch-btn {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    display: flex;
    justify-content: center;
    align-items: center;
    cursor: pointer;
    border: none;
    font-size: 14px;
    font-weight: 900;
  }
  .active.emerald .switch-btn {
    background: #10B981;
    color: #FFFFFF;
    box-shadow: 0 0 14px rgba(16, 185, 129, 0.65);
  }
  .active.amber .switch-btn {
    background: #F59E0B;
    color: #0F172A;
    box-shadow: 0 0 14px rgba(245, 158, 11, 0.65);
  }
  .muted .switch-btn {
    background: #334155;
    color: #64748B;
  }

  /* Master Switch Bar */
  .master-bar {
    padding: 8px 14px 6px;
  }
  .master-btn {
    width: 100%;
    background: rgba(30, 41, 59, 0.75);
    border: 1px solid rgba(255, 255, 255, 0.09);
    border-radius: 14px;
    padding: 8px;
    color: #E2E8F0;
    font-size: 12px;
    font-weight: 700;
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 7px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.25);
  }
  .master-btn span { color: #10B981; font-weight: 900; font-size: 14px; }

  /* Bottom Navigation Bar */
  .nav-bar {
    height: 60px;
    background: #0B1120;
    border-top: 1px solid rgba(255, 255, 255, 0.07);
    display: flex;
    justify-content: space-around;
    align-items: center;
    padding: 0 10px 4px;
  }
  .nav-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    color: #64748B;
    font-size: 10px;
    font-weight: 700;
  }
  .nav-item.active { color: #F59E0B; }
  .nav-icon { font-size: 16px; }

</style>
</head>
<body>

<div class="phone-frame">
  <!-- Status Bar -->
  <div class="status-bar">
    <span>12:45</span>
    <div class="status-icons">
      <span>5G</span>
      <span>📶</span>
      <span>100% 🔋</span>
    </div>
  </div>

  <!-- App Header -->
  <div class="app-header">
    <div class="strip-title-box">
      <div class="strip-title">مشترك الصالة الذكي ⚡</div>
      <div class="online-badge">
        <span class="online-dot"></span>
        متصل
      </div>
    </div>
    <div class="child-lock-btn">
      <span>👶 قفل الأطفال: مفعل</span>
    </div>
  </div>

  <!-- Slim KPI Bar -->
  <div class="kpi-container">
    <div class="kpi-bar">
      <div class="kpi-item">
        <span class="kpi-label">القدرة الإجمالية</span>
        <div class="kpi-value watt">65.4 <span class="kpi-unit">W</span></div>
      </div>
      <div class="kpi-item">
        <span class="kpi-label">جهد الكهرباء</span>
        <div class="kpi-value volt">228 <span class="kpi-unit">V 🛡️</span></div>
      </div>
      <div class="kpi-item">
        <span class="kpi-label">فاتورة اليوم</span>
        <div class="kpi-value cost">4.50 <span class="kpi-unit">ج.م</span></div>
      </div>
    </div>
  </div>

  <!-- 2x2 Grid Outlets (Zero-Scroll Viewport) -->
  <div class="grid-container">
    
    <!-- Socket 1: PC Display -->
    <div class="socket-card active emerald">
      <div class="sock-top">
        <span class="sock-voltage">228V · 28°C</span>
        <span class="sock-badge badge-pc">مخرج 1</span>
      </div>
      <div class="sock-middle">
        <div class="sock-icon-box">🖥️</div>
        <div class="sock-name">شاشة الكمبيوتر</div>
        <div class="sock-hint">تشغيل عادي</div>
      </div>
      <div class="sock-bottom">
        <div class="sock-watt-box">
          <span class="sock-watt-val">9.7</span>
          <span class="sock-watt-unit">WATTS</span>
        </div>
        <div class="switch-btn">⏻</div>
      </div>
    </div>

    <!-- Socket 2: Router (Protected) -->
    <div class="socket-card active amber">
      <div class="sock-top">
        <span class="sock-voltage">228V · 30°C</span>
        <span class="sock-badge badge-router">🔒 راوتر محمي</span>
      </div>
      <div class="sock-middle">
        <div class="sock-icon-box">🌐</div>
        <div class="sock-name">راوتر البيت</div>
        <div class="sock-hint">محمي برقم سري</div>
      </div>
      <div class="sock-bottom">
        <div class="sock-watt-box">
          <span class="sock-watt-val">5.5</span>
          <span class="sock-watt-unit">WATTS</span>
        </div>
        <div class="switch-btn">⏻</div>
      </div>
    </div>

    <!-- Socket 3: Fridge (Compressor Safe Delay) -->
    <div class="socket-card active emerald">
      <div class="sock-top">
        <span class="sock-voltage">228V · 29°C</span>
        <span class="sock-badge badge-fridge">⏳ درع الكمبروسر</span>
      </div>
      <div class="sock-middle">
        <div class="sock-icon-box">❄️</div>
        <div class="sock-name">ثلاجة المطبخ</div>
        <div class="sock-hint">تأخير 10 دقائق بعد الانقطاع</div>
      </div>
      <div class="sock-bottom">
        <div class="sock-watt-box">
          <span class="sock-watt-val">49.4</span>
          <span class="sock-watt-unit">WATTS</span>
        </div>
        <div class="switch-btn">⏻</div>
      </div>
    </div>

    <!-- Socket 4: Charger (OFF) -->
    <div class="socket-card muted">
      <div class="sock-top">
        <span class="sock-voltage">228V</span>
        <span class="sock-badge" style="color:#64748B;">مخرج 4</span>
      </div>
      <div class="sock-middle">
        <div class="sock-icon-box">📱</div>
        <div class="sock-name">شاحن الموبايل</div>
        <div class="sock-hint">فصل تلقائي عند الاكتمال</div>
      </div>
      <div class="sock-bottom">
        <div class="sock-watt-box">
          <span class="sock-watt-val">0.0</span>
          <span class="sock-watt-unit">WATTS</span>
        </div>
        <div class="switch-btn">⏻</div>
      </div>
    </div>

  </div>

  <!-- Master Control Bar -->
  <div class="master-bar">
    <div class="master-btn">
      <span>⏻</span> تشغيل / إيقاف الكل (الراوتر مستثنى)
    </div>
  </div>

  <!-- Bottom Navigation -->
  <div class="nav-bar">
    <div class="nav-item active">
      <span class="nav-icon">🔌</span>
      <span>مشتركاتي</span>
    </div>
    <div class="nav-item">
      <span class="nav-icon">⏱️</span>
      <span>الجدولة</span>
    </div>
    <div class="nav-item">
      <span class="nav-icon">⭐</span>
      <span>المفضلة</span>
    </div>
    <div class="nav-item">
      <span class="nav-icon">📊</span>
      <span>الفاتورة</span>
    </div>
    <div class="nav-item">
      <span class="nav-icon">⚙️</span>
      <span>الإعدادات</span>
    </div>
  </div>
</div>

</body>
</html>
"""

with open('mockup_preview.html', 'w', encoding='utf-8') as f:
    f.write(html_content)

print("Created updated mockup_preview.html")
