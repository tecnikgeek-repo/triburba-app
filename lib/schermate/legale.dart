// Regolamento, Termini, Privacy e Cookie letti dentro l'app (mai nel browser).
// Il testo arriva dal server in HTML semplice (titoli, paragrafi, elenchi, tabelle, link) e qui diventa widget.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dati/api.dart';
import '../dati/stato.dart';
import '../tema.dart';

const pagineLegali = {'regolamento': 'Regolamento', 'termini': 'Termini', 'privacy': 'Privacy', 'cookie': 'Cookie'};

Future<void> apriLegale(BuildContext context, String pagina) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SchermataLegale(pagina: pagina)));

class SchermataLegale extends StatefulWidget {
  const SchermataLegale({super.key, required this.pagina, this.iniziali});

  final String pagina;

  /// Solo per le anteprime: {titolo, aggiornato, html}.
  final Map<String, dynamic>? iniziali;

  @override
  State<SchermataLegale> createState() => _SchermataLegaleState();
}

class _SchermataLegaleState extends State<SchermataLegale> {
  Map<String, dynamic>? _d;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _d = widget.iniziali;
    if (_d == null) _carica();
  }

  Future<void> _carica() async {
    setState(() => _errore = null);
    try {
      final j = await stato.api.legale(widget.pagina);
      if (mounted) setState(() => _d = j);
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: Text(pagineLegali[widget.pagina] ?? 'triburba')),
      body: d == null
          ? Center(
              child: _errore == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errore!, textAlign: TextAlign.center, style: const TextStyle(color: muto)),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _carica, child: const Text('Riprova')),
                        ],
                      ),
                    ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
              children: [
                Text('${d['titolo']}', style: titolo(26)),
                const SizedBox(height: 6),
                Text('Ultimo aggiornamento: ${d['aggiornato']}', style: const TextStyle(color: muto, fontSize: 13)),
                const SizedBox(height: 12),
                ...TestoHtml.blocchi(context, '${d['html']}'),
              ],
            ),
    );
  }
}

/// HTML semplice → widget: h2/h3, p, ul/ol, table (a schede), con b/strong, i/em, code, a, br dentro il testo.
class TestoHtml {
  static String _pulisci(String s) => s
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _entita(String s) => s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&laquo;', '«')
      .replaceAll('&raquo;', '»')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&rsquo;', '’')
      .replaceAll('&egrave;', 'è')
      .replaceAll('&agrave;', 'à')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');

  static List<Widget> blocchi(BuildContext context, String html) {
    final out = <Widget>[];
    final h = _pulisci(html);
    final re = RegExp(r'<(h2|h3|p|ul|ol|table)\b[^>]*>(.*?)</\1>', dotAll: true, caseSensitive: false);
    for (final m in re.allMatches(h)) {
      final tag = m.group(1)!.toLowerCase();
      final dentro = m.group(2)!;
      switch (tag) {
        case 'h2':
          out.add(Padding(padding: const EdgeInsets.only(top: 18, bottom: 6), child: Text(_entita(_soloTesto(dentro)), style: titolo(19))));
        case 'h3':
          out.add(Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Text(_entita(_soloTesto(dentro)), style: titolo(16))));
        case 'p':
          if (_soloTesto(dentro).isEmpty) break;
          out.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: _ricco(context, dentro)));
        case 'ul':
        case 'ol':
          var n = 0;
          for (final li in RegExp(r'<li\b[^>]*>(.*?)</li>', dotAll: true).allMatches(dentro)) {
            n++;
            out.add(Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 20, child: Text(tag == 'ol' ? '$n.' : '•', style: const TextStyle(color: terracotta, fontWeight: FontWeight.w800, height: 1.5))),
                  Expanded(child: _ricco(context, li.group(1)!)),
                ],
              ),
            ));
          }
          out.add(const SizedBox(height: 6));
        case 'table':
          out.addAll(_tabella(context, dentro));
      }
    }
    return out;
  }

  /// Tabella a schede: ogni riga è una scheda con «intestazione: valore».
  static List<Widget> _tabella(BuildContext context, String t) {
    final testate = [for (final th in RegExp(r'<th\b[^>]*>(.*?)</th>', dotAll: true).allMatches(t)) _entita(_soloTesto(th.group(1)!))];
    final corpo = RegExp(r'<tbody\b[^>]*>(.*?)</tbody>', dotAll: true).firstMatch(t)?.group(1) ?? t;
    final schede = <Widget>[];
    for (final tr in RegExp(r'<tr\b[^>]*>(.*?)</tr>', dotAll: true).allMatches(corpo)) {
      final celle = [for (final td in RegExp(r'<td\b([^>]*)>(.*?)</td>', dotAll: true).allMatches(tr.group(1)!)) td];
      if (celle.isEmpty) continue;
      schede.add(Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: superficie, borderRadius: BorderRadius.circular(10), border: Border.all(color: linea)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < celle.length; i++) ...[
              Text(
                _etichetta(celle[i].group(1)!) ?? (i < testate.length ? testate[i] : ''),
                style: const TextStyle(color: oro, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .4),
              ),
              const SizedBox(height: 2),
              _ricco(context, celle[i].group(2)!),
              if (i < celle.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ));
    }
    return [...schede, const SizedBox(height: 6)];
  }

  static String? _etichetta(String attr) {
    final m = RegExp(r'data-label="([^"]*)"').firstMatch(attr);
    return m == null ? null : _entita(m.group(1)!).toUpperCase();
  }

  static String _soloTesto(String s) => s.replaceAll(RegExp(r'<br\s*/?>'), '\n').replaceAll(RegExp(r'<[^>]+>'), '').trim();

  /// Testo con grassetto, corsivo, codice e link toccabili.
  static Widget _ricco(BuildContext context, String s) {
    final spans = <InlineSpan>[];
    var grassetto = 0, corsivo = 0, codice = 0;
    String? link;
    final re = RegExp(r'<(/?)(b|strong|i|em|code|a|br)\b([^>]*)>|([^<]+)|<[^>]*>', caseSensitive: false);
    for (final m in re.allMatches(s)) {
      final testo = m.group(4);
      if (testo != null) {
        final href = link;
        spans.add(TextSpan(
          text: _entita(testo),
          style: TextStyle(
            fontWeight: grassetto > 0 ? FontWeight.w700 : null,
            fontStyle: corsivo > 0 ? FontStyle.italic : null,
            color: href != null ? golfo : (codice > 0 ? oro : null),
            decoration: href != null ? TextDecoration.underline : null,
          ),
          recognizer: href == null ? null : (TapGestureRecognizer()..onTap = () => _apri(context, href)),
        ));
        continue;
      }
      final chiude = m.group(1) == '/';
      final tag = (m.group(2) ?? '').toLowerCase();
      final d = chiude ? -1 : 1;
      switch (tag) {
        case 'b':
        case 'strong':
          grassetto += d;
        case 'i':
        case 'em':
          corsivo += d;
        case 'code':
          codice += d;
        case 'br':
          spans.add(const TextSpan(text: '\n'));
        case 'a':
          link = chiude ? null : RegExp(r'href="([^"]*)"').firstMatch(m.group(3) ?? '')?.group(1);
      }
    }
    return Text.rich(TextSpan(children: spans), style: const TextStyle(color: testo, fontSize: 15, height: 1.5));
  }

  /// Link: le altre pagine legali si aprono nell'app, email e siti esterni con l'app giusta.
  static void _apri(BuildContext context, String href) {
    final interno = RegExp(r'^/(regolamento|termini|privacy|cookie)\b').firstMatch(href);
    if (interno != null) {
      apriLegale(context, interno.group(1)!);
      return;
    }
    final u = href.startsWith('/') ? Uri.parse('$sito$href') : Uri.tryParse(href);
    if (u != null) launchUrl(u, mode: LaunchMode.externalApplication);
  }
}
