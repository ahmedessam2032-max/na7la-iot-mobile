import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/socket_model.dart';
import '../../../data/repositories/strip_repository.dart';
import '../../schedules/widgets/repeating_cycle_sheet.dart';

class SocketDeepDiveSheet extends StatefulWidget {
  final String mac;
  final SocketModel socket;
  final bool isDark;
  final Function(SocketModel updatedSocket) onUpdated;

  const SocketDeepDiveSheet({
    super.key,
    required this.mac,
    required this.socket,
    required this.isDark,
    required this.onUpdated,
  });

  @override
  State<SocketDeepDiveSheet> createState() => _SocketDeepDiveSheetState();
}

class _SocketDeepDiveSheetState extends State<SocketDeepDiveSheet> {
  final _repo = StripRepository();
  late TextEditingController _nameController;
  late bool _isLocked;
  late bool _isRouter;
  late bool _compressorProtect;
  late String _powerOnBehavior;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.socket.name);
    _isLocked = widget.socket.isLocked;
    _isRouter = widget.socket.isRouter;
    _compressorProtect = widget.socket.compressorProtect;
    _powerOnBehavior = widget.socket.powerOnBehavior;
  }

  void _applyPreset(String type) {
    setState(() {
      if (type == 'fridge') {
        _compressorProtect = true;
        _isRouter = false;
        widget.socket.icon = 'snowflake';
        widget.socket.compressorDelaySec = 180;
      } else if (type == 'ac') {
        _compressorProtect = true;
        _isRouter = false;
        widget.socket.icon = 'wind';
        widget.socket.compressorDelaySec = 300;
      } else if (type == 'router') {
        _isRouter = true;
        _isLocked = true;
        _compressorProtect = false;
        widget.socket.icon = 'router';
      } else if (type == 'charger') {
        widget.socket.icon = 'charger';
        widget.socket.minWattCutoff = 3.0;
        widget.socket.cutoffDelaySec = 600;
      } else if (type == 'tv') {
        widget.socket.icon = 'tv';
      }
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    await _repo.configSocket(widget.mac, widget.socket.socketIndex, {
      'name': _nameController.text.trim(),
      'icon': widget.socket.icon,
      'is_router': _isRouter,
      'compressor_protect': _compressorProtect,
      'compressor_delay_sec': widget.socket.compressorDelaySec,
      'min_watt_cutoff': widget.socket.minWattCutoff,
      'power_on_behavior': _powerOnBehavior,
    });

    if (_isLocked != widget.socket.isLocked) {
      await _repo.lockSocket(widget.mac, widget.socket.socketIndex, _isLocked);
    }

    widget.socket.name = _nameController.text.trim();
    widget.socket.isLocked = _isLocked;
    widget.socket.isRouter = _isRouter;
    widget.socket.compressorProtect = _compressorProtect;
    widget.socket.powerOnBehavior = _powerOnBehavior;

    widget.onUpdated(widget.socket);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(
            color: widget.isDark ? AppColors.darkBorder : AppColors.inkBlack,
            width: 3.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Notch Handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'إعدادات المخرج #${widget.socket.socketIndex}',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Socket Name Input
            Text(
              'اسم المخرج:',
              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                filled: true,
                fillColor: widget.isDark ? AppColors.cardMutedDark : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.isDark ? AppColors.darkBorder : AppColors.inkBlack, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Presets Selection
            Text(
              '🔌 قوالب الأجهزة السريعة (تضبط الحماية تلقائياً):',
              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildPresetChip('❄️ تلاجة', () => _applyPreset('fridge')),
                _buildPresetChip('🌀 تكييف', () => _applyPreset('ac')),
                _buildPresetChip('🌐 راوتر', () => _applyPreset('router')),
                _buildPresetChip('📱 شاحن ذكي', () => _applyPreset('charger')),
                _buildPresetChip('📺 شاشة', () => _applyPreset('tv')),
              ],
            ),
            const SizedBox(height: 16),

            // Lock Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '🔐 قفل هذه الفيشة برقم PIN / البصمة',
                style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'منع الإطفاء أو التشغيل بالخطأ بدون إذن',
                style: GoogleFonts.cairo(fontSize: 10),
              ),
              value: _isLocked,
              activeColor: AppColors.honeyAmber,
              onChanged: (val) => setState(() => _isLocked = val),
            ),

            // Power-On Behavior Selector
            const SizedBox(height: 8),
            Text(
              'سلوك المخرج بعد عودة الكهرباء (Power-on Behavior):',
              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildBehaviorBtn('تشغيل (ON)', 'ON'),
                const SizedBox(width: 6),
                _buildBehaviorBtn('إطفاء (OFF)', 'OFF'),
                const SizedBox(width: 6),
                _buildBehaviorBtn('آخر حالة (LAST)', 'LAST'),
              ],
            ),
            const SizedBox(height: 16),

            // Reset Energy Counter Button
            OutlinedButton.icon(
              onPressed: () async {
                await _repo.resetEnergy(widget.mac, widget.socket.socketIndex);
                setState(() => widget.socket.rawEnergyKwh = 0.0);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تصفير عداد الطاقة لهذه الفيشة')),
                  );
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                'تصفير عداد الطاقة (Reset kWh)',
                style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: widget.isDark ? Colors.white70 : AppColors.inkBlack,
                side: BorderSide(color: widget.isDark ? Colors.white24 : Colors.black26),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // Repeating Cycles Action Button
            OutlinedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => RepeatingCycleSheet(
                    mac: widget.mac,
                    socket: widget.socket,
                    isDark: widget.isDark,
                    onCycleChanged: () {
                      widget.onUpdated(widget.socket);
                    },
                  ),
                );
              },
              icon: const Icon(Icons.sync_rounded, color: AppColors.routerCyan, size: 18),
              label: Text(
                'دورات التشغيل المتكررة (Repeating Cycles) 🔄',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: widget.isDark ? AppColors.routerCyan : const Color(0xFF0284C7),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.routerCyan, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Save Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.honeyYellow,
                foregroundColor: AppColors.inkBlack,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.inkBlack, width: 2),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkBlack),
                    )
                  : Text(
                      'حفظ وتطبيق الإعدادات ✓',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w800)),
      backgroundColor: widget.isDark ? AppColors.cardMutedDark : AppColors.honeyYellow.withOpacity(0.2),
      side: BorderSide(color: widget.isDark ? AppColors.darkBorder : AppColors.inkBlack, width: 1.5),
      onPressed: onTap,
    );
  }

  Widget _buildBehaviorBtn(String label, String value) {
    final isSelected = _powerOnBehavior == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _powerOnBehavior = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.honeyAmber : (widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.inkBlack : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              color: widget.isDark ? Colors.white : AppColors.inkBlack,
            ),
          ),
        ),
      ),
    );
  }
}
