// Un post con tutti i commenti (un livello di risposte, come una chat) e la casella per commentare.
import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/emoji.dart';
import '../widget/faccia.dart';
import '../widget/post_card.dart';
import '../widget/testo_ricco.dart';
import 'naviga.dart';

class SchermataPost extends StatefulWidget {
  const SchermataPost({super.key, required this.id, this.post, this.scrivi = false});

  final int id;
  final Post? post;
  final bool scrivi;

  @override
  State<SchermataPost> createState() => _SchermataPostState();
}

class _SchermataPostState extends State<SchermataPost> {
  Post? _post;
  List<Commento>? _commenti;
  bool _puoCommentare = true;
  String? _errore;
  final _campo = TextEditingController();
  final _fuoco = FocusNode();
  Commento? _rispostaA;
  bool _invio = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _carica();
    if (widget.scrivi) WidgetsBinding.instance.addPostFrameCallback((_) => _fuoco.requestFocus());
  }

  @override
  void dispose() {
    _campo.dispose();
    _fuoco.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    try {
      final p = await stato.api.leggiPost(widget.id);
      final (c, puo) = await stato.api.commenti(widget.id);
      if (!mounted) return;
      setState(() {
        _post = p;
        _commenti = c;
        _puoCommentare = puo;
        _errore = null;
      });
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  Future<void> _invia() async {
    final t = _campo.text.trim();
    if (t.isEmpty || _invio) return;
    setState(() => _invio = true);
    try {
      final c = await stato.api.commenta(widget.id, t, rispostaA: _rispostaA?.id);
      if (!mounted) return;
      setState(() {
        _commenti = [...?_commenti, c];
        _post?.commenti++;
        _campo.clear();
        _rispostaA = null;
      });
      FocusScope.of(context).unfocus();
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _invio = false);
    }
  }

  Future<void> _reagisci(Commento c, String r) async {
    try {
      final j = await stato.api.reagisciCommento(c.id, r);
      if (!mounted) return;
      setState(() {
        c.mia = j['mia'] as String?;
        c.likes = (j['likes'] as num).toInt();
        c.top = (j['top'] as List).map((e) => '$e').toList();
      });
      if (c.mia != null) esplodiEmoji(context, c.mia!);
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    }
  }

  Future<void> _elimina(Commento c) async {
    if (!await conferma(context, 'Eliminare il commento?', 'Spariscono anche le risposte.')) return;
    try {
      await stato.api.eliminaCommento(c.id);
      if (!mounted) return;
      setState(() {
        final tolti = _commenti!.where((x) => x.id == c.id || x.padre == c.id).length;
        _commenti!.removeWhere((x) => x.id == c.id || x.padre == c.id);
        _post?.commenti -= tolti;
      });
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _post;
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: p == null
                ? Center(
                    child: _errore == null
                        ? const CircularProgressIndicator()
                        : Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_errore!, textAlign: TextAlign.center),
                          ),
                  )
                : RefreshIndicator(
                    onRefresh: _carica,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      children: [
                        PostCard(
                          post: p,
                          dettaglio: true,
                          onCommenta: () => _fuoco.requestFocus(),
                          onEliminato: () => Navigator.pop(context),
                        ),
                        if (_commenti == null)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_commenti!.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text('Ancora nessun commento: scrivi il primo.', style: TextStyle(color: muto)),
                            ),
                          )
                        else
                          for (final c in _commenti!.where((c) => c.padre == null)) ...[
                            _commento(c),
                            for (final r in _commenti!.where((x) => x.padre == c.id))
                              Padding(padding: const EdgeInsets.only(left: 40), child: _commento(r)),
                          ],
                      ],
                    ),
                  ),
          ),
          if (p != null) _casella(),
        ],
      ),
    );
  }

  Widget _commento(Commento c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => apriUtente(context, c.username),
          child: FotoProfilo.da(nome: c.nome, avatar: c.avatar, lato: 34),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: () async {
                  final r = await scegliReazione(context, attuale: c.mia);
                  if (r != null) _reagisci(c, r);
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
                  decoration: BoxDecoration(color: superficie2, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          StemmaMini(stemma: c.stemma, altezza: 14),
                          if (c.autoreDelPost) ...[
                            const SizedBox(width: 6),
                            const Text(
                              'AUTORE',
                              style: TextStyle(color: terracotta, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .4),
                            ),
                          ],
                          if (c.bot) ...[const SizedBox(width: 5), const PillaProva()],
                        ],
                      ),
                      const SizedBox(height: 2),
                      TestoRicco(c.testo, stile: const TextStyle(fontSize: 14.5, height: 1.4, color: testo)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 3),
                child: Row(
                  children: [
                    Text(_quando(c.creato), style: const TextStyle(color: muto, fontSize: 12)),
                    _azioncina(
                      c.mia == null ? 'Mi piace' : nomiReazioni[c.mia]!,
                      () => _reagisci(c, c.mia ?? 'cuore'),
                      colore: c.mia == null ? muto : (c.mia == 'cuore' ? pompeiano : oro),
                      // tenendo premuto «Mi piace» si sceglie l'emoji, come sul sito
                      tenuto: () async {
                        final r = await scegliReazione(context, attuale: c.mia);
                        if (r != null) _reagisci(c, r);
                      },
                    ),
                    if (_puoCommentare)
                      _azioncina('Rispondi', () {
                        setState(() => _rispostaA = c);
                        _fuoco.requestFocus();
                      }),
                    if (c.puoEliminare) _azioncina('Elimina', () => _elimina(c)),
                    const Spacer(),
                    if (c.likes > 0) ...[
                      PilaEmoji(c.top.isEmpty && c.mia != null ? [c.mia!] : c.top, lato: 15),
                      const SizedBox(width: 3),
                      Text('${c.likes}', style: const TextStyle(color: muto, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _azioncina(String t, VoidCallback f, {Color colore = muto, VoidCallback? tenuto}) => InkWell(
    onTap: f,
    onLongPress: tenuto,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        t,
        style: TextStyle(color: colore, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
  );

  String _quando(DateTime? d) {
    if (d == null) return '';
    final s = DateTime.now().difference(d).inSeconds;
    if (s < 60) return 'adesso';
    if (s < 3600) return '${s ~/ 60} min';
    if (s < 86400) return '${s ~/ 3600} h';
    if (s < 172800) return 'ieri';
    if (s < 604800) return '${s ~/ 86400} g';
    const mesi = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
    return '${d.day} ${mesi[d.month - 1]}${d.year != DateTime.now().year ? ' ${d.year}' : ''}';
  }

  Widget _casella() {
    if (!_puoCommentare) {
      return const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'Qui possono commentare solo i residenti confermati.',
            style: TextStyle(color: muto),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final io = stato.io;
    return Container(
      decoration: const BoxDecoration(
        color: vernice2,
        border: Border(top: BorderSide(color: linea)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_rispostaA != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Rispondi a ${_rispostaA!.nome}',
                        style: const TextStyle(color: testo2, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _rispostaA = null),
                      icon: const Icon(Icons.close, size: 18, color: muto),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (io != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: FotoProfilo(faccia: io.faccia, lato: 34),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _campo,
                      focusNode: _fuoco,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: io?.maxCommento,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Scrivi un commento…',
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: linea2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: linea2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: terracotta, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _invio ? null : _invia,
                    icon: _invio
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: terracotta),
                    tooltip: 'Invia',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
