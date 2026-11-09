// Ricerca di persone, quartieri e post (la stessa del sito).
import 'dart:async';

import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/faccia.dart';
import 'naviga.dart';

class SchermataCerca extends StatefulWidget {
  const SchermataCerca({super.key});

  @override
  State<SchermataCerca> createState() => _SchermataCercaState();
}

class _SchermataCercaState extends State<SchermataCerca> {
  final _campo = TextEditingController();
  Timer? _attesa;
  Map<String, dynamic>? _r;
  bool _carico = false;
  String? _errore;

  @override
  void dispose() {
    _attesa?.cancel();
    _campo.dispose();
    super.dispose();
  }

  void _scrive(String q) {
    _attesa?.cancel();
    if (q.trim().length < 2) {
      setState(() => _r = null);
      return;
    }
    _attesa = Timer(const Duration(milliseconds: 300), () => _cerca(q.trim()));
  }

  Future<void> _cerca(String q) async {
    setState(() => _carico = true);
    try {
      final r = await stato.api.cerca(q);
      if (mounted && _campo.text.trim() == q) {
        setState(() {
          _r = r;
          _errore = null;
        });
      }
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    } finally {
      if (mounted) setState(() => _carico = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final persone = (_r?['persone'] as List? ?? []).cast<Map<String, dynamic>>();
    final quartieri = (_r?['quartieri'] as List? ?? []).cast<Map<String, dynamic>>();
    final post = (_r?['post'] as List? ?? []).cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _campo,
          autofocus: true,
          onChanged: _scrive,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Cerca persone, quartieri, post…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
        bottom: _carico ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
      ),
      body: _errore != null
          ? Center(
              child: Text(_errore!, style: const TextStyle(color: muto)),
            )
          : _r == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Scrivi almeno due lettere.', style: TextStyle(color: muto)),
              ),
            )
          : ListView(
              children: [
                if (persone.isEmpty && quartieri.isEmpty && post.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('Nessun risultato.', style: TextStyle(color: muto)),
                    ),
                  ),
                if (persone.isNotEmpty) _sezione('Persone'),
                for (final u in persone)
                  ListTile(
                    leading: FotoProfilo.da(nome: '${u['nome']}', avatar: u['avatar'] as String?, lato: 42),
                    title: Text('${u['nome']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '@${u['username']}${u['quartiere'] != null ? ' · ${u['quartiere']}' : ''}',
                      style: const TextStyle(color: muto),
                    ),
                    onTap: () => apriUtente(context, '${u['username']}'),
                  ),
                if (quartieri.isNotEmpty) _sezione('Quartieri'),
                for (final q in quartieri)
                  ListTile(
                    leading: CircleAvatar(backgroundColor: colore('${q['colore']}'), radius: 10),
                    title: Text('${q['nome']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${q['mun']} · ${q['residenti']} residenti', style: const TextStyle(color: muto)),
                    onTap: () => apriQuartiere(context, '${q['slug']}'),
                  ),
                if (post.isNotEmpty) _sezione('Post'),
                for (final p in post)
                  ListTile(
                    leading: FotoProfilo.da(nome: '${p['nome']}', avatar: p['avatar'] as String?, lato: 36),
                    title: Text('${p['testo']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${p['nome']} · ${p['quando']}', style: const TextStyle(color: muto)),
                    onTap: () {
                      final d = destinazioneDaLink('${p['link']}');
                      if (d != null) apriDestinazione(context, d);
                    },
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _sezione(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
    child: Text(
      t.toUpperCase(),
      style: const TextStyle(color: muto, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6),
    ),
  );
}
