// Testo dei post e dei commenti come sul sito: **grassetto**, {oro}colori{/}, @menzioni toccabili, link toccabili.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dati/stato.dart';
import '../tema.dart';

const gruppiMenzione = {'tribu', 'follower', 'followers', 'primopiano'};

class TestoRicco extends StatefulWidget {
  const TestoRicco(this.testo, {super.key, this.stile, this.maxRighe});

  final String testo;
  final TextStyle? stile;
  final int? maxRighe;

  @override
  State<TestoRicco> createState() => _TestoRiccoState();
}

class _TestoRiccoState extends State<TestoRicco> {
  final _tocchi = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final t in _tocchi) {
      t.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _tocco(VoidCallback f) {
    final t = TapGestureRecognizer()..onTap = f;
    _tocchi.add(t);
    return t;
  }

  @override
  Widget build(BuildContext context) {
    for (final t in _tocchi) {
      t.dispose();
    }
    _tocchi.clear();
    final base = widget.stile ?? const TextStyle(fontSize: 15.5, height: 1.45, color: testo);
    return Text.rich(
      TextSpan(style: base, children: _pezzi(widget.testo, base)),
      maxLines: widget.maxRighe,
      overflow: widget.maxRighe == null ? null : TextOverflow.ellipsis,
    );
  }

  /// Prima formattazione (grassetto e colori), poi in ogni pezzo link e menzioni.
  List<InlineSpan> _pezzi(String t, TextStyle base) {
    final out = <InlineSpan>[];
    final rx = RegExp(r'\*\*(?=\S)([^\n]*?\S)\*\*|\{(' + coloriTesto.keys.join('|') + r')\}([\s\S]+?)\{/\}');
    var pos = 0;
    for (final m in rx.allMatches(t)) {
      if (m.start > pos) out.addAll(_link(t.substring(pos, m.start), base));
      if (m.group(1) != null) {
        out.addAll(_link(m.group(1)!, base.copyWith(fontWeight: FontWeight.w800)));
      } else {
        out.addAll(_link(m.group(3)!, base.copyWith(color: coloriTesto[m.group(2)], fontWeight: FontWeight.w600)));
      }
      pos = m.end;
    }
    if (pos < t.length) out.addAll(_link(t.substring(pos), base));
    return out;
  }

  List<InlineSpan> _link(String t, TextStyle s) {
    final out = <InlineSpan>[];
    final rx = RegExp(r'''https?://[^\s<>"']+|(?<=^|[\s(])@([A-Za-z0-9_.]{3,32})''');
    var pos = 0;
    for (final m in rx.allMatches(t)) {
      if (m.start > pos) out.add(TextSpan(text: t.substring(pos, m.start), style: s));
      final pezzo = m.group(0)!;
      if (pezzo.startsWith('@')) {
        final u = m.group(1)!;
        if (gruppiMenzione.contains(u.toLowerCase())) {
          out.add(
            TextSpan(
              text: pezzo,
              style: s.copyWith(color: oro, fontWeight: FontWeight.w700),
            ),
          );
        } else {
          out.add(
            TextSpan(
              text: pezzo,
              style: s.copyWith(color: golfo, fontWeight: FontWeight.w700),
              recognizer: _tocco(() => stato.apri({'tipo': 'utente', 'username': u})),
            ),
          );
        }
      } else {
        var url = pezzo;
        var resto = '';
        while (url.isNotEmpty && '.,;:!?)'.contains(url[url.length - 1])) {
          resto = url[url.length - 1] + resto;
          url = url.substring(0, url.length - 1);
        }
        var vista = url.replaceFirst(RegExp(r'^https?://(www\.)?'), '');
        if (vista.length > 42) vista = '${vista.substring(0, 41)}…';
        out.add(
          TextSpan(
            text: vista,
            style: s.copyWith(color: golfo, decoration: TextDecoration.underline, decorationColor: golfo.withValues(alpha: .5)),
            recognizer: _tocco(() => _apri(url)),
          ),
        );
        if (resto.isNotEmpty) out.add(TextSpan(text: resto, style: s));
      }
      pos = m.end;
    }
    if (pos < t.length) out.add(TextSpan(text: t.substring(pos), style: s));
    return out;
  }

  void _apri(String url) {
    final d = destinazioneDaLink(url);
    if (d != null) {
      stato.apri(d);
    } else {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}

/// Lo stesso testo senza segni di formattazione (anteprime, notifiche).
String senzaFormato(String t) => t
    .replaceAllMapped(RegExp(r'\*\*(?=\S)([^\n]*?\S)\*\*'), (m) => m.group(1)!)
    .replaceAllMapped(RegExp(r'\{(' + coloriTesto.keys.join('|') + r')\}([\s\S]+?)\{/\}'), (m) => m.group(2)!);
