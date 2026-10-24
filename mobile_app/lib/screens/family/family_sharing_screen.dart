import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/strip_model.dart';
import '../../data/repositories/strip_repository.dart';

class FamilySharingScreen extends StatefulWidget {
  final StripModel strip;
  final bool isDark;

  const FamilySharingScreen({
    super.key,
    required this.strip,
    required this.isDark,
  });

  @override
  State<FamilySharingScreen> createState() => _FamilySharingScreenState();
}

class _FamilySharingScreenState extends State<FamilySharingScreen> {
  final StripRepository _repo = StripRepository();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();

  bool _wholeStrip = true;
  final Set<int> _selectedSockets = {1, 2, 3, 4};
  String _permissionLevel = 'FULL'; // FULL | PARTIAL | VIEW
  List<dynamic> _shares = [];
  bool _isLoading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _loadShares();
  }

  Future<void> _loadShares() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.getShares(widget.strip.mac);
      if (mounted) {
        setState(() {
          _shares = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createRealShare() async {
    final name = _nameCtrl.text.trim().isEmpty
        ? (_emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim().split('@').first : 'فرد عائلة')
        : _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final socksStr = _wholeStrip
        ? '1,2,3,4'
        : (_selectedSockets.isEmpty ? '1' : (_selectedSockets.toList()..sort()).join(','));

    setState(() => _creating = true);
    try {
      final res = await _repo.createShare(
        widget.strip.mac,
        name,
        _wholeStrip ? _permissionLevel : 'PARTIAL',
        socksStr,
        email: email.isEmpty ? null : email,
      );
      if (!mounted) return;
      setState(() => _creating = false);
      if (res['ok'] == true) {
        final code = res['share']?['invite_code'] ?? '';
        _nameCtrl.clear();
        _emailCtrl.clear();
        await _loadShares();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء المشاركة بنجاح! كود الدعوة: $code'),
            backgroundColor: AppColors.emeraldActive,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['detail']?.toString() ?? 'تعذر إنشاء المشاركة'),
            backgroundColor: AppColors.dangerRed,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.dangerRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Create Real Share Card (Whole Strip or Specific Outlet + Email & Invite Code)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.inkCardDecoration(isDark: isDark, radius: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded, color: AppColors.emeraldActive),
                    SizedBox(width: 8),
                    Text(
                      'مشاركة المشترك أو مخرج محدد',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'شارك المشترك بالكامل أو مخرجاً واحداً فقط عبر البريد الإلكتروني أو كود دعوة سحابي فعلي:',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                const SizedBox(height: 12),

                // Scope Toggle: Whole Strip vs Single/Selected Outlets
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('المشترك بالكامل (4 مخارج)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                        selected: _wholeStrip,
                        selectedColor: AppColors.emeraldActive.withOpacity(0.2),
                        onSelected: (_) => setState(() {
                          _wholeStrip = true;
                          _selectedSockets
                            ..clear()
                            ..addAll([1, 2, 3, 4]);
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('مخرج محدد فقط', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                        selected: !_wholeStrip,
                        selectedColor: AppColors.emeraldActive.withOpacity(0.2),
                        onSelected: (_) => setState(() {
                          _wholeStrip = false;
                          _selectedSockets
                            ..clear()
                            ..add(1);
                        }),
                      ),
                    ),
                  ],
                ),

                if (!_wholeStrip) ...[
                  const SizedBox(height: 10),
                  const Text('اختر المخارج المسموح بالتحكم بها:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: widget.strip.sockets.map((s) {
                      final sel = _selectedSockets.contains(s.index);
                      return FilterChip(
                        selected: sel,
                        selectedColor: AppColors.emeraldActive.withOpacity(0.2),
                        label: Text('${s.name} (#${s.index})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _selectedSockets.add(s.index);
                            } else if (_selectedSockets.length > 1) {
                              _selectedSockets.remove(s.index);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'اسم الفرد أو الضيف',
                    hintText: 'مثال: أحمد / غرفة المعيشة',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني للمستخدم (اختياري)',
                    hintText: 'user@example.com',
                    prefixIcon: const Icon(Icons.email_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('مستوى الصلاحية:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('تحكم وتشغيل 🎛️', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                      selected: _permissionLevel != 'VIEW',
                      selectedColor: AppColors.emeraldActive.withOpacity(0.2),
                      onSelected: (_) => setState(() => _permissionLevel = 'FULL'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('مشاهدة فقط 👀', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                      selected: _permissionLevel == 'VIEW',
                      selectedColor: AppColors.routerCyan.withOpacity(0.2),
                      onSelected: (_) => setState(() => _permissionLevel = 'VIEW'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldActive,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _creating ? null : _createRealShare,
                    icon: _creating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.share_rounded, size: 18),
                    label: const Text('إنشاء مشاركة وتوليد كود الدعوة', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Active Shares List from Backend
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.inkCardDecoration(isDark: isDark, radius: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '👨‍👩‍👧 المشاركات الفعالة (${_shares.length})',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    IconButton(
                      onPressed: _loadShares,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator(color: AppColors.emeraldActive)),
                  )
                else if (_shares.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('لا توجد مشاركات مضافة حالياً لهذا المشترك', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  )
                else
                  ..._shares.map((sh) {
                    final int shId = (sh['id'] as num?)?.toInt() ?? 0;
                    final String name = (sh['name'] ?? sh['member_name'] ?? 'فرد عائلة').toString();
                    final String code = (sh['invite_code'] ?? '').toString();
                    final String email = (sh['email'] ?? '').toString();
                    final List socks = (sh['allowed_sockets'] as List?) ?? [1, 2, 3, 4];
                    final String perm = (sh['permission_level'] ?? 'FULL').toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                                if (email.isNotEmpty && !email.endsWith('@na7la.local'))
                                  Text(email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.emeraldActive.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        socks.length >= 4 ? 'كل المخارج (1-4)' : 'مخارج: ${socks.join(", ")}',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.emeraldActive),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        perm == 'VIEW' ? 'مشاهدة فقط' : 'تحكم',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    if (code.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: code));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('تم نسخ كود الدعوة: $code')),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.copy_rounded, size: 11, color: Colors.blue),
                                              const SizedBox(width: 3),
                                              Text(code, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.blue)),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'إلغاء المشاركة',
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.dangerRed),
                            onPressed: () async {
                              final ok = await _repo.deleteShare(shId);
                              if (ok) await _loadShares();
                            },
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
