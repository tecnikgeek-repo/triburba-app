// Scegli cosa ricevere, come Impostazioni → Notifiche sul sito: per ogni categoria
// «Campanella» (la notifica in triburba) e «Telefono» (l'avviso push). Si salva da sola.
import 'dart:async';

import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/stato.dart';
import '../tema.dart';

class CategoriaNotifica {
  CategoriaNotifica(Map<String, dynamic> j)
    : chiave = '${j['chiave']}',
      titolo = '${j['titolo']}',
      spiega = '${j['spiega'] ?? ''}',
      sempre = j['sempre'] == true,
      campanella = j['campanella'] != false,
      telefono = j['telefono'] != false;

  final String chiave, titolo, spiega;
  final bool sempre;
  bool campanella, telefono;
}

class SchermataPreferenzeNotifiche extends StatefulWidget {
  const SchermataPreferenzeNotifiche({super.key, this.iniziali});

  /// solo per le anteprime: categorie già pronte senza chiamare il sito
  final List<Map<String, dynamic>>? iniziali;

  @override
  State<SchermataPreferenzeNotifiche> createState() => _SchermataPreferenzeNotificheState();
}

class _SchermataPreferenzeNotificheState extends State<SchermataPreferenzeNotifiche> {
  List<CategoriaNotifica>? _c;
  String? _errore;
  Timer? _salva;

  @override
  void initState() {
    super.initState();
    if (widget.iniziali != null) {
      _c = widget.iniziali!.map(CategoriaNotifica.new).toList();
    } else {
      _carica();
    }
  }

  @override
  void dispose() {
    _salva?.cancel();
    super.dispose();
  }

  Future<void> _carica() async {
    try {
      final j = await stato.api.preferenzeNotifiche();
      if (!mounted) return;
      setState(() => _c = (j['categorie'] as List).map((e) => CategoriaNotifica(e as Map<String, dynamic>)).toList());
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  void _cambia(CategoriaNotifica c, {bool? campanella, bool? telefono}) {
    setState(() {
      if (campanella != null) {
        c.campanella = campanella;
        if (!campanella) c.telefono = false; // senza campanella niente avviso sul telefono
      }
      if (telefono != null) c.telefono = telefono;
    });
    _salva?.cancel();
    _salva = Timer(const Duration(milliseconds: 400), _invia);
  }

  Future<void> _invia() async {
    final c = _c;
    if (c == null || widget.iniziali != null) return;
    try {
      await stato.api.salvaPreferenzeNotifiche({
        for (final x in c) x.chiave: {'campanella': x.campanella, 'telefono': x.telefono},
      });
      if (mounted) messaggio(context, 'Preferenze salvate');
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifiche')),
      body: c == null
          ? Center(
              child: _errore == null ? const CircularProgressIndicator() : Text(_errore!, style: const TextStyle(color: muto)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                const Text(
                  'Scegli di cosa vuoi essere avvisato. Campanella: la notifica compare in triburba. '
                  'Telefono: arriva anche come avviso sul telefono. Le scelte si salvano da sole.',
                  style: TextStyle(color: muto, height: 1.4),
                ),
                const SizedBox(height: 14),
                for (final x in c) _riga(x),
              ],
            ),
    );
  }

  Widget _riga(CategoriaNotifica c) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
    decoration: BoxDecoration(color: superficie, borderRadius: BorderRadius.circular(14), border: Border.all(color: linea)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(c.titolo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
        const SizedBox(height: 3),
        Text(c.spiega, style: const TextStyle(color: muto, fontSize: 13, height: 1.35)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _interruttore(
                'Campanella',
                Icons.notifications_none_rounded,
                c.campanella,
                c.sempre ? null : (v) => _cambia(c, campanella: v),
                fisso: c.sempre,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _interruttore(
                'Telefono',
                Icons.smartphone_rounded,
                c.telefono,
                c.campanella ? (v) => _cambia(c, telefono: v) : null,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _interruttore(String t, IconData i, bool v, ValueChanged<bool>? onChanged, {bool fisso = false}) => Opacity(
    opacity: onChanged == null && !fisso ? .55 : 1,
    child: Container(
      height: 46,
      padding: const EdgeInsets.only(left: 12, right: 2),
      decoration: BoxDecoration(color: vernice2, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Text(t, maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          ),
          if (fisso)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text('SEMPRE', style: TextStyle(color: oro, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: .4)),
            )
          else
            Transform.scale(
              scale: .8,
              child: Switch(value: v, onChanged: onChanged, activeTrackColor: terracotta, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
        ],
      ),
    ),
  );
}
