import 'package:home_widget/home_widget.dart';
import '../../data/models/strip_model.dart';

class HomeWidgetService {
  static const String appWidgetProviderName = 'Na7laWidgetProvider';

  /// تحديث بيانات ويدجت الشاشة الرئيسية بالأندرويد بالقيم اللحظية للخلية
  static Future<void> updateFromStrip(StripModel strip) async {
    try {
      await HomeWidget.saveWidgetData<String>('total_watts', '${strip.totalWatt.toStringAsFixed(1)} W');
      await HomeWidget.saveWidgetData<String>('voltage', '${strip.voltage.toStringAsFixed(0)} V');
      await HomeWidget.saveWidgetData<String>('strip_status', strip.isOnline ? 'متصل ⚡' : 'غير متصل');
      await HomeWidget.saveWidgetData<String>('strip_name', strip.stripName);

      // حفظ حالات المقابس الأربعة
      for (final s in strip.sockets) {
        await HomeWidget.saveWidgetData<bool>('socket_${s.socketIndex}_on', s.state);
        await HomeWidget.saveWidgetData<String>('socket_${s.socketIndex}_name', s.name);
      }

      await HomeWidget.updateWidget(
        name: appWidgetProviderName,
        androidName: appWidgetProviderName,
        qualifiedAndroidName: 'com.na7la.iot.$appWidgetProviderName',
      );
    } catch (e) {
      // Ignored if platform channels are unavailable in headless mode
    }
  }
}
