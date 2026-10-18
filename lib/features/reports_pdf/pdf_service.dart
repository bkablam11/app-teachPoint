// lib/features/reports_pdf/pdf_service.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../core/database/models.dart';

class PdfService {
  static Future<Uint8List> generateVacationReport({
    required TeacherProfile teacher,
    required List<AttendanceRecord> records,
    required Map<String, ClassEntity> classesMap,
    required int mois,
    required int annee,
  }) async {
    final pdf = pw.Document();
    final currencyFormatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    final dateFormatter = DateFormat('dd/MM/yyyy');

    final totalHeures = records.fold<double>(0.0, (acc, r) => acc + r.heuresValidees);
    final totalBrut = records.fold<double>(0.0, (acc, r) => acc + r.montantTotal);
    final totalTaxe = records.fold<double>(0.0, (acc, r) => acc + r.montantTaxe);
    final totalNet = totalBrut - totalTaxe;

    final moisNom = DateFormat.MMMM('fr_FR').format(DateTime(annee, mois));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // EN-TÊTE ADMINISTRATIF OFFICIEL
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        teacher.etablissement.toUpperCase(),
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                      pw.Text("DIRECTION DES AFFAIRES ACADÉMIQUES", style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(
                        "BORDEREAU RÉCAPITULATIF DES VACATIONS",
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("ANNÉE : 2026-2027", style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(
                        "PÉRIODE : ${moisNom.toUpperCase()} $annee",
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  )
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.blueGrey800),
              pw.SizedBox(height: 8),

              // RÉCAPITULATIF ENSEIGNANT
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Enseignant : ${teacher.nom.toUpperCase()} ${teacher.prenoms}",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text("Contact : ${teacher.contact}", style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Régime : Enseignant Vacataire", style: const pw.TextStyle(fontSize: 9)),
                        pw.Text("Retenue Fiscale : ${teacher.tauxTaxePourcent} %",
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // TABLEAU GÉNÉRAL TOUTES CLASSES CONFONDUES
              pw.Text(
                "DÉTAIL MENSUEL DES PRESTATIONS PÉDAGOGIQUES (TOUTES CLASSES)",
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
              ),
              pw.SizedBox(height: 5),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.8), // Date
                  1: const pw.FlexColumnWidth(2.2), // Classe
                  2: const pw.FlexColumnWidth(4.2), // Thème / Matière
                  3: const pw.FlexColumnWidth(1.8), // Horaires
                  4: const pw.FlexColumnWidth(1.2), // Vol
                  5: const pw.FlexColumnWidth(2.2), // Montant Brut
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _th("DATE"),
                      _th("CLASSE"),
                      _th("DISCIPLINE & LEÇON"),
                      _th("CRÉNEAU"),
                      _th("VOL"),
                      _th("BRUT"),
                    ],
                  ),
                  ...records.map(
                    (r) {
                      final c = classesMap[r.classId];
                      final classeName = c?.nomClasse ?? "Classe";
                      return pw.TableRow(
                        children: [
                          _td(r.dateCours),
                          _td(classeName),
                          _td(r.remarque ?? c?.matiere ?? "Séance de cours"),
                          _td("${r.heureArrivee} - ${r.heureDepart}"),
                          _td("${r.heuresValidees} h", align: pw.TextAlign.center),
                          _td(currencyFormatter.format(r.montantTotal), align: pw.TextAlign.right),
                        ],
                      );
                    },
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // TOTALISATEUR CONSOLIDÉ (BRUT / TAXE / NET)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.blueGrey800),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text("Total Heures Exécutées :", style: const pw.TextStyle(fontSize: 9)),
                            pw.Text("$totalHeures H",
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text("TOTAL BRUT :", style: const pw.TextStyle(fontSize: 9)),
                            pw.Text(currencyFormatter.format(totalBrut),
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text("Retenue Fiscale (${teacher.tauxTaxePourcent}%) :",
                                style: const pw.TextStyle(fontSize: 9, color: PdfColors.red900)),
                            pw.Text("- ${currencyFormatter.format(totalTaxe)}",
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.red900)),
                          ],
                        ),
                        pw.Divider(thickness: 0.5),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text("NET À PAYER :",
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue900)),
                            pw.Text(
                              currencyFormatter.format(totalNet),
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.green900),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // VISAS ACADÉMIQUES
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text("L'Enseignant Vacataire",
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 40),
                      pw.Text("${teacher.nom.toUpperCase()} ${teacher.prenoms}",
                          style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text("Le Chef de Département",
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 40),
                      pw.Text("Visa & Cachet",
                          style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text("La Direction Générale",
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 40),
                      pw.Text("Pour Visa et Paiement",
                          style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  "Édité automatiquement via TeachPoint • Le ${dateFormatter.format(DateTime.now())}",
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
              )
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _th(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 7.5),
        textAlign: align,
      ),
    );
  }
}