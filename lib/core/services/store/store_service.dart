import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/constants.dart';
import '../printer/printer_service.dart';

class StoreService {
  final SharedPreferences _prefs;
  final FirebaseFirestore _firestore;
  final PrinterService _printerService;

  StoreService(this._prefs, this._firestore, this._printerService);

  String get activeStoreCode {
    return _prefs.getString(Constants.activeStoreCodeKey) ?? 'LAKKU-01';
  }

  Future<void> setActiveStoreCode(String code) async {
    final sanitized = code.trim().toUpperCase().replaceAll(' ', '-');
    await _prefs.setString(Constants.activeStoreCodeKey, sanitized);
  }

  /// Sync local printer, theme, and branding settings to Firestore under Store/{storeCode}
  Future<void> syncSettingsToCloud([String? targetCode]) async {
    final code = targetCode ?? activeStoreCode;
    if (code.isEmpty) return;

    try {
      final docRef = _firestore.collection('Store').doc(code);

      String? logoBase64;
      final logoPath = _printerService.receiptLogoPath;
      if (logoPath != null && logoPath.isNotEmpty) {
        final logoFile = File(logoPath);
        if (logoFile.existsSync()) {
          final bytes = await logoFile.readAsBytes();
          logoBase64 = base64Encode(bytes);
        }
      }

      final accentColor = _prefs.getInt(Constants.selectedAccentColorKey);
      final brightness = _prefs.getString(Constants.selectedBrightnessKey);
      final paperSize = _printerService.paperSize.value;
      final headerTitle = _printerService.receiptHeaderTitle;
      final headerSubtitle = _printerService.receiptHeaderSubtitle;
      final hideHeaderTitle = _printerService.hideReceiptHeaderTitle;
      final hideHeaderSubtitle = _printerService.hideReceiptHeaderSubtitle;

      await docRef.set({
        'storeCode': code,
        'headerTitle': headerTitle,
        'headerSubtitle': headerSubtitle,
        'hideHeaderTitle': hideHeaderTitle,
        'hideHeaderSubtitle': hideHeaderSubtitle,
        'paperSize': paperSize,
        if (accentColor != null) 'accentColor': accentColor,
        if (brightness != null) 'brightness': brightness,
        if (logoBase64 != null) 'logoBase64': logoBase64,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Fetch settings from Firestore Store/{storeCode} and apply them to local Printer & Theme
  Future<bool> fetchAndApplyCloudSettings([String? targetCode]) async {
    final code = targetCode ?? activeStoreCode;
    if (code.isEmpty) return false;

    try {
      final doc = await _firestore.collection('Store').doc(code).get();
      if (!doc.exists || doc.data() == null) return false;

      final data = doc.data()!;
      if (data['headerTitle'] is String) {
        await _printerService.setReceiptHeaderTitle(data['headerTitle']);
      }
      if (data['headerSubtitle'] is String) {
        await _printerService.setReceiptHeaderSubtitle(data['headerSubtitle']);
      }
      if (data['hideHeaderTitle'] is bool) {
        await _printerService.setHideReceiptHeaderTitle(data['hideHeaderTitle']);
      }
      if (data['hideHeaderSubtitle'] is bool) {
        await _printerService.setHideReceiptHeaderSubtitle(data['hideHeaderSubtitle']);
      }
      if (data['accentColor'] is int) {
        await _prefs.setInt(Constants.selectedAccentColorKey, data['accentColor']);
      }
      if (data['brightness'] is String) {
        await _prefs.setString(Constants.selectedBrightnessKey, data['brightness']);
      }

      // Restore logo if available and missing locally
      if (data['logoBase64'] is String && (data['logoBase64'] as String).isNotEmpty) {
        final bytes = base64Decode(data['logoBase64'] as String);
        final appDir = await getApplicationDocumentsDirectory();
        final localFile = File('${appDir.path}/store_logo_$code.png');
        await localFile.writeAsBytes(bytes);
        await _printerService.setReceiptLogoPath(localFile.path);
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
