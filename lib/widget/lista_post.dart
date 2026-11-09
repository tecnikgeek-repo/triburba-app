// Lista di post con «tira per aggiornare» e caricamento dei più vecchi scorrendo (feed, quartiere, profilo).
import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../tema.dart';
import 'post_card.dart';

typedef CaricaPagina = Future<(List<Post>, bool)> Function(int prima);

class ListaPost extends StatefulWidget {
  const ListaPost({super.key, required this.carica, this.testa, this.vuoto, this.controller});

  final CaricaPagina carica;

  /// Contenuto sopra i post (testata del quartiere o del profilo).
  final Widget? testa;
  final Widget? vuoto;
  final ScrollController? controller;

  @override
  State<ListaPost> createState() => ListaPostState();
}

class ListaPostState extends State<ListaPost> with AutomaticKeepAliveClientMixin {
  final _post = <Post>[];
  bool _altri = true;
  bool _carico = false;
  String? _errore;
  bool _primaVolta = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    aggiorna();
  }

  /// Ricarica da capo (anche dopo aver pubblicato).
  Future<void> aggiorna() async {
    try {
      final (p, altri) = await widget.carica(0);
      if (!mounted) return;
      setState(() {
        _post
          ..clear()
          ..addAll(p);
        _altri = altri;
        _errore = null;
        _primaVolta = false;
      });
    } on ErroreApi catch (e) {
      if (mounted) {
        setState(() {
          _errore = e.messaggio;
          _primaVolta = false;
        });
      }
    }
  }

  /// Mette in cima un post appena pubblicato.
  void inCima(Post p) => setState(() => _post.insert(0, p));

  Future<void> _altriPost() async {
    if (_carico || !_altri || _post.isEmpty) return;
    _carico = true;
    try {
      final (p, altri) = await widget.carica(_post.last.id);
      if (!mounted) return;
      setState(() {
        _post.addAll(p.where((x) => !_post.any((y) => y.id == x.id)));
        _altri = altri;
      });
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      _carico = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pezzi = <Widget>[
      ?widget.testa,
      if (_primaVolta)
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_errore != null && _post.isEmpty)
        _Messaggio(icona: Icons.wifi_off_rounded, testo: _errore!, azione: ('Riprova', aggiorna))
      else if (_post.isEmpty)
        widget.vuoto ?? const _Messaggio(icona: Icons.forum_outlined, testo: 'Qui non c\'è ancora nessun post.'),
    ];
    return RefreshIndicator(
      onRefresh: aggiorna,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 900) _altriPost();
          return false;
        },
        child: ListView.builder(
          controller: widget.controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 12, bottom: 90),
          itemCount: pezzi.length + _post.length + (_altri && _post.isNotEmpty ? 1 : 0),
          itemBuilder: (c, i) {
            if (i < pezzi.length) return pezzi[i];
            final k = i - pezzi.length;
            if (k == _post.length) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final p = _post[k];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: PostCard(key: ValueKey(p.id), post: p, onEliminato: () => setState(() => _post.remove(p))),
            );
          },
        ),
      ),
    );
  }
}

class _Messaggio extends StatelessWidget {
  const _Messaggio({required this.icona, required this.testo, this.azione});

  final IconData icona;
  final String testo;
  final (String, VoidCallback)? azione;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
    child: Column(
      children: [
        Icon(icona, size: 48, color: muto),
        const SizedBox(height: 12),
        Text(
          testo,
          textAlign: TextAlign.center,
          style: const TextStyle(color: testo2, fontSize: 15, height: 1.4),
        ),
        if (azione != null) ...[const SizedBox(height: 14), OutlinedButton(onPressed: azione!.$2, child: Text(azione!.$1))],
      ],
    ),
  );
}

/// Messaggio vuoto con un invito, riusabile dalle schermate.
class Vuoto extends StatelessWidget {
  const Vuoto({super.key, required this.icona, required this.testo, this.azione});

  final IconData icona;
  final String testo;
  final (String, VoidCallback)? azione;

  @override
  Widget build(BuildContext context) => _Messaggio(icona: icona, testo: testo, azione: azione);
}
