import 'dart:async';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

import '../../../domain/entities/transaction_entity.dart';
import '../../common/result.dart';
import '../../constants/constants.dart';
import '../../utilities/console_logger.dart';
import '../../utilities/currency_formatter.dart';
import '../../utilities/date_time_formatter.dart';

class PrinterService {
  final PrinterManager _manager = PrinterManager();
  final SharedPreferences _sharedPreferences;

  PrinterService(this._sharedPreferences);

  List<PrinterDevice> printers = [];
  PrinterDevice? selectedPrinter;

  PrinterConnectionState get connectionState => _manager.state;
  Stream<PrinterConnectionState> get stateStream => _manager.stateStream;
  bool get isConnected => _manager.isConnected;

  PaperSize get paperSize {
    final saved = _sharedPreferences.getString(Constants.selectedPaperSizeKey);
    return switch (saved) {
      'mm72' => PaperSize.mm72,
      'mm80' => PaperSize.mm80,
      _ => PaperSize.mm58,
    };
  }

  void setPaperSize(PaperSize size) {
    final key = switch (size) {
      PaperSize.mm58 => 'mm58',
      PaperSize.mm72 => 'mm72',
      PaperSize.mm80 => 'mm80',
    };
    _sharedPreferences.setString(Constants.selectedPaperSizeKey, key);
  }

  String? get receiptLogoPath => _sharedPreferences.getString(Constants.receiptLogoPathKey);

  Future<void> setReceiptLogoPath(String? path) async {
    if (path == null) {
      await _sharedPreferences.remove(Constants.receiptLogoPathKey);
    } else {
      await _sharedPreferences.setString(Constants.receiptLogoPathKey, path);
    }
  }

  String get receiptHeaderTitle =>
      _sharedPreferences.getString(Constants.receiptHeaderTitleKey) ?? 'ZC-POS';

  Future<void> setReceiptHeaderTitle(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _sharedPreferences.remove(Constants.receiptHeaderTitleKey);
    } else {
      await _sharedPreferences.setString(Constants.receiptHeaderTitleKey, value.trim());
    }
  }

  String get receiptHeaderSubtitle =>
      _sharedPreferences.getString(Constants.receiptHeaderSubtitleKey) ??
      'https://github.com/kelvinzer0/ZC-POS';

  Future<void> setReceiptHeaderSubtitle(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _sharedPreferences.remove(Constants.receiptHeaderSubtitleKey);
    } else {
      await _sharedPreferences.setString(Constants.receiptHeaderSubtitleKey, value.trim());
    }
  }

  bool get hideReceiptHeaderTitle =>
      _sharedPreferences.getBool(Constants.hideReceiptHeaderTitleKey) ?? false;

  Future<void> setHideReceiptHeaderTitle(bool value) async {
    await _sharedPreferences.setBool(Constants.hideReceiptHeaderTitleKey, value);
  }

  bool get hideReceiptHeaderSubtitle =>
      _sharedPreferences.getBool(Constants.hideReceiptHeaderSubtitleKey) ?? false;

  Future<void> setHideReceiptHeaderSubtitle(bool value) async {
    await _sharedPreferences.setBool(Constants.hideReceiptHeaderSubtitleKey, value);
  }

  static const String defaultReviewMessage = 'Loved the food? Leave us a 5-star review via QR code.';

  String get receiptReviewMessage =>
      _sharedPreferences.getString(Constants.receiptReviewMessageKey) ?? defaultReviewMessage;

  Future<void> setReceiptReviewMessage(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _sharedPreferences.remove(Constants.receiptReviewMessageKey);
    } else {
      await _sharedPreferences.setString(Constants.receiptReviewMessageKey, value.trim());
    }
  }

  bool get hideReceiptReviewMessage =>
      _sharedPreferences.getBool(Constants.hideReceiptReviewMessageKey) ?? false;

  Future<void> setHideReceiptReviewMessage(bool value) async {
    await _sharedPreferences.setBool(Constants.hideReceiptReviewMessageKey, value);
  }

  Future<Result<void>> scanPrinters({
    Set<PrinterConnectionType> types = const {
      PrinterConnectionType.usb,
      PrinterConnectionType.bluetooth,
      PrinterConnectionType.ble,
      PrinterConnectionType.network,
    },
    String? selectedDeviceId,
    Function(List<PrinterDevice>)? onDeviceStream,
  }) async {
    final permissions = await checkPermissions();
    if (permissions.isFailure) return Result.failure(error: permissions.error!);

    try {
      printers = [];
      final stream = _manager.scanAll(
        timeout: const Duration(seconds: 5),
        types: types,
      );

      await for (final devices in stream) {
        for (final device in devices) {
          if (!printers.any((p) => getDeviceId(p) == getDeviceId(device))) {
            printers.add(device);
          }
        }

        onDeviceStream?.call(printers);

        if (selectedDeviceId != null && !(_manager.state == PrinterConnectionState.scanning)) {
          final match = printers.where((d) => getDeviceId(d) == selectedDeviceId).firstOrNull;
          if (match != null && selectedPrinter == null) {
            final result = await selectPrinter(match);
            if (result.isFailure) {
              return Result.failure(error: result.error!);
            }
          } else if (match != null) {
            // Update reference to the new scan instance without reconnecting
            selectedPrinter = match;
          }
        }
      }

      return Result.success(data: null);
    } catch (e) {
      return Result.failure(error: e.toString());
    }
  }

  Future<Result<void>> selectPrinter(PrinterDevice device) async {
    cl('[PrinterService].selectPrinter: ${device.name} (${device.connectionType.name})');

    try {
      final currentSelectedDeviceId = selectedPrinter == null ? null : getDeviceId(selectedPrinter!);
      final nextSelectedDeviceId = getDeviceId(device);

      if (_manager.isConnected && currentSelectedDeviceId == nextSelectedDeviceId) {
        selectedPrinter = device;
        return Result.success(data: null);
      }

      if (_manager.isConnected) {
        await _manager.disconnect();
      }

      await _manager.connect(device, timeout: const Duration(seconds: 10));
      selectedPrinter = device;
      return Result.success(data: null);
    } on PrinterException catch (e) {
      if (!_manager.isConnected) {
        selectedPrinter = null;
      }

      cl('[PrinterService].selectPrinter connection error: ${e.message}');
      return Result.failure(error: e.message);
    } catch (e) {
      if (!_manager.isConnected) {
        selectedPrinter = null;
      }

      cl('[PrinterService].selectPrinter connection error: $e');
      return Result.failure(error: e.toString());
    }
  }

  Future<Result<void>> disconnectPrinter() async {
    try {
      if (_manager.isConnected) {
        await _manager.disconnect();
      }

      selectedPrinter = null;
      return Result.success(data: null);
    } on PrinterException catch (e) {
      cl('[PrinterService].disconnectPrinter error: ${e.message}');
      return Result.failure(error: e.message);
    } catch (e) {
      cl('[PrinterService].disconnectPrinter error: $e');
      return Result.failure(error: e.toString());
    }
  }

  Future<Result<void>> printTicket(Ticket ticket) async {
    if (selectedPrinter == null) {
      return Result.failure(error: 'Printer is not selected yet!');
    }

    try {
      if (!_manager.isConnected) {
        await _manager.connect(selectedPrinter!, timeout: const Duration(seconds: 10));
      }

      await _manager.printTicket(ticket);
      return Result.success(data: null);
    } on PrinterException catch (e) {
      return Result.failure(error: e.message);
    } catch (e) {
      return Result.failure(error: e.toString());
    }
  }

  Future<Result<void>> printData(List<int> bytes) async {
    if (selectedPrinter == null) {
      return Result.failure(error: 'Printer is not selected yet!');
    }

    try {
      if (!_manager.isConnected) {
        await _manager.connect(selectedPrinter!, timeout: const Duration(seconds: 10));
      }

      await _manager.printBytes(bytes);
      return Result.success(data: null);
    } on PrinterException catch (e) {
      return Result.failure(error: e.message);
    } catch (e) {
      return Result.failure(error: e.toString());
    }
  }

  Future<Result<void>> printTransaction(TransactionEntity transaction) async {
    try {
      final ticket = await Ticket.create(paperSize);

      // Print custom receipt logo if configured
      final logoPath = receiptLogoPath;
      if (logoPath != null && logoPath.isNotEmpty) {
        final logoFile = File(logoPath);
        if (logoFile.existsSync()) {
          try {
            final bytes = logoFile.readAsBytesSync();
            var decoded = img.decodeImage(bytes);
            if (decoded != null) {
              if (decoded.width > 384) {
                decoded = img.copyResize(decoded, width: 384);
              }
              ticket.imageRaster(decoded, align: PrintAlign.center);
              ticket.emptyLines(1);
            }
          } catch (e) {
            cl('Failed to print receipt logo: $e');
          }
        }
      }

      if (!hideReceiptHeaderTitle && receiptHeaderTitle.trim().isNotEmpty) {
        ticket.text(
          receiptHeaderTitle.trim(),
          align: PrintAlign.center,
          style: const PrintTextStyle(
            bold: true,
            height: TextSize.size2,
            width: TextSize.size2,
          ),
        );
      }
      if (!hideReceiptHeaderSubtitle && receiptHeaderSubtitle.trim().isNotEmpty) {
        ticket.text(
          receiptHeaderSubtitle.trim(),
          align: PrintAlign.center,
          style: const PrintTextStyle(
            fontType: FontType.fontB,
          ),
        );
      }

      if ((!hideReceiptHeaderTitle && receiptHeaderTitle.trim().isNotEmpty) ||
          (!hideReceiptHeaderSubtitle && receiptHeaderSubtitle.trim().isNotEmpty)) {
        ticket.emptyLines();
      }

      final date = DateTimeFormatter.slashDateShortedYearWithClock(
        transaction.createdAt ?? DateTime.now().toIso8601String(),
      );

      ticket.text('Date: $date');
      ticket.text('Trx. ID: #${transaction.id}');
      ticket.text('Channel: ${transaction.channel.toUpperCase()}');
      ticket.text('Customer: ${transaction.customerName ?? '-'}');
      ticket.text('Created by: ${transaction.createdBy?.name ?? '-'}');

      ticket.separator();

      if (transaction.orderedProducts != null) {
        for (final product in transaction.orderedProducts!) {
          ticket.text(product.name);
          ticket.row([
            PrintColumn(
              text: '  ${product.quantity} x ${CurrencyFormatter.withoutSymbol(product.price).trim()}',
              flex: 3,
            ),
            PrintColumn(
              text: CurrencyFormatter.withoutSymbol(product.price * product.quantity).trim(),
              flex: 2,
              align: PrintAlign.right,
            ),
          ]);
          if (product.notes != null && product.notes!.trim().isNotEmpty) {
            ticket.text('  Catatan: ${product.notes!.trim()}');
          }
        }
      }

      ticket.separator();

      if (transaction.shippingFee > 0) {
        ticket.row([
          PrintColumn(
            text: 'Ongkir',
            flex: 2,
          ),
          PrintColumn(
            text: CurrencyFormatter.format(transaction.shippingFee),
            flex: 1,
            align: PrintAlign.right,
          ),
        ]);
      }

      ticket.row([
        PrintColumn(
          text: 'Total',
          flex: 2,
          style: const PrintTextStyle(bold: true),
        ),
        PrintColumn(
          text: CurrencyFormatter.format(transaction.totalAmount),
          flex: 1,
          align: PrintAlign.right,
          style: const PrintTextStyle(bold: true),
        ),
      ]);
      ticket.row([
        PrintColumn(
          text: 'Pay (${transaction.paymentMethod})',
          flex: 2,
        ),
        PrintColumn(
          text: CurrencyFormatter.format(transaction.receivedAmount),
          flex: 1,
          align: PrintAlign.right,
        ),
      ]);
      ticket.row([
        PrintColumn(
          text: 'Change',
          flex: 2,
        ),
        PrintColumn(
          text: CurrencyFormatter.format(transaction.returnAmount),
          flex: 1,
          align: PrintAlign.right,
        ),
      ]);

      if (transaction.description != null && transaction.description!.trim().isNotEmpty) {
        ticket.separator();
        ticket.text('Note: ${transaction.description!.trim()}');
      }

      ticket.emptyLines();
      ticket.qrcode(
        'https://search.google.com/local/writereview/mobile?placeid=ChIJsT8cF-S9eC4RnrekN3z63eI',
        size: QRSize.size3,
      );
      ticket.emptyLines();
      ticket.text('Thank you for your order!', align: PrintAlign.center);
      if (!hideReceiptReviewMessage && receiptReviewMessage.trim().isNotEmpty) {
        ticket.text(
          receiptReviewMessage.trim(),
          align: PrintAlign.center,
        );
      }
      ticket.cut(linesBefore: 2);

      return await printTicket(ticket);
    } catch (e) {
      return Result.failure(error: e.toString());
    }
  }

  Future<Result<void>> printCustomerReceipt(TransactionEntity transaction) async {
    return printTransaction(transaction);
  }

  Future<Result<void>> printKitchenTicket(TransactionEntity transaction) async {
    try {
      final ticket = await Ticket.create(paperSize);

      ticket.separator(char: '=');
      ticket.text(
        'KITCHEN TICKET',
        align: PrintAlign.center,
        style: const PrintTextStyle(
          bold: true,
          height: TextSize.size2,
          width: TextSize.size1,
        ),
      );
      ticket.separator(char: '=');
      ticket.emptyLines();

      final date = DateTimeFormatter.slashDateShortedYearWithClock(
        transaction.createdAt ?? DateTime.now().toIso8601String(),
      );

      ticket.text('Trx. ID: #${transaction.id}', style: const PrintTextStyle(bold: true));
      ticket.text('Date: $date');
      ticket.text('Channel: ${transaction.channel.toUpperCase()}');
      if (transaction.customerName != null &&
          transaction.customerName!.trim().isNotEmpty &&
          transaction.customerName != '-') {
        ticket.text('Customer: ${transaction.customerName!.trim()}');
      }

      ticket.separator();

      if (transaction.orderedProducts != null) {
        for (final product in transaction.orderedProducts!) {
          ticket.row([
            PrintColumn(
              text: product.name,
              flex: 3,
              style: const PrintTextStyle(bold: true),
            ),
            PrintColumn(
              text: 'x${product.quantity}',
              flex: 1,
              align: PrintAlign.right,
              style: const PrintTextStyle(bold: true),
            ),
          ]);
          if (product.notes != null && product.notes!.trim().isNotEmpty) {
            ticket.text('  Catatan: ${product.notes!.trim()}', style: const PrintTextStyle(bold: true));
          }
        }
      }

      ticket.separator();

      if (transaction.description != null && transaction.description!.trim().isNotEmpty) {
        ticket.text('Catatan Pesanan:', style: const PrintTextStyle(bold: true));
        ticket.text(transaction.description!.trim());
        ticket.emptyLines();
      }

      ticket.cut(linesBefore: 2);

      return await printTicket(ticket);
    } catch (e) {
      return Result.failure(error: e.toString());
    }
  }

  Future<Result<void>> printSalesReport({
    required String periodTitle,
    required int totalSales,
    required int totalTransactions,
    required int totalItemsSold,
    required Map<String, int> paymentBreakdown,
    required Map<String, int> channelBreakdown,
    required List<MapEntry<String, int>> topProducts,
  }) async {
    try {
      final ticket = await Ticket.create(paperSize);

      ticket.separator(char: '=');
      ticket.text(
        'LAPORAN PENJUALAN',
        align: PrintAlign.center,
        style: const PrintTextStyle(
          bold: true,
          height: TextSize.size2,
          width: TextSize.size1,
        ),
      );
      ticket.separator(char: '=');
      ticket.emptyLines();

      final now = DateTimeFormatter.slashDateShortedYearWithClock(
        DateTime.now().toIso8601String(),
      );

      ticket.text('Periode: $periodTitle');
      ticket.text('Waktu Cetak: $now');
      ticket.separator();

      ticket.text('RINGKASAN', style: const PrintTextStyle(bold: true));
      ticket.text('Total Transaksi : $totalTransactions');
      ticket.text('Produk Terjual  : $totalItemsSold pcs');
      ticket.text('TOTAL OMZET     : ${CurrencyFormatter.format(totalSales)}', style: const PrintTextStyle(bold: true));
      ticket.separator();

      if (paymentBreakdown.isNotEmpty) {
        ticket.text('METODE PEMBAYARAN', style: const PrintTextStyle(bold: true));
        paymentBreakdown.forEach((method, amount) {
          ticket.text('${method.toUpperCase()} : ${CurrencyFormatter.format(amount)}');
        });
        ticket.separator();
      }

      if (channelBreakdown.isNotEmpty) {
        ticket.text('SALURAN PENJUALAN', style: const PrintTextStyle(bold: true));
        channelBreakdown.forEach((channel, amount) {
          ticket.text('${channel.toUpperCase()} : ${CurrencyFormatter.format(amount)}');
        });
        ticket.separator();
      }

      if (topProducts.isNotEmpty) {
        ticket.text('PRODUK TERLARIS', style: const PrintTextStyle(bold: true));
        for (int i = 0; i < topProducts.length && i < 5; i++) {
          final entry = topProducts[i];
          ticket.text('${i + 1}. ${entry.key} (${entry.value} pcs)');
        }
        ticket.separator();
      }

      ticket.cut(linesBefore: 2);

      return await printTicket(ticket);
    } catch (e) {
      return Result.failure(error: e.toString());
    }
  }

  Future<Result<void>> testPrint() async {
    try {
      final ticket = await Ticket.create(paperSize);

      ticket.row([
        PrintColumn(
          text: 'top left',
          flex: 1,
        ),
        PrintColumn(
          text: 'top right',
          flex: 1,
          align: PrintAlign.right,
        ),
      ]);

      ticket.emptyLines(1);

      final logoPath = receiptLogoPath;
      if (logoPath != null && logoPath.isNotEmpty) {
        final logoFile = File(logoPath);
        if (logoFile.existsSync()) {
          try {
            final bytes = logoFile.readAsBytesSync();
            var decoded = img.decodeImage(bytes);
            if (decoded != null) {
              if (decoded.width > 384) {
                decoded = img.copyResize(decoded, width: 384);
              }
              ticket.imageRaster(decoded, align: PrintAlign.center);
              ticket.emptyLines(1);
            }
          } catch (e) {
            cl('Failed to test print receipt logo: $e');
          }
        }
      }

      ticket.text(
        'ZC-POS PRINT TEST OK',
        align: PrintAlign.center,
        style: const PrintTextStyle(bold: true),
      );
      await ticket.textRaster(
        'ありがとうございます',
        align: PrintAlign.center,
      );

      ticket.emptyLines(3);

      ticket.row([
        PrintColumn(
          text: 'bottom left',
          flex: 1,
        ),
        PrintColumn(
          text: 'bottom right',
          flex: 1,
          align: PrintAlign.right,
        ),
      ]);

      ticket.feed(4);
      ticket.cut();

      return await printTicket(ticket);
    } catch (e) {
      return Result.failure(error: e.toString());
    }
  }

  Future<Result<void>> checkPermissions() async {
    final isBluetoothScanGranted = await Permission.bluetoothScan.request();
    if (isBluetoothScanGranted.isDenied) {
      return Result.failure(error: 'Bluetooth scan permission is not granted!');
    }

    final isBluetoothConnectGranted = await Permission.bluetoothConnect.request();
    if (isBluetoothConnectGranted.isDenied) {
      return Result.failure(error: 'Bluetooth connect permission is not granted!');
    }

    return Result.success(data: null);
  }

  String getDeviceId(PrinterDevice device) {
    return switch (device) {
      NetworkPrinterDevice d => '${d.host}:${d.port}',
      BlePrinterDevice d => d.deviceId,
      BluetoothPrinterDevice d => d.address,
      UsbPrinterDevice d => d.identifier,
      _ => device.name,
    };
  }

  Future<void> dispose() async {
    await _manager.dispose();
  }
}
