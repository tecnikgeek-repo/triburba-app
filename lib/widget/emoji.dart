// Le 6 reazioni di triburba con le emoji animate Noto (le stesse del sito, ospitate nell'app).
import 'package:flutter/material.dart';

import '../tema.dart';

const reazioniOrdine = ['cuore', 'ridere', 'wow', 'triste', 'rabbia', 'applauso'];

const nomiReazioni = {
  'cuore': 'Mi piace',
  'ridere': 'Che ridere',
  'wow': 'Wow',
  'triste': 'Che tristezza',
  'rabbia': 'Che rabbia',
  'applauso': 'Bravi!',
};

/// Emoji di una reazione: animata (webp) o ferma (png, per le liste lunghe).
class Emoji extends StatelessWidget {
  const Emoji(this.nome, {super.key, this.lato = 22, this.animata = false});

  final String nome;
  final double lato;
  final bool animata;

  @override
  Widget build(BuildContext context) {
    final n = reazioniOrdine.contains(nome) ? nome : 'cuore';
    return Image.asset(
      'assets/emoji/$n.${animata ? 'webp' : 'png'}',
      width: lato,
      height: lato,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
  }
}

/// Le emoji più usate, una sopra l'altra come sul sito.
class PilaEmoji extends StatelessWidget {
  const PilaEmoji(this.top, {super.key, this.lato = 18});

  final List<String> top;
  final double lato;

  @override
  Widget build(BuildContext context) {
    if (top.isEmpty) return const SizedBox.shrink();
    final n = top.take(3).toList();
    return SizedBox(
      width: lato + (n.length - 1) * lato * .62,
      height: lato,
      child: Stack(
        children: [
          for (var i = n.length - 1; i >= 0; i--)
            Positioned(
              left: i * lato * .62,
              child: Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: superficie),
                child: Emoji(n[i], lato: lato),
              ),
            ),
        ],
      ),
    );
  }
}

/// Barra a comparsa con le 6 reazioni animate (tenendo premuto «Mi piace»). Ritorna la scelta.
Future<String?> scegliReazione(BuildContext context, {String? attuale}) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: false,
  backgroundColor: Colors.transparent,
  builder: (c) => SafeArea(
    child: Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: superficie2,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: linea2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final r in reazioniOrdine)
            Tooltip(
              message: nomiReazioni[r]!,
              child: InkResponse(
                onTap: () => Navigator.pop(c, r),
                radius: 30,
                child: AnimatedScale(
                  scale: r == attuale ? 1.2 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Emoji(r, lato: 44, animata: true),
                ),
              ),
            ),
        ],
      ),
    ),
  ),
);

/// Emoji grande che esplode al centro dello schermo (come sul telefono nel sito).
void esplodiEmoji(BuildContext context, String nome) {
  final ov = Overlay.of(context);
  late OverlayEntry e;
  e = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOut,
          onEnd: () => e.remove(),
          builder: (_, t, child) {
            final scala = t < .35 ? Curves.elasticOut.transform(t / .35) * 1.15 : 1.15 - (t - .35) * .2;
            return Opacity(
              opacity: t < .75 ? 1 : (1 - (t - .75) / .25).clamp(0, 1),
              child: Transform.scale(scale: scala, child: child),
            );
          },
          child: Emoji(nome, lato: 150, animata: true),
        ),
      ),
    ),
  );
  ov.insert(e);
}
