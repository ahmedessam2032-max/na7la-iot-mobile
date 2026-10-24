import os, subprocess

# Mockup 1: Dashboard with 3-Dots Menu Open (Matching the user's uploaded image exactly)
html_menu = """<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Na7la IoT - 3-Dots Strip Menu</title>
<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;800;900&family=Inter:wght@400;600;700;900&display=swap" rel="stylesheet">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Cairo', sans-serif; }
  body { background: #080D1A; display: flex; justify-content: center; align-items: flex-start; padding: 10px; }
  .phone-frame {
    width: 395px; height: 840px; background: #0F172A; border-radius: 44px;
    box-shadow: 0 25px 60px rgba(0,0,0,0.9), 0 0 0 8px #1E293B, 0 0 0 10px #334155;
    overflow: hidden; display: flex; flex-direction: column; position: relative; border: 1px solid rgba(255,255,255,0.12);
  }
  .status-bar { height: 36px; padding: 10px 22px 0; display: flex; justify-content: space-between; align-items: center; color: #94A3B8; font-size: 12px; font-weight: 700; font-family: 'Inter'; }
  .app-header { padding: 8px 16px 6px; display: flex; justify-content: space-between; align-items: center; }
  .strip-title-box { display: flex; align-items: center; gap: 8px; }
  .strip-title { color: #FFFFFF; font-size: 16px; font-weight: 800; }
  .three-dots-btn { width: 32px; height: 32px; border-radius: 8px; background: rgba(59, 130, 246, 0.15); border: 1px solid #3B82F6; color: #60A5FA; display: flex; justify-content: center; align-items: center; font-size: 18px; cursor: pointer; }
  .online-badge { background: rgba(16, 185, 129, 0.15); color: #10B981; border: 1px solid rgba(16, 185, 129, 0.4); font-size: 10px; font-weight: 700; padding: 2px 7px; border-radius: 12px; display: flex; align-items: center; gap: 4px; }
  .online-dot { width: 5px; height: 5px; background: #10B981; border-radius: 50%; }

  /* Background Dashboard Content (Subtly Dimmed for Menu Overlay) */
  .dashboard-dimmed { flex: 1; display: flex; flex-direction: column; opacity: 0.25; filter: blur(2px); pointer-events: none; }
  .kpi-bar { margin: 6px 14px; background: #1E293B; border-radius: 16px; padding: 10px; display: flex; justify-content: space-around; }
  .grid-container { margin: 0 14px; display: grid; grid-template-columns: 1fr 1fr; gap: 10px; height: 360px; }
  .socket-card { background: #1E293B; border-radius: 18px; }

  /* The 3-Dots Dropdown Menu (Matching User's Uploaded Image Exactly) */
  .menu-overlay {
    position: absolute;
    top: 80px;
    right: 16px;
    width: 250px;
    background: #111C2E;
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 18px;
    box-shadow: 0 20px 45px rgba(0, 0, 0, 0.75), 0 0 0 1px rgba(59, 130, 246, 0.2);
    padding: 8px 0;
    z-index: 100;
    backdrop-filter: blur(16px);
  }
  .menu-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 9px 16px;
    color: #E2E8F0;
    font-size: 13px;
    font-weight: 700;
    cursor: pointer;
    border-bottom: 1px solid rgba(255, 255, 255, 0.03);
    transition: background 0.15s;
  }
  .menu-item:hover { background: rgba(255, 255, 255, 0.06); }
  .menu-item-left { display: flex; align-items: center; gap: 10px; }
  .menu-icon { font-size: 15px; width: 20px; text-align: center; }
  .menu-item.danger { color: #F87171; border-bottom: none; margin-top: 4px; }
  .menu-item.danger .menu-icon { color: #F87171; }
  .menu-badge { font-size: 9px; padding: 2px 6px; border-radius: 6px; font-weight: 800; }
  .badge-gold { background: rgba(245, 158, 11, 0.2); color: #FBBF24; }
  .badge-cyan { background: rgba(56, 189, 248, 0.2); color: #38BDF8; }

  .nav-bar { height: 60px; background: #0B1120; border-top: 1px solid rgba(255, 255, 255, 0.07); display: flex; justify-content: space-around; align-items: center; }
  .nav-item { display: flex; flex-direction: column; align-items: center; gap: 2px; color: #64748B; font-size: 10px; font-weight: 700; }
  .nav-item.active { color: #F59E0B; }
</style>
</head>
<body>
<div class="phone-frame">
  <div class="status-bar"><span>12:45</span><span>5G · 📶 · 100% 🔋</span></div>

  <div class="app-header">
    <div class="strip-title-box">
      <div class="three-dots-btn">⋮</div>
      <div class="strip-title">مشترك الصالة الذكي</div>
      <div class="online-badge"><span class="online-dot"></span>متصل</div>
    </div>
    <div style="font-size: 11px; color: #FBBF24; font-weight: 700; background: rgba(245,158,11,0.15); padding: 3px 8px; border-radius: 10px;">
      👶 قفل الأطفال
    </div>
  </div>

  <!-- Background Dimmed -->
  <div class="dashboard-dimmed">
    <div class="kpi-bar">
      <div>65.4 W</div><div>228 V</div><div>4.50 ج.م</div>
    </div>
    <div class="grid-container">
      <div class="socket-card"></div><div class="socket-card"></div>
      <div class="socket-card"></div><div class="socket-card"></div>
    </div>
  </div>

  <!-- The Full 3-Dots Dropdown Menu -->
  <div class="menu-overlay">
    <div class="menu-item">
      <div class="menu-item-left"><span class="menu-icon">✏️</span><span>إعادة تسمية المشترك</span></div>
    </div>
    <div class="menu-item">
      <div class="menu-item-left"><span class="menu-icon">⏱️</span><span>جدولة ومؤقّت</span></div>
    </div>
    <div class="menu-item">
      <div class="menu-item-left"><span class="menu-icon">📊</span><span>إحصائيات الطاقة & Excel</span></div>
      <span class="menu-badge badge-gold">xlsx</span>
    </div>
    <div class="menu-item">
      <div class="menu-item-left"><span class="menu-icon">🕒</span><span>سجل النشاط والأحداث</span></div>
    </div>
    <div class="menu-item">
      <div class="menu-item-left"><span class="menu-icon">📈</span><span>فحص حالة المشترك</span></div>
      <span class="menu-badge badge-cyan">تشخيص</span>
    </div>
    <div class="menu-item">
      <div class="menu-item-left"><span class="menu-icon">🪟</span><span>تثبيت في الويدجت</span></div>
    </div>
    <div class="menu-item">
      <div class="menu-item-left"><span class="menu-icon">🛡️</span><span>حماية الجهد (180V-250V)</span></div>
    </div>
    <div class="menu-item">
      <div class="menu-item-left"><span class="menu-icon">👥</span><span>مشاركة الجهاز والعائلة</span></div>
    </div>
    <div class="menu-item">
      <div class="menu-item-left"><span class="menu-icon">🔒</span><span>قفل التحكم بكلمة سر</span></div>
    </div>
    <div class="menu-item">
      <div class="menu-item-left"><span class="menu-icon">☝️</span><span>بصمة الإصبع البيومترية</span></div>
    </div>
    <div class="menu-item">
      <div class="menu-item-left"><span class="menu-icon">👶</span><span>قفل أزرار المشترك (الأطفال)</span></div>
      <span class="menu-badge badge-gold">MCU</span>
    </div>
    <div class="menu-item danger">
      <div class="menu-item-left"><span class="menu-icon">🗑️</span><span>حذف المشترك</span></div>
    </div>
  </div>

  <div class="nav-bar">
    <div class="nav-item active"><span>🔌</span><span>مشتركاتي</span></div>
    <div class="nav-item"><span>⏱️</span><span>الجدولة</span></div>
    <div class="nav-item"><span>⭐</span><span>المفضلة</span></div>
    <div class="nav-item"><span>📊</span><span>الفاتورة</span></div>
    <div class="nav-item"><span>👤</span><span>حسابي</span></div>
  </div>
</div>
</body>
</html>
"""

# Mockup 2: The "حسابي" (My Account) Screen with Logout, Profile, Change Password, Admin Console
html_account = """<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Na7la IoT - My Account Screen</title>
<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;800;900&family=Inter:wght@400;600;700;900&display=swap" rel="stylesheet">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Cairo', sans-serif; }
  body { background: #080D1A; display: flex; justify-content: center; align-items: flex-start; padding: 10px; }
  .phone-frame {
    width: 395px; height: 840px; background: #0F172A; border-radius: 44px;
    box-shadow: 0 25px 60px rgba(0,0,0,0.9), 0 0 0 8px #1E293B, 0 0 0 10px #334155;
    overflow: hidden; display: flex; flex-direction: column; position: relative; border: 1px solid rgba(255,255,255,0.12);
  }
  .status-bar { height: 36px; padding: 10px 22px 0; display: flex; justify-content: space-between; align-items: center; color: #94A3B8; font-size: 12px; font-weight: 700; font-family: 'Inter'; }
  .screen-header { padding: 12px 18px 8px; display: flex; justify-content: space-between; align-items: center; }
  .screen-title { color: #FFFFFF; font-size: 18px; font-weight: 800; }
  
  /* User Profile Card */
  .profile-card {
    margin: 8px 16px 14px;
    background: linear-gradient(135deg, #1E293B 0%, #172554 100%);
    border: 1px solid rgba(59, 130, 246, 0.3);
    border-radius: 20px;
    padding: 14px 16px;
    display: flex;
    align-items: center;
    gap: 14px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.35);
  }
  .avatar-box {
    width: 50px; height: 50px; border-radius: 16px;
    background: linear-gradient(135deg, #F59E0B 0%, #D97706 100%);
    display: flex; justify-content: center; align-items: center;
    font-size: 24px; color: #FFFFFF; font-weight: 900;
    box-shadow: 0 4px 14px rgba(245, 158, 11, 0.4);
  }
  .user-info { display: flex; flex-direction: column; gap: 2px; }
  .user-name { color: #FFFFFF; font-size: 15px; font-weight: 800; }
  .user-email { color: #94A3B8; font-size: 11px; font-weight: 600; font-family: 'Inter'; }
  .user-role-badge {
    align-self: flex-start;
    margin-top: 3px;
    background: rgba(245, 158, 11, 0.2);
    color: #FBBF24;
    border: 1px solid rgba(245, 158, 11, 0.4);
    font-size: 9px; font-weight: 800; padding: 2px 8px; border-radius: 10px;
  }

  /* Settings Menu List */
  .menu-section {
    flex: 1;
    padding: 0 16px;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .section-label { color: #64748B; font-size: 11px; font-weight: 700; margin: 4px 6px 2px; }
  .menu-group {
    background: #1E293B;
    border-radius: 18px;
    border: 1px solid rgba(255, 255, 255, 0.05);
    overflow: hidden;
  }
  .menu-row {
    padding: 12px 14px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.04);
    cursor: pointer;
  }
  .menu-row:last-child { border-bottom: none; }
  .menu-row-left { display: flex; align-items: center; gap: 12px; }
  .menu-row-icon {
    width: 32px; height: 32px; border-radius: 10px;
    background: rgba(255, 255, 255, 0.06);
    display: flex; justify-content: center; align-items: center;
    font-size: 16px;
  }
  .menu-row-text { display: flex; flex-direction: column; }
  .menu-row-title { color: #FFFFFF; font-size: 13px; font-weight: 700; }
  .menu-row-subtitle { color: #64748B; font-size: 10px; font-weight: 600; }
  .arrow { color: #64748B; font-size: 12px; font-weight: 900; }

  /* Admin Badge Row */
  .admin-row {
    background: linear-gradient(135deg, rgba(245, 158, 11, 0.15) 0%, rgba(30, 41, 59, 0.8) 100%);
    border: 1px solid rgba(245, 158, 11, 0.35);
  }

  /* Logout Button */
  .logout-btn {
    margin: 10px 16px 14px;
    background: rgba(239, 68, 68, 0.12);
    border: 1px solid rgba(239, 68, 68, 0.4);
    color: #F87171;
    border-radius: 16px;
    padding: 12px;
    font-size: 13px;
    font-weight: 800;
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 8px;
    cursor: pointer;
    box-shadow: 0 4px 14px rgba(239, 68, 68, 0.15);
  }

  .nav-bar { height: 60px; background: #0B1120; border-top: 1px solid rgba(255, 255, 255, 0.07); display: flex; justify-content: space-around; align-items: center; }
  .nav-item { display: flex; flex-direction: column; align-items: center; gap: 2px; color: #64748B; font-size: 10px; font-weight: 700; }
  .nav-item.active { color: #F59E0B; }
</style>
</head>
<body>
<div class="phone-frame">
  <div class="status-bar"><span>12:45</span><span>5G · 📶 · 100% 🔋</span></div>

  <div class="screen-header">
    <div class="screen-title">حسابي والإعدادات</div>
    <div style="font-size: 12px; color: #10B981; font-weight: 700;">v1.3 Na7la</div>
  </div>

  <!-- Profile Card -->
  <div class="profile-card">
    <div class="avatar-box">أ</div>
    <div class="user-info">
      <div class="user-name">أحمد عصام (المالك)</div>
      <div class="user-email">ahmedessam2032@gmail.com</div>
      <div class="user-role-badge">👑 SUPER ADMIN</div>
    </div>
  </div>

  <div class="menu-section">
    <!-- Admin Portal -->
    <div class="section-label">إدارة المنصة</div>
    <div class="menu-group admin-row">
      <div class="menu-row">
        <div class="menu-row-left">
          <div class="menu-row-icon" style="background: rgba(245,158,11,0.25); color:#FBBF24;">👑</div>
          <div class="menu-row-text">
            <div class="menu-row-title">بوابة إدارة الأسطول (Admin Fleet)</div>
            <div class="menu-row-subtitle">إدارة كل المشتركات، والعملاء، وسجلات السيرفر</div>
          </div>
        </div>
        <span class="arrow">◀</span>
      </div>
    </div>

    <!-- Security & Account -->
    <div class="section-label">الأمان والحساب</div>
    <div class="menu-group">
      <div class="menu-row">
        <div class="menu-row-left">
          <div class="menu-row-icon">🔑</div>
          <div class="menu-row-text">
            <div class="menu-row-title">تغيير كلمة المرور</div>
            <div class="menu-row-subtitle">تحديث كلمة سر الدخول للحساب</div>
          </div>
        </div>
        <span class="arrow">◀</span>
      </div>
      <div class="menu-row">
        <div class="menu-row-left">
          <div class="menu-row-icon">🔒</div>
          <div class="menu-row-text">
            <div class="menu-row-title">رمز PIN والأمان البيومتري</div>
            <div class="menu-row-subtitle">حماية المخارج ببصمة الإصبع أو PIN</div>
          </div>
        </div>
        <span class="arrow">◀</span>
      </div>
    </div>

    <!-- Strips & Connectivity -->
    <div class="section-label">المشتركات والأجهزة</div>
    <div class="menu-group">
      <div class="menu-row">
        <div class="menu-row-left">
          <div class="menu-row-icon">➕</div>
          <div class="menu-row-text">
            <div class="menu-row-title">إضافة مشترك جديد</div>
            <div class="menu-row-subtitle">ربط عبر الواي فاي أو الرقم التسلسلي MAC</div>
          </div>
        </div>
        <span class="arrow">◀</span>
      </div>
      <div class="menu-row">
        <div class="menu-row-left">
          <div class="menu-row-icon">🩺</div>
          <div class="menu-row-text">
            <div class="menu-row-title">الفحص والتشخيص الذاتي (Diagnostics)</div>
            <div class="menu-row-subtitle">فحص اتصال السيرفر وبورت 10086 والراوتر</div>
          </div>
        </div>
        <span class="arrow">◀</span>
      </div>
      <div class="menu-row">
        <div class="menu-row-left">
          <div class="menu-row-icon">🎧</div>
          <div class="menu-row-text">
            <div class="menu-row-title">الدعم الفني المباشر</div>
            <div class="menu-row-subtitle">تواصل عبر واتساب أو الاتصال الهاتفي</div>
          </div>
        </div>
        <span class="arrow">◀</span>
      </div>
    </div>
  </div>

  <!-- Logout Button -->
  <div class="logout-btn">
    <span>🚪</span>
    <span>تسجيل الخروج من الحساب</span>
  </div>

  <div class="nav-bar">
    <div class="nav-item"><span>🔌</span><span>مشتركاتي</span></div>
    <div class="nav-item"><span>⏱️</span><span>الجدولة</span></div>
    <div class="nav-item"><span>⭐</span><span>المفضلة</span></div>
    <div class="nav-item"><span>📊</span><span>الفاتورة</span></div>
    <div class="nav-item active"><span>👤</span><span>حسابي</span></div>
  </div>
</div>
</body>
</html>
"""

with open('mockup_menu.html', 'w', encoding='utf-8') as f:
    f.write(html_menu)
with open('mockup_account.html', 'w', encoding='utf-8') as f:
    f.write(html_account)

print("Generated HTML for 3-dots menu and account screen")
