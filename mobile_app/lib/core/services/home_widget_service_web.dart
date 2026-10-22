import '../../data/models/strip_model.dart';

class HomeWidgetService {
  static const String appWidgetProviderName = 'Na7laWidgetProvider';

  /// Dummy implementation for Web platform (Android AppWidgets do not exist on Web)
  static Future<void> updateFromStrip(StripModel strip) async {
    // No-op on Web
  }
}
