import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

class PrinterSettingsState {
  final bool isScanning;
  final String? connectingDeviceId;
  final bool isDisconnecting;
  final List<PrinterDevice> printers;
  final PaperSize paperSize;
  final Set<PrinterConnectionType> selectedTypes;
  final String? receiptLogoPath;
  final String receiptHeaderTitle;
  final String receiptHeaderSubtitle;

  const PrinterSettingsState({
    this.isScanning = false,
    this.connectingDeviceId,
    this.isDisconnecting = false,
    this.printers = const [],
    required this.paperSize,
    required this.selectedTypes,
    this.receiptLogoPath,
    this.receiptHeaderTitle = 'ZC-POS',
    this.receiptHeaderSubtitle = 'https://github.com/kelvinzer0/ZC-POS',
  });

  PrinterSettingsState copyWith({
    bool? isScanning,
    String? connectingDeviceId,
    bool? isDisconnecting,
    List<PrinterDevice>? printers,
    PaperSize? paperSize,
    Set<PrinterConnectionType>? selectedTypes,
    String? receiptLogoPath,
    bool clearReceiptLogo = false,
    String? receiptHeaderTitle,
    String? receiptHeaderSubtitle,
  }) {
    return PrinterSettingsState(
      isScanning: isScanning ?? this.isScanning,
      connectingDeviceId: connectingDeviceId ?? this.connectingDeviceId,
      isDisconnecting: isDisconnecting ?? this.isDisconnecting,
      printers: printers ?? this.printers,
      paperSize: paperSize ?? this.paperSize,
      selectedTypes: selectedTypes ?? this.selectedTypes,
      receiptLogoPath: clearReceiptLogo ? null : (receiptLogoPath ?? this.receiptLogoPath),
      receiptHeaderTitle: receiptHeaderTitle ?? this.receiptHeaderTitle,
      receiptHeaderSubtitle: receiptHeaderSubtitle ?? this.receiptHeaderSubtitle,
    );
  }
}
