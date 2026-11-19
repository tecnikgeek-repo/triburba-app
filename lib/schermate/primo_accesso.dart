// Benvenuto al primo accesso: quattro pagine da scorrere (cos'è triburba, la tribù e le garanzie,
// tam-tam/attività/sondaggi, la mappa che si accende) con «Avanti» e «Salta». Si vede una volta sola:
// il sito se lo ricorda per la persona (vale anche sul sito) e il telefono anche in locale.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dati/stato.dart';
import '../tema.dart';

String _chiave(int id) => 'triburba_benvenuto_$id';

/// Apre il benvenuto se questa persona non l'ha ancora visto (né qui né sul sito).
Future<void> proponiBenvenuto(BuildContext context) async {
  final io = stato.io;
  final g = io?.guida;
  if (io == null || g == null || g.benvenuto) return;
  final p = await SharedPreferences.getInstance();
  if (p.getBool(_chiave(io.id)) == true) return;
  if (!context.mounted) return;
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black54,
      pageBuilder: (_, _, _) => const SchermataPrimoAccesso(),
      transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
    ),
  );
}

class SchermataPrimoAccesso extends StatefulWidget {
  const SchermataPrimoAccesso({super.key});

  @override
  State<SchermataPrimoAccesso> createState() => _SchermataPrimoAccessoState();
}

class _SchermataPrimoAccessoState extends State<SchermataPrimoAccesso> {
  final _pagine = PageController();
  final _bio = TextEditingController();
  int _i = 0;

  /// Pagina «Presentati ai vicini» solo per chi non ha ancora la biografia
  bool get _conBio => stato.io?.guida?.bio != true;
  int get _ultima => _conBio ? 4 : 3;

  @override
  void dispose() {
    _pagine.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _chiudi() async {
    final io = stato.io;
    if (io != null) {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_chiave(io.id), true);
    }
    stato.api.guida('benvenuto').catchError((_) => <String, dynamic>{});
    // biografia scritta nell'ultima pagina (vuota = la si ricorda più avanti, con calma)
    final bio = _bio.text.trim();
    if (bio.isNotEmpty) {
      final ctx = context;
      stato.api
          .salvaBio(bio)
          .then((msg) {
            if (ctx.mounted) messaggio(ctx, msg);
            stato.ricarica();
          })
          .catchError((Object e) {
            if (ctx.mounted) messaggio(ctx, 'Biografia non salvata: puoi scriverla dal tuo profilo.');
          });
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _avanti() {
    if (_i == _ultima) {
      _chiudi();
    } else {
      _pagine.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vicini = stato.io?.viciniGaranti ?? 'tre vicini';
    final pagine = [
      (
        Padding(padding: const EdgeInsets.all(14), child: emblema(64)),
        'Benvenuto su triburba',
        'Tribus + urbs: la tribù della città. Il social dei quartieri, nato a Napoli, '
            'dove ogni quartiere ha la sua voce e insieme fanno una città.',
        false,
      ),
      (
        const Icon(Icons.handshake_outlined, size: 46, color: bianco),
        'La tua tribù',
        'Il quartiere o comune che hai scelto all\'iscrizione è la tua tribù. Per scrivere servono le garanzie di $vicini già confermati che ti conoscono: '
            'così qui ci sono persone vere. Intanto puoi leggere, reagire e commentare.',
        true,
      ),
      (
        const Icon(Icons.campaign_outlined, size: 46, color: bianco),
        'Tam-tam, attività e sondaggi',
        'Col Tam-tam una notizia sale dal quartiere alla città quando la rilanciano i residenti. '
            'Proponi un\'attività e chiedi chi ti dà una mano, o fai un sondaggio ai vicini.',
        true,
      ),
      (
        const Icon(Icons.map_outlined, size: 46, color: bianco),
        'La mappa che si accende',
        'Quartieri e comuni restano nella nebbia finché non li chiede abbastanza gente. '
            'Il tuo non è ancora acceso? La tua iscrizione conta già come richiesta: passa parola e, quando si accende, ci entri da solo.',
        true,
      ),
      if (_conBio)
        (
          const Icon(Icons.person_outline, size: 46, color: bianco),
          'Presentati ai vicini',
          'Due righe su di te, che i vicini leggono sul tuo profilo. Se preferisci, puoi scriverle anche dopo.',
          true,
        ),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (fatto, _) {
        if (!fatto) _chiudi();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 520),
            decoration: BoxDecoration(
              color: superficie,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: linea2)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                      child: TextButton(
                        onPressed: _chiudi,
                        style: TextButton.styleFrom(
                          foregroundColor: muto,
                          textStyle: const TextStyle(fontFamily: fontTesto, fontWeight: FontWeight.w600, fontSize: 14.5),
                        ),
                        child: const Text('Salta'),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: _conBio && _i == 4 ? 400 : 330,
                    child: PageView(
                      controller: _pagine,
                      onPageChanged: (i) => setState(() => _i = i),
                      children: [
                        for (final p in pagine)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 26),
                            child: Column(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    gradient: p.$4 ? gradiente : null,
                                    color: p.$4 ? null : superficie2,
                                    boxShadow: p.$4
                                        ? [BoxShadow(color: terracotta.withValues(alpha: .45), blurRadius: 30, offset: const Offset(0, 14))]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: p.$1,
                                ),
                                const SizedBox(height: 22),
                                Text(p.$2, textAlign: TextAlign.center, style: titolo(24)),
                                const SizedBox(height: 12),
                                Text(
                                  p.$3,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: testo2, fontSize: 15, height: 1.5),
                                ),
                                if (p.$2 == 'Presentati ai vicini') ...[
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _bio,
                                    minLines: 2,
                                    maxLines: 3,
                                    maxLength: 240,
                                    textCapitalization: TextCapitalization.sentences,
                                    decoration: const InputDecoration(
                                      hintText: 'Es. Abito qui da dieci anni, faccio l\'infermiera e la domenica corro sul lungomare.',
                                      counterText: '',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
                    child: Row(
                      children: [
                        for (var k = 0; k <= _ultima; k++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(right: 7),
                            width: k == _i ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: k == _i ? null : linea2,
                              gradient: k == _i ? gradiente : null,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BottoneCaldo(
                            testo: _i == _ultima ? 'Inizia' : 'Avanti',
                            icona: _i == _ultima ? Icons.check_rounded : Icons.arrow_forward_rounded,
                            onPressed: _avanti,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
