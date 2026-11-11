// Data di nascita: campo che apre il calendario (almeno 14 anni, come sul sito). Valore «AAAA-MM-GG».
import 'package:flutter/material.dart';

import '../tema.dart';

const etaMinima = 14;

String? dataIso(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? daIso(String? s) => (s == null || s.isEmpty) ? null : DateTime.tryParse(s);

class CampoNascita extends StatelessWidget {
  const CampoNascita({super.key, required this.valore, required this.onCambia, this.aiuto});

  final DateTime? valore;
  final ValueChanged<DateTime> onCambia;
  final String? aiuto;

  Future<void> _apri(BuildContext context) async {
    final oggi = DateTime.now();
    final ultimo = DateTime(oggi.year - etaMinima, oggi.month, oggi.day);
    final d = await showDatePicker(
      context: context,
      locale: const Locale('it'),
      initialDatePickerMode: DatePickerMode.year,
      initialDate: valore ?? DateTime(oggi.year - 30, oggi.month, oggi.day),
      firstDate: DateTime(oggi.year - 110),
      lastDate: ultimo,
      helpText: 'La tua data di nascita',
      cancelText: 'Annulla',
      confirmText: 'Fatto',
    );
    if (d != null) onCambia(d);
  }

  @override
  Widget build(BuildContext context) {
    final v = valore;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _apri(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Data di nascita',
          helperText: aiuto,
          prefixIcon: const Icon(Icons.cake_outlined),
          suffixIcon: const Icon(Icons.calendar_month_outlined),
        ),
        isEmpty: v == null,
        child: Text(
          v == null ? '' : '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}',
          style: const TextStyle(color: testo, fontSize: 16),
        ),
      ),
    );
  }
}
