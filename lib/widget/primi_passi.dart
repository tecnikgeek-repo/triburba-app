// Carta «Primi passi» in cima alla Home: sette passi che si spuntano da soli coi dati veri del sito,
// barra di avanzamento, un tasto per passo e «Nascondi». A passi finiti: festa e la carta si chiude.
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../schermate/naviga.dart';
import '../schermate/profilo.dart';
import '../schermate/scrivi.dart';
import '../tema.dart';

class PrimiPassi extends StatefulWidget {
  const PrimiPassi({super.key, required this.guida, this.onLeggi});

  final Guida guida;

  /// Porta alla scheda con i post da leggere (Napoli).
  final VoidCallback? onLeggi;

  @override
  State<PrimiPassi> createState() => _PrimiPassiState();
}

class _PrimiPassiState extends State<PrimiPassi> {
  bool _via = false;

  static const _icone = {
    'foto': Icons.photo_camera_outlined,
    'casa': Icons.home_outlined,
    'garanzie': Icons.handshake_outlined,
    'partecipa': Icons.favorite_border_rounded,
    'segui': Icons.group_outlined,
    'post': Icons.edit_outlined,
    'invito': Icons.ios_share_rounded,
  };

  Future<void> _nascondi() async {
    setState(() => _via = true);
    try {
      await stato.api.guida('nascondi');
    } catch (_) {}
    stato.ricarica();
  }

  Future<void> _azione(PassoGuida p) async {
    final io = stato.io;
    switch (p.chiave) {
      case 'foto':
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SchermataModificaProfilo()));
      case 'casa':
      case 'segui':
        stato.apri({'tipo': 'mappa'});
        return;
      case 'garanzie':
        final slug = io?.casa?['slug'];
        if (slug != null) {
          await apriQuartiere(context, '$slug');
        } else {
          stato.apri({'tipo': 'mappa'});
          return;
        }
      case 'partecipa':
        widget.onLeggi?.call();
        return;
      case 'post':
        await apriScrivi(context);
      case 'invito':
        final r = await SharePlus.instance.share(
          ShareParams(
            text:
                'Ti aspetto su triburba, il social dei quartieri nato a Napoli: iscriviti e scegli il tuo quartiere.\n\n$sito/register',
          ),
        );
        if (r.status == ShareResultStatus.dismissed) return;
        try {
          await stato.api.guida('invito');
        } catch (_) {}
    }
    stato.ricarica();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guida;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: _via
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: superficie,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: terracotta.withValues(alpha: .35)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [golfo.withValues(alpha: .12), superficie, terracotta.withValues(alpha: .10)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: g.completa ? _festa() : _passi(g),
              ),
            ),
    );
  }

  Widget _festa() => Padding(
    padding: const EdgeInsets.only(right: 8, bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(gradient: gradiente, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.celebration_rounded, color: bianco, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Ce l\'hai fatta: sei dentro la tua tribù!', style: titolo(19))),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Hai fatto tutti i primi passi. Adesso triburba è casa tua: scrivi, proponi attività e fai girare le notizie che contano.',
          style: TextStyle(color: testo2, height: 1.4),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: BottoneCaldo(testo: 'Grazie, chiudi', icona: Icons.check_rounded, onPressed: _nascondi),
        ),
      ],
    ),
  );

  Widget _passi(Guida g) {
    // il prossimo passo da fare è il primo non fatto e non bloccato
    final prossimo = g.passi.indexWhere((p) => !p.fatto && !p.bloccato);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PRIMI PASSI',
                    style: TextStyle(color: terracotta, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                  const SizedBox(height: 2),
                  Text('Benvenuto su triburba', style: titolo(20)),
                  const SizedBox(height: 3),
                  const Text('Sette passi per entrare nella tua tribù. Si spuntano da soli.', style: TextStyle(color: muto, fontSize: 13)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Nascondi i primi passi',
              onPressed: _nascondi,
              icon: const Icon(Icons.close_rounded, color: muto),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: g.totale == 0 ? 0 : g.fatti / g.totale,
                    minHeight: 8,
                    backgroundColor: linea2,
                    color: terracotta,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${g.fatti}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: testo, fontSize: 15),
                    ),
                    TextSpan(text: ' su ${g.totale}'),
                  ],
                ),
                style: const TextStyle(color: muto, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < g.passi.length; i++) _passo(g.passi[i], i == prossimo),
      ],
    );
  }

  Widget _passo(PassoGuida p, bool prossimo) {
    final segno = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.fatto ? golfo : (prossimo ? null : superficie2),
        gradient: prossimo ? gradiente : null,
      ),
      child: Icon(
        p.fatto ? Icons.check_rounded : (_icone[p.chiave] ?? Icons.circle_outlined),
        size: 17,
        color: p.fatto || prossimo ? bianco : testo2,
      ),
    );
    final conta = p.conta != null && !p.fatto && p.conta![1] > 0 ? ' ${p.conta![0]}/${p.conta![1]}' : '';
    Widget? tasto;
    if (!p.fatto) {
      if (p.bloccato) {
        tasto = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 14, color: muto),
            const SizedBox(width: 4),
            Text(p.tasto, style: const TextStyle(color: muto, fontSize: 12.5)),
          ],
        );
      } else if (prossimo) {
        tasto = FilledButton(
          onPressed: () => _azione(p),
          style: FilledButton.styleFrom(
            backgroundColor: terracotta,
            foregroundColor: bianco,
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontFamily: fontTesto, fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          child: Text(p.tasto),
        );
      } else {
        tasto = TextButton(
          onPressed: () => _azione(p),
          style: TextButton.styleFrom(
            foregroundColor: oro,
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontFamily: fontTesto, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          child: Text(p.tasto),
        );
      }
    }
    return Container(
      margin: const EdgeInsets.only(top: 4, right: 8),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      decoration: BoxDecoration(color: prossimo ? Colors.white.withValues(alpha: .05) : null, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: prossimo ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          segno,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: p.titolo),
                      if (conta.isNotEmpty)
                        TextSpan(
                          text: conta,
                          style: const TextStyle(color: oro, fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                  style: TextStyle(
                    fontWeight: p.fatto ? FontWeight.w600 : FontWeight.w700,
                    fontSize: 14.5,
                    color: p.fatto ? muto : testo,
                    decoration: p.fatto ? TextDecoration.lineThrough : null,
                    decorationColor: golfo,
                  ),
                ),
                if (prossimo) ...[
                  const SizedBox(height: 3),
                  Text(p.testo, style: const TextStyle(color: testo2, fontSize: 13, height: 1.35)),
                  const SizedBox(height: 8),
                  ?tasto,
                ],
              ],
            ),
          ),
          if (!prossimo && tasto != null) ...[const SizedBox(width: 6), tasto],
        ],
      ),
    );
  }
}
