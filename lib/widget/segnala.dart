// Scelta del motivo per segnalare un commento o una persona (requisito App Store 1.2: si segnala ogni contenuto).
import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/stato.dart';
import '../tema.dart';

/// Mostra i motivi e restituisce quello scelto (null = annullato)
Future<String?> scegliMotivo(BuildContext context, {required String intestazione, required String spiega, required List<String> motivi}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(intestazione, style: titolo(20)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(spiega, style: const TextStyle(color: muto, fontSize: 13)),
              ),
              for (final x in motivi) ListTile(title: Text(x), onTap: () => Navigator.pop(c, x)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

/// Segnala una persona: chiede il motivo e manda la segnalazione allo staff
Future<void> segnalaPersona(BuildContext context, String username) async {
  List<String> motivi;
  try {
    motivi = ((await stato.api.motiviSegnalazione())['persona'] as List).map((e) => '$e').toList();
  } on ErroreApi catch (e) {
    if (context.mounted) messaggio(context, e.messaggio);
    return;
  }
  if (!context.mounted) return;
  final m = await scegliMotivo(
    context,
    intestazione: 'Perché segnali @$username?',
    spiega: 'La segnalazione è anonima: arriva solo allo staff di triburba, che la controlla entro 24 ore.',
    motivi: motivi,
  );
  if (m == null || !context.mounted) return;
  try {
    final msg = await stato.api.segnalaPersona(username, m);
    if (context.mounted) messaggio(context, msg);
  } on ErroreApi catch (e) {
    if (context.mounted) messaggio(context, e.messaggio);
  }
}
