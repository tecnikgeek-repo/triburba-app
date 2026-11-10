// Fascia in cima alla Home finché l'email non è confermata: «Conferma la tua email» con Rimanda e Cambia email.
// Come la fascia del sito: si entra e si legge, per scrivere e commentare serve il link della mail.
import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/stato.dart';
import '../schermate/profilo.dart';
import '../tema.dart';

/// Email con il nome accorciato: «te••••••@gmail.com», come sul sito.
String emailMascherata(String email) {
  final at = email.indexOf('@');
  if (at < 0) return email;
  final nome = email.substring(0, at);
  final resto = email.substring(at);
  if (nome.length <= 2) return email;
  final punti = nome.length - 2 > 6 ? 6 : nome.length - 2;
  return '${nome.substring(0, 2)}${'•' * punti}$resto';
}

class FasciaEmail extends StatefulWidget {
  const FasciaEmail({super.key});

  @override
  State<FasciaEmail> createState() => _FasciaEmailState();
}

class _FasciaEmailState extends State<FasciaEmail> {
  bool _invio = false;
  String? _esito;

  Future<void> _rimanda() async {
    setState(() => _invio = true);
    try {
      final msg = await stato.api.rimandaEmail();
      if (mounted) setState(() => _esito = msg);
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _esito = e.messaggio);
    } finally {
      if (mounted) setState(() => _invio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final io = stato.io;
    if (io == null || io.emailConfermata) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(colors: [terracotta.withValues(alpha: .20), oro.withValues(alpha: .12)]),
        border: Border.all(color: terracotta.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(gradient: gradienteBottone, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.mail_outline_rounded, color: bianco, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Conferma la tua email', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    const SizedBox(height: 3),
                    Text(
                      'Ti abbiamo scritto a ${emailMascherata(io.email)}: apri la mail e tocca «Conferma la mia email». '
                      'Fino ad allora puoi leggere, ma non scrivere né commentare.',
                      style: const TextStyle(color: testo2, fontSize: 13.5, height: 1.4),
                    ),
                    if (_esito != null) ...[
                      const SizedBox(height: 6),
                      Text(_esito!, style: const TextStyle(color: oro, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: BottoneCaldo(testo: 'Rimanda', occupato: _invio, onPressed: _rimanda)),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SchermataImpostazioni())),
                  child: const Text('Cambia email'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dopo l'iscrizione: «Ti abbiamo scritto», prima di entrare nella Home.
Future<void> avvisoMailMandata(BuildContext context, String email) => showDialog<void>(
  context: context,
  builder: (c) => AlertDialog(
    icon: const Icon(Icons.mark_email_unread_outlined, color: terracotta, size: 40),
    title: const Text('Ti abbiamo scritto'),
    content: Text(
      'Abbiamo mandato una mail a ${emailMascherata(email)}.\n\nAprila e tocca «Conferma la mia email»: '
      'così potrai scrivere, commentare e farti garantire dai vicini. Non la trovi? Guarda nello spam.',
      style: const TextStyle(height: 1.45),
    ),
    actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Ho capito'))],
  ),
);

/// «Password dimenticata?»: chiede l'email e manda il link per una nuova password.
Future<void> passwordDimenticata(BuildContext context, {String email = ''}) async {
  final campo = TextEditingController(text: email.contains('@') ? email : '');
  final esito = await showDialog<String>(
    context: context,
    builder: (c) {
      var invio = false;
      String? errore;
      return StatefulBuilder(
        builder: (c, aggiorna) => AlertDialog(
          title: const Text('Password dimenticata?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Scrivi l\'email con cui ti sei iscritto: ti mandiamo un link per sceglierne una nuova.', style: TextStyle(height: 1.4)),
              const SizedBox(height: 14),
              TextField(
                controller: campo,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: 'Email', errorText: errore, prefixIcon: const Icon(Icons.mail_outline)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
            FilledButton(
              onPressed: invio
                  ? null
                  : () async {
                      aggiorna(() => invio = true);
                      try {
                        final msg = await stato.api.passwordDimenticata(campo.text.trim());
                        if (c.mounted) Navigator.pop(c, msg);
                      } on ErroreApi catch (e) {
                        aggiorna(() {
                          invio = false;
                          errore = e.messaggio;
                        });
                      }
                    },
              child: const Text('Mandami il link'),
            ),
          ],
        ),
      );
    },
  );
  if (esito != null && context.mounted) messaggio(context, esito);
}
