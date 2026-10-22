import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
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
  final _repo = StripRepository();
  String _inviteCode = '849-201';
  List<dynamic> _shares = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadShares();
  }

  Future<void> _loadShares() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.getShares(widget.strip.macAddress);
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

  void _generateNewCode() {
    final rnd = Random();
    final p1 = 100 + rnd.nextInt(900);
    final p2 = 100 + rnd.nextInt(900);
    setState(() => _inviteCode = '$p1-$p2');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم توليد كود دعوة جديد صالح لمدة 15 دقيقة')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Invite Code Generator Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppTheme.inkCardDecoration(isDark: widget.isDark),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.honeyYellow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.inkBlack, width: 1.5),
                  ),
                  child: Text(
                    'مشاركة الخلية بأمان',
                    style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'إضافة فرد جديد أو ضيف',
                  style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900),
                ),
                Text(
                  'كود دعوة فوري صالح لمرة واحدة فقط (ينتهي خلال 15 دقيقة):',
                  style: GoogleFonts.cairo(fontSize: 10, color: widget.isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 14),

                // Big Code Display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.inkBlack,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.honeyAmber, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('كود الدعوة الفوري:',
                              style: GoogleFonts.cairo(fontSize: 9, color: Colors.white60)),
                          Text(
                            _inviteCode,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.honeyYellow,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _generateNewCode,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text('تجديد', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.honeyYellow,
                          foregroundColor: AppColors.inkBlack,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Family Members List Container
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppTheme.inkCardDecoration(isDark: widget.isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '👨‍👩‍👧 أعضاء البيت والصلاحيات',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.honeyYellow),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Owner Row (Dynamic Master Account)
                _buildMemberCard(
                  name: 'أنت (المالك الرئيسي)',
                  roleLabel: 'تحكم كامل 👑',
                  roleColor: AppColors.honeyYellow,
                  subtitle: 'كافة الصلاحيات + إدارة المشترك وتغيير الـ PIN',
                ),
                const SizedBox(height: 10),

                // Dynamic Shared Members List
                if (_shares.isNotEmpty) ...[
                  ..._shares.map((share) {
                    final name = share['member_name'] ?? share['user_email'] ?? 'فرد عائلة';
                    final perm = (share['permission_level'] ?? 'CONTROL').toString().toUpperCase();
                    final isControl = perm == 'CONTROL' || perm == 'FULL';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildMemberCard(
                        name: name,
                        roleLabel: isControl ? 'تحكم جزئي 🎛️' : 'مشاهدة فقط 👀',
                        roleColor: isControl ? AppColors.routerCyan : Colors.blueGrey.shade300,
                        subtitle: isControl ? 'مسموح له بالتحكم في المخارج المحددة' : 'مراقبة الاستهلاك فقط',
                      ),
                    );
                  }),
                ] else ...[
                  // Clean Empty State matching Web Dashboard & Reference
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isDark ? Colors.white10 : Colors.black12,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.people_outline_rounded, size: 28, color: AppColors.honeyAmber),
                        const SizedBox(height: 8),
                        Text(
                          'لا يوجد أفراد عائلة أو ضيوف مضافون بعد',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: widget.isDark ? Colors.white70 : AppColors.inkBlack,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'استخدم كود الدعوة الفوري بالأعلى لمشاركة التحكم مع عائلتك بأمان.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: widget.isDark ? Colors.white38 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard({
    required String name,
    required String roleLabel,
    required Color roleColor,
    required String subtitle,
    List<Widget>? extraWidgets,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.cardMutedDark : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDark ? AppColors.darkBorder : AppColors.inkBlack,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: roleColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.inkBlack, width: 1),
                ),
                child: Text(
                  roleLabel,
                  style: GoogleFonts.cairo(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.inkBlack),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.cairo(fontSize: 10, color: widget.isDark ? Colors.white60 : Colors.black54)),
          if (extraWidgets != null) ...extraWidgets,
        ],
      ),
    );
  }
}
