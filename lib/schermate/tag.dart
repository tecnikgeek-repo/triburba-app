// La pagina di un hashtag, come /tag/parola sul sito: i post che lo usano, quanti sono, chi lo segue,
// e «Segui #parola» (i post con l'hashtag arrivano in «Per te» anche da altri quartieri).
import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/post_card.dart';

class SchermataTag extends StatefulWidget {
  const SchermataTag({super.key, required this.tag});

  final String tag;

  @override
  State<SchermataTag> createState() => _SchermataTagState();
}

class _SchermataTagState extends State<SchermataTag> {
  String get tag => widget.tag.toLowerCase().replaceFirst('#', '');
  List<Post> _post = [];
  int _nPost = 0, _seguaci = 0;
  bool _seguo = false, _carico = true, _occupato = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _carico = true;
      _errore = null;
    });
    try {
      final j = await stato.api.tag(tag);
      if (!mounted) return;
      setState(() {
        _post = (j['post'] as List? ?? []).map((p) => Post(p as Map<String, dynamic>)).toList();
        _nPost = (j['n_post'] as num? ?? 0).toInt();
        _seguaci = (j['seguaci'] as num? ?? 0).toInt();
        _seguo = j['seguo'] == true;
        _carico = false;
      });
    } on ErroreApi catch (e) {
      if (mounted) {
        setState(() {
          _errore = e.messaggio;
          _carico = false;
        });
      }
    }
  }

  Future<void> _segui() async {
    if (_occupato) return;
    setState(() => _occupato = true);
    try {
      final j = await stato.api.seguiTag(tag);
      if (!mounted) return;
      setState(() {
        _seguo = j['seguo'] == true;
        _seguaci = (j['seguaci'] as num? ?? _seguaci).toInt();
      });
      messaggio(context, (j['msg'] ?? '').toString());
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _occupato = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('#$tag')),
    body: _carico
        ? const Center(child: CircularProgressIndicator())
        : _errore != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_errore!, textAlign: TextAlign.center, style: const TextStyle(color: testo2)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _carica, child: const Text('Riprova')),
                ],
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _carica,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '$_nPost POST · $_seguaci ${_seguaci == 1 ? 'PERSONA LO SEGUE' : 'PERSONE LO SEGUONO'}',
                        style: const TextStyle(color: muto, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .8),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: '#', style: TextStyle(color: oro)),
                            TextSpan(text: tag),
                          ],
                        ),
                        style: titolo(30),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Segui l\'hashtag e i post che lo usano ti arrivano in «Per te», anche da altri quartieri.',
                        style: TextStyle(color: testo2, fontSize: 13.5, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      _seguo
                          ? OutlinedButton.icon(
                              onPressed: _occupato ? null : _segui,
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Segui già'),
                            )
                          : BottoneCaldo(testo: 'Segui #$tag', icona: Icons.add, occupato: _occupato, onPressed: _segui),
                    ],
                  ),
                ),
                if (_post.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Nessun post con questo hashtag, per ora.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muto),
                    ),
                  )
                else
                  for (final p in _post)
                    PostCard(
                      key: ValueKey(p.id),
                      post: p,
                      onEliminato: () => setState(() => _post.remove(p)),
                    ),
              ],
            ),
          ),
  );
}
