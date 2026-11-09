// La card di un post, come sul sito: autore con stemma, dove è arrivato, testo, foto, anteprima del link,
// reazioni animate, commenti, tam-tam e menu (modifica, elimina, segnala, condividi).
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../schermate/naviga.dart';
import '../tema.dart';
import 'emoji.dart';
import 'faccia.dart';
import 'tamtam.dart';
import 'testo_ricco.dart';

class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.post, this.onEliminato, this.dettaglio = false, this.onCommenta});

  final Post post;
  final VoidCallback? onEliminato;

  /// Nella schermata del post: niente anteprima dei commenti (ci sono tutti sotto).
  final bool dettaglio;
  final VoidCallback? onCommenta;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  Post get p => widget.post;
  bool _occupato = false;
  bool _mostraFoto = false;

  Future<void> _reagisci(String r) async {
    if (_occupato) return;
    final prima = (p.reazioni.mia, p.reazioni.n, p.reazioni.top, p.reazioni.chi);
    final togli = p.reazioni.mia == r;
    setState(() {
      // aggiorno subito, poi allineo con il server
      if (p.reazioni.mia == null) p.reazioni.n++;
      if (togli) p.reazioni.n--;
      p.reazioni.mia = togli ? null : r;
    });
    if (!togli) esplodiEmoji(context, r);
    HapticFeedback.lightImpact();
    _occupato = true;
    try {
      final j = await stato.api.reagisci(p.id, r);
      if (!mounted) return;
      setState(() {
        p.reazioni.mia = j['reazione'] as String?;
        p.reazioni.n = (j['like_count'] as num).toInt();
        p.reazioni.top = (j['top'] as List).map((e) => '$e').toList();
        final n = p.reazioni.n;
        p.reazioni.chi = p.reazioni.mia != null
            ? (n > 1 ? 'Tu e ${n - 1 == 1 ? "un'altra persona" : 'altre ${n - 1} persone'}' : 'Tu')
            : (n > 0 ? '$n' : '');
      });
    } on ErroreApi catch (e) {
      if (!mounted) return;
      setState(() {
        p.reazioni.mia = prima.$1;
        p.reazioni.n = prima.$2;
        p.reazioni.top = prima.$3;
        p.reazioni.chi = prima.$4;
      });
      messaggio(context, e.messaggio);
    } finally {
      _occupato = false;
    }
  }

  Future<void> _menu() async {
    final scelta = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p.puoModificare) _voce(c, 'modifica', Icons.edit_outlined, 'Modifica'),
            if (p.puoEliminare) _voce(c, 'elimina', Icons.delete_outline, 'Elimina', pericolo: true),
            _voce(c, 'condividi', Icons.share_outlined, 'Condividi'),
            _voce(c, 'copia', Icons.link, 'Copia link'),
            if (p.puoSegnalare) _voce(c, 'segnala', Icons.flag_outlined, 'Segnala', pericolo: true),
            if (p.segnalato)
              const ListTile(
                leading: Icon(Icons.check, color: golfo),
                title: Text('Hai già segnalato questo post'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || scelta == null) return;
    switch (scelta) {
      case 'modifica':
        final nuovo = await modificaTesto(context, p.testo, stato.io?.maxPost ?? 3000);
        if (nuovo == null || nuovo == p.testo || !mounted) return;
        try {
          await stato.api.modifica(p.id, nuovo);
          if (mounted) setState(() => p.testo = nuovo);
        } on ErroreApi catch (e) {
          if (mounted) messaggio(context, e.messaggio);
        }
      case 'elimina':
        if (!await conferma(context, 'Eliminare il post?', 'Spariscono anche commenti e reazioni. Non si può annullare.')) return;
        try {
          await stato.api.elimina(p.id);
          widget.onEliminato?.call();
          if (mounted) messaggio(context, 'Post eliminato.');
        } on ErroreApi catch (e) {
          if (mounted) messaggio(context, e.messaggio);
        }
      case 'condividi':
        SharePlus.instance.share(ShareParams(text: '${senzaFormato(p.testo).characters.take(140)}\n\n$sito${p.url}'));
      case 'copia':
        await Clipboard.setData(ClipboardData(text: '$sito${p.url}'));
        if (mounted) messaggio(context, 'Link copiato.');
      case 'segnala':
        await _segnala();
    }
  }

  Widget _voce(BuildContext c, String id, IconData ico, String t, {bool pericolo = false}) => ListTile(
    leading: Icon(ico, color: pericolo ? pompeiano : testo2),
    title: Text(
      t,
      style: TextStyle(color: pericolo ? pompeiano : testo, fontWeight: FontWeight.w600),
    ),
    onTap: () => Navigator.pop(c, id),
  );

  Future<void> _segnala() async {
    final motivi = stato.io?.motivi ?? const [];
    final m = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Perché lo segnali?', style: titolo(20)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Quando abbastanza residenti lo segnalano, il post viene nascosto in attesa dei moderatori.',
                style: TextStyle(color: muto, fontSize: 13),
              ),
            ),
            for (final x in motivi) ListTile(title: Text(x), onTap: () => Navigator.pop(c, x)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (m == null || !mounted) return;
    try {
      final msg = await stato.api.segnala(p.id, m);
      if (!mounted) return;
      setState(() {
        p.segnalato = true;
        p.puoSegnalare = false;
      });
      messaggio(context, msg);
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qCol = colore(p.quartiere?.colore);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: linea),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // filo del colore del quartiere
          Container(height: 3, color: qCol.withValues(alpha: .85)),
          if (p.nascosto != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: pompeiano.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.visibility_off_outlined, color: pompeiano, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nascosto ${p.nascosto} dopo le segnalazioni dei residenti. Lo vedono solo l\'autore e lo staff.',
                      style: const TextStyle(fontSize: 12.5, color: testo2),
                    ),
                  ),
                ],
              ),
            ),
          _testa(),
          if (p.quartiere != null || p.portate.isNotEmpty || p.rilanci > 0 || p.citta || p.area) _dove(),
          if (p.candidatura != null || p.tipo == 'candidatura') _candidatura(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: TestoRicco(
              p.testo,
              stile: (p.immagine == null && p.testo.length <= 120 && '\n'.allMatches(p.testo).length < 3)
                  ? const TextStyle(fontSize: 20, height: 1.35, color: testo, fontWeight: FontWeight.w500)
                  : null,
            ),
          ),
          if (p.immagine != null) _foto(),
          if (p.link != null && p.immagine == null) _anteprimaLink(p.link!),
          _numeri(),
          const Divider(height: 1),
          _azioni(),
          if (!widget.dettaglio && p.anteprima.isNotEmpty) _anteprimaCommenti(),
        ],
      ),
    );
  }

  Widget _testa() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => apriUtente(context, p.autore.username),
          child: FotoProfilo(faccia: p.autore, lato: 40, anello: true),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => apriUtente(context, p.autore.username),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.autore.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 5),
                    StemmaMini(stemma: p.autore.stemma),
                    if (p.autore.bot) ...[const SizedBox(width: 5), const PillaProva()],
                  ],
                ),
                Text(
                  '@${p.autore.username} · ${p.quando}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muto, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: _menu,
          icon: const Icon(Icons.more_horiz, color: muto),
          tooltip: 'Altre azioni',
        ),
      ],
    ),
  );

  Widget _dove() {
    final chips = <Widget>[];
    if (p.quartiere != null) {
      chips.add(
        Chip2(
          testo: p.quartiere!.nome,
          icona: Icons.place_outlined,
          colore: colore(p.quartiere!.colore),
          onTap: p.quartiere!.slug == null ? null : () => apriQuartiere(context, p.quartiere!.slug!),
        ),
      );
    }
    for (final x in p.portate) {
      if (x.attesa) {
        chips.add(Chip2(testo: 'In attesa: ${x.nome}', icona: Icons.schedule, colore: muto, tenue: true));
      } else if (x.livello == 'quartiere') {
        chips.add(
          Chip2(
            testo: x.nome,
            icona: Icons.call_split,
            colore: colore(x.colore),
            onTap: x.slug == null ? null : () => apriQuartiere(context, x.slug!),
          ),
        );
      } else {
        chips.add(Chip2(testo: x.nome, icona: Icons.layers_outlined, colore: golfo));
      }
    }
    if (p.area) chips.add(const Chip2(testo: 'Area metropolitana', icona: Icons.map_outlined, colore: oro));
    if (p.citta) {
      chips.add(const Chip2(testo: 'Tutta Napoli', icona: Icons.location_city, colore: oro));
    } else if (p.rilanci > 0) {
      chips.add(
        Chip2(
          testo: p.daComune ? "Verso l'area ${p.rilanci}" : 'Verso Napoli ${p.rilanci}/${p.soglia}',
          icona: Icons.campaign_outlined,
          colore: oro,
          tenue: true,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  Widget _candidatura() {
    final c = p.candidatura;
    final eletto = c?['eletto'] == true;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [terracotta.withValues(alpha: .16), oro.withValues(alpha: .1)]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: oro.withValues(alpha: .3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.how_to_vote_outlined, color: oro, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eletto ? 'Eletto moderatore' : 'Si candida a moderatore', style: const TextStyle(color: muto, fontSize: 12)),
                Text('${p.autore.nome} per ${p.quartiere?.nome ?? 'il quartiere'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  c == null ? 'Candidatura ritirata' : '${c['voti']} ${c['voti'] == 1 ? 'voto' : 'voti'}',
                  style: const TextStyle(color: oro, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (p.quartiere?.slug != null)
            TextButton(
              onPressed: () => launchUrl(Uri.parse('$sito/q/${p.quartiere!.slug}?t=moderatori'), mode: LaunchMode.externalApplication),
              child: const Text('Vota sul sito'),
            ),
        ],
      ),
    );
  }

  Widget _foto() {
    final url = assoluto(p.immagine)!;
    Widget img = CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      placeholder: (_, _) => const AspectRatio(
        aspectRatio: 4 / 3,
        child: ColoredBox(color: superficie2),
      ),
      errorWidget: (_, _, _) => const AspectRatio(
        aspectRatio: 4 / 3,
        child: ColoredBox(
          color: superficie2,
          child: Icon(Icons.broken_image_outlined, color: muto),
        ),
      ),
    );
    if (p.sfocata && !_mostraFoto) {
      img = Stack(
        alignment: Alignment.center,
        children: [
          ClipRect(
            child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28), child: img),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility_off_outlined, color: bianco, size: 30),
              const SizedBox(height: 6),
              const Text(
                'Foto in revisione',
                style: TextStyle(color: bianco, fontWeight: FontWeight.w800),
              ),
              TextButton(onPressed: () => setState(() => _mostraFoto = true), child: const Text('Mostra comunque')),
            ],
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: (p.sfocata && !_mostraFoto) ? null : () => apriFoto(context, url),
      onDoubleTap: () => _reagisci('cuore'),
      child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 560), child: img),
    );
  }

  Widget _anteprimaLink(AnteprimaLink l) => GestureDetector(
    onTap: () => launchUrl(Uri.parse(l.url), mode: LaunchMode.externalApplication),
    child: Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: superficie2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: linea),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (l.immagine != null)
            CachedNetworkImage(
              imageUrl: assoluto(l.immagine)!,
              height: 170,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (l.sito ?? '').toUpperCase(),
                  style: const TextStyle(color: muto, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .4),
                ),
                if (l.titolo != null)
                  Text(
                    l.titolo!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                if (l.descrizione != null)
                  Text(
                    l.descrizione!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: testo2, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _numeri() {
    if (p.reazioni.n == 0 && p.commenti == 0) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      child: Row(
        children: [
          if (p.reazioni.n > 0)
            Expanded(
              child: GestureDetector(
                onTap: () => apriChiHaReagito(context, p.id),
                child: Row(
                  children: [
                    PilaEmoji(p.reazioni.top.isEmpty && p.reazioni.mia != null ? [p.reazioni.mia!] : p.reazioni.top),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        p.reazioni.chi.isEmpty ? '${p.reazioni.n}' : p.reazioni.chi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: testo2, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const Spacer(),
          if (p.commenti > 0)
            GestureDetector(
              onTap: _apriCommenti,
              child: Text(
                '${p.commenti} ${p.commenti == 1 ? 'commento' : 'commenti'}',
                style: const TextStyle(color: testo2, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  void _apriCommenti() {
    if (widget.onCommenta != null) {
      widget.onCommenta!();
    } else {
      apriPost(context, p.id, post: p, scrivi: true);
    }
  }

  Widget _azioni() {
    final mia = p.reazioni.mia;
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          _azione(
            icona: mia == null ? const Icon(Icons.favorite_border, color: testo2, size: 22) : Emoji(mia, lato: 22),
            testo: mia == null ? 'Mi piace' : (nomiReazioni[mia] ?? 'Mi piace'),
            colore: mia == null ? testo2 : (mia == 'cuore' ? pompeiano : oro),
            onTap: () => _reagisci(mia ?? 'cuore'),
            onLongPress: () async {
              final r = await scegliReazione(context, attuale: mia);
              if (r != null) _reagisci(r);
            },
          ),
          _azione(
            icona: const Icon(Icons.chat_bubble_outline, color: testo2, size: 21),
            testo: 'Commenta',
            onTap: _apriCommenti,
          ),
          _azione(
            icona: Icon(Icons.campaign_outlined, color: p.mioRilancio ? oro : testo2, size: 23),
            testo: 'Tam-tam',
            colore: p.mioRilancio ? oro : testo2,
            onTap: () async {
              if (!p.puoTamtam) {
                messaggio(
                  context,
                  'Il tam-tam lo fanno i residenti confermati: chiedi a ${stato.io?.viciniGaranti ?? 'i vicini'} di garantire per te.',
                );
                return;
              }
              final ok = await apriTamtam(context, p);
              if (ok && mounted) setState(() {});
            },
          ),
          _azione(
            icona: const Icon(Icons.share_outlined, color: testo2, size: 21),
            testo: 'Condividi',
            onTap: () => SharePlus.instance.share(ShareParams(text: '${senzaFormato(p.testo).characters.take(140)}\n\n$sito${p.url}')),
          ),
        ],
      ),
    );
  }

  Widget _azione({required Widget icona, required String testo, Color colore = testo2, VoidCallback? onTap, VoidCallback? onLongPress}) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icona,
              const SizedBox(height: 3),
              Text(
                testo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colore, fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );

  Widget _anteprimaCommenti() => InkWell(
    onTap: _apriCommenti,
    child: Container(
      color: vernice2.withValues(alpha: .5),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          for (final c in p.anteprima)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FotoProfilo(faccia: c.autore, lato: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(color: superficie2, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.autore.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          TestoRicco(c.testo, maxRighe: 3, stile: const TextStyle(fontSize: 13.5, height: 1.35, color: testo)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (p.commenti > p.anteprima.length)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 36, top: 2),
                child: Text(
                  'Vedi tutti i ${p.commenti} commenti',
                  style: const TextStyle(color: muto, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Finestra per modificare il testo di un post.
Future<String?> modificaTesto(BuildContext context, String attuale, int max) async {
  final c = TextEditingController(text: attuale);
  final r = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Modifica il post', style: titolo(20)),
          const SizedBox(height: 12),
          TextField(controller: c, maxLines: 8, minLines: 3, maxLength: max, autofocus: true),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Salva')),
        ],
      ),
    ),
  );
  c.dispose();
  return (r == null || r.isEmpty) ? null : r;
}
