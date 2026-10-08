/// حامل جلسة الجرد الفعلي — مسودة عدّ واحدة حية طوال جلسة التطبيق.
///
/// **لماذا؟ (P0-1a — فقدان بيانات صامت)**: كانت الشاشة تبني نموذجها داخل
/// `build()` فيُدمَّر بمغادرة المسار، و`load()` يفرغ الأسطر، و`RefreshOnActive`
/// يعيد التحميل عند كل تنشيط — فتبديل تبويب أو قفل تلقائي يمسح عدّ 200 صنف
/// بصمت. هذا الحامل يطبّق **نفس نمط SellCartSession** (السلة التي تنجو من
/// التنقل والقفل): النموذج يعيش هنا، والشاشة تتصل به عند كل بناء.
///
/// تحسّن موثّق عن نمط السلة: الجلسة تتحقق من **هوية القاعدة** — بعد مسح أو
/// استعادة يعيد AppController تبنّي قاعدة جديدة، فتُبنى مسودة جديدة فوقها
/// بدل نموذج يحمل مستودعات قاعدة مغلقة.
library;

import '../../../../core/storage/app_database.dart';
import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/stocktake_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import 'stocktake_view_model.dart';

/// جلسة مسودة جرد واحدة لكل تشغيل تطبيق.
class StocktakeSession {
  StocktakeViewModel? _viewModel;
  AppDatabase? _database;

  /// يعيد نموذج الجرد الحي — ينشئه عند أول طلب (أو بعد تغيّر القاعدة)
  /// ثم يعيد نفس الكائن مهما تنقّل المستخدم بين الشاشات أو قُفل التطبيق.
  StocktakeViewModel attach({
    required AppDatabase database,
    required StocktakeRepository stocktakeRepo,
    required UserRepository userRepo,
    required CompanyRepository companyRepo,
  }) {
    final current = _viewModel;
    if (current != null && identical(_database, database)) {
      return current;
    }
    final created = StocktakeViewModel(
      stocktakeRepo: stocktakeRepo,
      userRepo: userRepo,
      companyRepo: companyRepo,
    );
    _viewModel = created;
    _database = database;
    return created;
  }

  /// يعيد الجلسة لحالتها الأولى (الاختبارات — بداية نظيفة لكل قاعدة).
  void reset() {
    _viewModel = null;
    _database = null;
  }

  /// المسودة الحالية إن وُجدت (للاختبارات والفحص).
  StocktakeViewModel? get current => _viewModel;
}

/// الجلسة التطبيقية الوحيدة لمسودة الجرد.
final StocktakeSession stocktakeSession = StocktakeSession();
