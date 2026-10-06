/// نمط `Result<T,E>` — SRS §0.3: تحقق مركزي بلا استثناءات غير منضبطة.
///
/// كل حالات الاستخدام المحاسبية تعيد `Result` بدلاً من الرمي، وتتولى
/// الواجهة عرض الخطأ وفق قاعدة صياغة رسائل الخطأ (§6.3).
library;

/// نتيجة ناجحة تحمل قيمة.
final class Ok<T, E> extends Result<T, E> {
  const Ok(this.value);

  /// القيمة الناجحة.
  final T value;
}

/// نتيجة فاشلة تحمل خطأً موصوفاً.
final class Err<T, E> extends Result<T, E> {
  const Err(this.error);

  /// الخطأ.
  final E error;
}

/// النتيجة الثنائية (نجاح/فشل) بلا رمي.
sealed class Result<T, E> {
  const Result();

  /// هل النتيجة نجاح؟
  bool get isOk => this is Ok<T, E>;

  /// هل النتيجة فشل؟
  bool get isErr => this is Err<T, E>;

  /// القيمة عند النجاح (وإلا `null`).
  T? get valueOrNull {
    final self = this;
    return self is Ok<T, E> ? self.value : null;
  }

  /// الخطأ عند الفشل (وإلا `null`).
  E? get errorOrNull {
    final self = this;
    return self is Err<T, E> ? self.error : null;
  }

  /// يطابق النتيجة إلى قيمة واحدة.
  R fold<R>(R Function(T value) onOk, R Function(E error) onErr) {
    final self = this;
    return switch (self) {
      final Ok<T, E> ok => onOk(ok.value),
      final Err<T, E> err => onErr(err.error),
    };
  }

  /// يحوّل قيمة النجاح مع الإبقاء على الخطأ.
  Result<R, E> map<R>(R Function(T value) transform) {
    final self = this;
    return switch (self) {
      final Ok<T, E> ok => Ok<R, E>(transform(ok.value)),
      final Err<T, E> err => Err<R, E>(err.error),
    };
  }
}

/// خطأ نطاقي موصوف بكلمات المستخدم — يُعرض كما هو في الواجهة.
///
/// الصيغة الملزمة (§6.3): (ماذا حدث) + (ما الحل) + (زر الإجراء اختياري).
class DomainError {
  const DomainError(this.message, {this.actionLabel});

  /// الرسالة الرئيسية بكلمات المستخدم.
  final String message;

  /// نص زر الإجراء المقترح إن وُجد.
  final String? actionLabel;

  @override
  String toString() => message;
}
