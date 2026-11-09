// triburba per Android e iPhone — il social dei quartieri (triburba.it)
// Ogni quartiere una voce, insieme una città: feed delle tribù, mappa, tam-tam, residenza garantita dai vicini,
// notifiche push.
// Copyright (C) 2026 Pietro De Filippis (TecnikGeek) — AGPL-3.0-or-later, vedi COPYING
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'dati/api.dart';
import 'dati/push.dart';
import 'dati/stato.dart';
import 'schermate/accesso.dart';
import 'schermate/home.dart';
import 'schermate/naviga.dart';
import 'tema.dart';
import 'tk_licenza.dart';
import 'tk_pro.dart' show ProTk, proTk;

Future<void> _inizializza() async {
  var versione = '';
  try {
    final info = await PackageInfo.fromPlatform();
    versione = info.version;
    final lic = Licenza(slug: 'triburba', versione: versione);
    await lic.carica();
    proTk = ProTk(lic);
    lic.avvia();
  } catch (_) {
    proTk = null;
  }
  stato = Stato(Api(versione: versione));
  await stato.api.caricaToken();
  await preparaPush();
  if (stato.api.token != null) {
    try {
      stato.entra(await stato.api.io());
      collegaPush();
    } on ErroreApi catch (e) {
      // senza rete si entra lo stesso: le schermate riprovano da sole
      if (!e.accessoScaduto) stato.io = null;
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configTk = configTriburba;
  registraLicenzaAgpl();
  PlatformDispatcher.instance.onError = (e, s) {
    debugPrint('errore non gestito: $e');
    return true;
  };
  runApp(AppTriburba(avvio: _inizializza()));
}

class AppTriburba extends StatelessWidget {
  const AppTriburba({super.key, required this.avvio});

  final Future<void> avvio;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'triburba',
    debugShowCheckedModeBanner: false,
    navigatorKey: chiaveNavigazione,
    theme: temaTriburba(),
    darkTheme: temaTriburba(),
    themeMode: ThemeMode.dark,
    locale: const Locale('it'),
    supportedLocales: const [Locale('it')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: FutureBuilder<void>(
      future: avvio,
      builder: (_, s) {
        if (s.connectionState != ConnectionState.done) return const Avvio();
        if (s.hasError) return const _ErroreAvvio();
        return ListenableBuilder(
          listenable: stato,
          builder: (_, _) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: stato.collegato ? const SchermataHome(key: ValueKey('home')) : const SchermataBenvenuto(key: ValueKey('benvenuto')),
          ),
        );
      },
    ),
  );
}

/// Avvio: emblema che respira sul nero vernice, scritta e motto.
class Avvio extends StatefulWidget {
  const Avvio({super.key});

  @override
  State<Avvio> createState() => _AvvioState();
}

class _AvvioState extends State<Avvio> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: vernice,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: Tween(begin: .94, end: 1.04).animate(CurvedAnimation(parent: _a, curve: Curves.easeInOut)),
            child: emblema(120),
          ),
          const SizedBox(height: 16),
          const Marchio(misura: 40),
          const SizedBox(height: 8),
          const Text(
            'OGNI QUARTIERE UNA VOCE',
            style: TextStyle(color: muto, letterSpacing: 2, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _ErroreAvvio extends StatelessWidget {
  const _ErroreAvvio();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Non riesco ad aprire triburba. Chiudi l\'app e riaprila; se succede ancora scrivi a info@triburba.it.',
          textAlign: TextAlign.center,
          style: TextStyle(color: testo2, height: 1.4),
        ),
      ),
    ),
  );
}
