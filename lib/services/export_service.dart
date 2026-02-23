import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/project_lead.dart';

class ExportService {
  /// Export all leads to a CSV file and share/save it.
  static Future<String?> exportToCsv(List<ProjectLead> leads) async {
    if (leads.isEmpty) return null;

    // Build CSV rows
    final rows = <List<String>>[
      ProjectLead.csvHeaders(),
      ...leads.map((l) => l.toCsvRow()),
    ];

    final csvData = const ListToCsvConverter().convert(rows);

    // Write to temp file
    final dir = await getTemporaryDirectory();
    final filename =
        'project_leads_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(csvData, flush: true);

    return file.path;
  }

  /// Export and share via system share sheet.
  static Future<void> exportAndShare(List<ProjectLead> leads) async {
    final path = await exportToCsv(leads);
    if (path == null) return;

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'text/csv')],
        subject: 'Project Leads Export',
        text: 'Exported ${leads.length} project leads from Lead Tracker.',
      ),
    );
  }

  /// Save CSV to Downloads folder (Android).
  static Future<String?> exportToDownloads(List<ProjectLead> leads) async {
    if (leads.isEmpty) return null;

    final rows = <List<String>>[
      ProjectLead.csvHeaders(),
      ...leads.map((l) => l.toCsvRow()),
    ];

    final csvData = const ListToCsvConverter().convert(rows);
    final filename =
        'project_leads_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        dir = await getExternalStorageDirectory();
      }
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    if (dir == null) return null;

    final file = File('${dir.path}/$filename');
    await file.writeAsString(csvData, flush: true);
    return file.path;
  }
}
