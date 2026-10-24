import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_locale.dart';
import '../../data/models/strip_model.dart';
import '../../data/models/socket_model.dart';
import '../../widgets/socket_card.dart';

class FavoritesTab extends StatelessWidget {
  final StripModel? strip;
  final bool isDark;
  final Function(SocketModel socket) onToggleSocket;
  final Function(SocketModel socket) onOpenDeepDive;
  final Function(SocketModel socket)? onLockToggle;
  final VoidCallback onGoToDashboard;

  const FavoritesTab({
    super.key,
    required this.strip,
    required this.isDark,
    required this.onToggleSocket,
    required this.onOpenDeepDive,
    this.onLockToggle,
    required this.onGoToDashboard,
  });

  @override
  Widget build(BuildContext context) {
    final favoriteSockets = strip?.sockets.where((s) => s.isFavorite).toList() ?? [];
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (favoriteSockets.isNotEmpty && strip != null) ...[
            Text(
              trBi('⭐ المخارج المفضلة (تحكم فوري)', '⭐ Favorite Outlets (Quick Control)'),
              style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.w900, color: textPrimary),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: favoriteSockets.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.74,
              ),
              itemBuilder: (context, index) {
                final s = favoriteSockets[index];
                return SocketCard(
                  socket: s,
                  isDark: isDark,
                  voltage: strip!.voltage,
                  onToggle: () => onToggleSocket(s),
                  onOpenDeepDive: () => onOpenDeepDive(s),
                  onLockToggle: onLockToggle != null ? () => onLockToggle!(s) : null,
                );
              },
            ),
          ] else ...[
            Container(
              margin: const EdgeInsets.only(top: 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.emeraldActive.withOpacity(0.14),
                      border: Border.all(color: AppColors.emeraldActive.withOpacity(0.5), width: 1.6),
                    ),
                    child: const Icon(Icons.star_outline_rounded, size: 30, color: AppColors.emeraldActive),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    trBi('لا توجد مخارج مفضلة بعد', 'No Favorite Outlets Yet'),
                    style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    trBi(
                      'أضف المخارج التي تستخدمها كثيراً للتحكم فيها بلمسة واحدة من إعدادات المخرج ⚙️.',
                      'Mark your frequently used outlets as favorites from the outlet settings menu ⚙️ for one-tap access.',
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: onGoToDashboard,
                    icon: const Icon(Icons.power_rounded, size: 16),
                    label: Text(
                      trBi('استعراض مخارج المشترك', 'Browse Strip Outlets'),
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldActive,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
