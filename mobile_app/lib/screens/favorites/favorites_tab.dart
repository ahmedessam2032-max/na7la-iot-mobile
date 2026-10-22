import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/strip_model.dart';
import '../../data/models/socket_model.dart';
import '../../widgets/socket_card.dart';

class FavoritesTab extends StatelessWidget {
  final StripModel strip;
  final bool isDark;
  final Function(SocketModel socket) onToggleSocket;
  final Function(SocketModel socket) onOpenDeepDive;
  final VoidCallback onGoToDashboard;

  const FavoritesTab({
    super.key,
    required this.strip,
    required this.isDark,
    required this.onToggleSocket,
    required this.onOpenDeepDive,
    required this.onGoToDashboard,
  });

  @override
  Widget build(BuildContext context) {
    // Sockets that are marked favorite, or socket 4 (Router) / socket 1
    final favoriteSockets = strip.sockets.where((s) => s.isFavorite).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (favoriteSockets.isNotEmpty) ...[
            Text(
              '⭐ المخارج المفضلة (تحكم فوري)',
              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900),
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
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                final s = favoriteSockets[index];
                return SocketCard(
                  socket: s,
                  isDark: isDark,
                  voltage: strip.voltage,
                  onToggle: () => onToggleSocket(s),
                  onOpenDeepDive: () => onOpenDeepDive(s),
                );
              },
            ),
          ] else ...[
            // Empty State matching HTML #tab-favorites
            Container(
              margin: const EdgeInsets.only(top: 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1C) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF33312B) : Colors.black12,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.honeyYellow.withOpacity(0.15),
                      border: Border.all(color: AppColors.honeyYellow, width: 2),
                    ),
                    child: const Icon(Icons.star_outline_rounded, size: 30, color: AppColors.honeyYellow),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد مخارج مفضلة بعد',
                    style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'أضف المخارج التي تستخدمها كثيراً للتحكم فيها بلمسة واحدة من قائمة الإعدادات ⚙️.',
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
                      'استعراض مخارج المشترك',
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.honeyYellow,
                      foregroundColor: AppColors.inkBlack,
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
