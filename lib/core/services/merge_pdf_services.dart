import 'dart:io';

void main() {
  var pdfServicePath = 'd:/Asansor/lib/core/services/pdf_service.dart';
  var pdfReportServicePath = 'd:/Asansor/lib/core/services/pdf_report_service.dart';
  
  var pdfServiceContent = File(pdfServicePath).readAsStringSync();
  var pdfReportContent = File(pdfReportServicePath).readAsStringSync();
  
  // Extract imports from pdf_report_service
  var elevatorImport = "import '../../features/elevator/models/elevator_model.dart';\n";
  
  // Extract the functions and constants from pdf_report_service
  var reportLogic = pdfReportContent.substring(pdfReportContent.indexOf('// ¦¦ Corporate colour palette'));
  
  // Remove the 'Future<pw.Document> generateElevatorReport(' and replace with 'Future<pw.Document> generateElevatorReport(' inside class? No, let's keep them as methods of PdfService.
  // Actually, keeping them top-level is fine, but the user expects PdfService().generateElevatorReport based on the prompt's Call the updated PdfService().generateMaintenanceReport(...) which implies instance methods. But wait, ElevatorDetailView is currently calling generateElevatorReport(widget.elevator, logs). If we make it PdfService().generateElevatorReport, we need it inside the class.
  // Let's replace top-level function signature with instance method signature. But wait, generateElevatorReport uses pw. and other imports. 
  
  // Let's just put all constants and functions into the class.
  reportLogic = reportLogic.replaceAll('Future<pw.Document> generateElevatorReport', 'Future<pw.Document> generateElevatorReport');
  
  // Just inject reportLogic at the end of the PdfService class, before the last '}'
  var lastBraceIndex = pdfServiceContent.lastIndexOf('}');
  
  var newContent = pdfServiceContent.substring(0, lastBraceIndex) + '\n\n  // --- Migrated from pdf_report_service.dart ---\n\n' + reportLogic.replaceAll('\n', '\n  ') + '\n}\n';
  
  // Add the elevator import
  newContent = newContent.replaceFirst('import \'../../features/maintenance/models/maintenance_log_model.dart\';', 'import \'../../features/maintenance/models/maintenance_log_model.dart\';\n' + elevatorImport);
  
  File(pdfServicePath).writeAsStringSync(newContent);
}
