/// تهشير رمز PIN وعبارة المرور — PBKDF2-HMAC-SHA256 (نقي، بلا اعتماد إطار).
///
/// قرار هندسي موثّق (المرحلة 1): SRS §5.3 يحدد `pin_hash` بـ Argon2id ضمن
/// منظومة التشفير الكاملة (FR-12-03: اشتقاق مفتاح 256-bit من عبارة المرور
/// + SQLCipher — NFR-05) التي تُفعَّل في مرحلة التصلب. إلى ذلك الحين
/// يعتمد التطبيق PBKDF2-HMAC-SHA256 بـ 100,000 دورة وملح عشوائي 16 بايت
/// (مقاومة لهجمات القاموس على ملف القاعدة) — والدفاع الأول عن فضاء PIN
/// الصغير هو **سياسة القفل** (FR-12-06) المفعلة كاملة في `pin_policy.dart`.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// تهشير و تحقق رمز PIN/عبارة المرور.
class PinHasher {
  const PinHasher._();

  /// عدد دورات PBKDF2.
  static const int iterations = 100000;

  /// طول المفتاح المشتق (بايت).
  static const int keyLength = 32;

  /// طول الملح العشوائي (بايت).
  static const int saltLength = 16;

  /// بادئة صيغة التخزين: `pbkdf2-sha256$iter$salt$hash` (سداسي عشري).
  static const String scheme = 'pbkdf2-sha256';

  /// يهشّر [pin] ويعيد السلسلة المخزَّنة.
  static String hash(String secret) {
    final salt = _randomBytes(saltLength);
    final key = _pbkdf2(utf8.encode(secret), salt, iterations, keyLength);
    return '$scheme\$$iterations\$${_hex(salt)}\$${_hex(key)}';
  }

  /// يتحقق من [secret] مقابل سلسلة مخزَّنة — مقارنة زمنية ثابتة.
  static bool verify(String secret, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != scheme) return false;
    final iter = int.tryParse(parts[1]);
    final salt = _unhex(parts[2]);
    final expected = _unhex(parts[3]);
    if (iter == null || salt.isEmpty || expected.isEmpty) return false;
    final actual = _pbkdf2(utf8.encode(secret), salt, iter, expected.length);
    // مقارنة XOR تراكمية — لا خروج مبكر (ثبات زمني).
    var diff = 0;
    for (var i = 0; i < expected.length; i++) {
      diff |= expected[i] ^ (i < actual.length ? actual[i] : 0);
    }
    return diff == 0;
  }

  /// صيغة PIN صالحة: 4 إلى 6 خانات رقمية.
  static bool isValidPinFormat(String pin) =>
      RegExp(r'^[0-9]{4,6}$').hasMatch(pin);

  /// عبارة مرور صالحة: 8 خانات فأكثر (FR-12-03).
  static bool isValidPassphrase(String passphrase) => passphrase.length >= 8;

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
  }

  /// PBKDF2 قياسي (RFC 2898) فوق HMAC-SHA256.
  static Uint8List _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = crypto.Hmac(crypto.sha256, password);
    final blockCount = (keyLength + 31) ~/ 32;
    final out = BytesBuilder(copy: false);
    for (var block = 1; block <= blockCount; block++) {
      final blockIndex = Uint8List(4)
        ..[0] = (block >> 24) & 0xFF
        ..[1] = (block >> 16) & 0xFF
        ..[2] = (block >> 8) & 0xFF
        ..[3] = block & 0xFF;
      final saltAndBlock = Uint8List.fromList([...salt, ...blockIndex]);
      var u = Uint8List.fromList(hmac.convert(saltAndBlock).bytes);
      final result = Uint8List.fromList(u);
      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < result.length; j++) {
          result[j] ^= u[j];
        }
      }
      out.add(result);
    }
    final bytes = out.toBytes();
    return Uint8List.sublistView(bytes, 0, keyLength);
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _unhex(String hex) {
    if (hex.length.isOdd) return const <int>[];
    final out = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      final v = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (v == null) return const <int>[];
      out.add(v);
    }
    return out;
  }
}
