// Struttura dell'app: barra in basso (Home, Tribù, Scrivi, Notifiche, Profilo) e apertura delle destinazioni
// che arrivano da notifiche push e link.
import 'dart:async';

import 'package:flutter/material.dart';

import '../dati/stato.dart';
import '../tema.dart';
import 'feed.dart';
import 'mappa.dart';
import 'naviga.dart';
import 'notifiche.dart';
import 'scrivi.dart';
import 'utente.dart';

class SchermataHome extends StatefulWidget {
  const SchermataHome({super.key});

  @override
  State<SchermataHome> createState() => _SchermataHomeState();
}

class _SchermataHomeState extends State<SchermataHome> with WidgetsBindingObserver {
  int _scheda = 0;
  final _feed = GlobalKey<SchermataFeedState>();
  final _notifiche = GlobalKey<SchermataNotificheState>();
  Timer? _orologio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    stato.addListener(_cambio);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cambio();
      if (!tkPlay) proponiAggiornamento(context, avvisaSeAggiornata: false);
    });
    // contatore delle notifiche aggiornato anche senza push (ogni 2 minuti con l'app aperta)
    _orologio = Timer.periodic(const Duration(minutes: 2), (_) => stato.ricarica());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stato.removeListener(_cambio);
    _orologio?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) stato.ricarica();
  }

  void _cambio() {
    final vai = stato.daAprire;
    if (vai == null || !mounted) {
      if (mounted) setState(() {});
      return;
    }
    stato.daAprire = null;
    switch (vai['tipo']) {
      case 'mappa':
        setState(() => _scheda = 1);
      case 'notifiche':
        setState(() => _scheda = 3);
        _notifiche.currentState?.aggiorna();
      default:
        final ctx = chiaveNavigazione.currentContext ?? context;
        apriDestinazione(ctx, vai);
    }
  }

  Future<void> _scrivi() async {
    final p = await apriScrivi(context);
    if (p != null) {
      setState(() => _scheda = 0);
      _feed.currentState?.aggiornaTutto();
    }
  }

  @override
  Widget build(BuildContext context) {
    final io = stato.io;
    final n = stato.notifiche;
    return Scaffold(
      body: IndexedStack(
        index: _scheda,
        children: [
          SchermataFeed(key: _feed),
          const SchermataMappa(),
          const SizedBox.shrink(),
          SchermataNotifiche(key: _notifiche),
          if (io != null)
            SchermataUtente(key: ValueKey('io-${io.username}'), username: io.username, mio: true)
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _scheda,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          if (i == 2) {
            _scrivi();
            return;
          }
          if (i == 3) _notifiche.currentState?.aggiorna();
          setState(() => _scheda = i);
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'Tribù'),
          NavigationDestination(
            icon: Container(
              width: 50,
              height: 36,
              decoration: BoxDecoration(gradient: gradienteBottone, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add_rounded, color: bianco, size: 28),
            ),
            label: 'Scrivi',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: n > 0,
              label: Text(n > 99 ? '99+' : '$n'),
              backgroundColor: pompeiano,
              child: const Icon(Icons.notifications_none_rounded),
            ),
            selectedIcon: Badge(
              isLabelVisible: n > 0,
              label: Text(n > 99 ? '99+' : '$n'),
              backgroundColor: pompeiano,
              child: const Icon(Icons.notifications_rounded),
            ),
            label: 'Notifiche',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profilo'),
        ],
      ),
    );
  }
}
