// La pagina di un quartiere (una tribù): copertina, stemma, numeri, casa/segui, residenti da garantire, regole, bacheca.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/faccia.dart';
import '../widget/lista_post.dart';
import '../widget/tamtam.dart';
import 'moderazione.dart';
import 'naviga.dart';

class SchermataQuartiere extends StatefulWidget {
  const SchermataQuartiere({super.key, required this.slug, this.apriResidenti = false});

  final String slug;

  /// Dalla notifica «chiede di essere garantito» o da «Da fare»: appena caricato si aprono i residenti.
  final bool apriResidenti;

  @override
  State<SchermataQuartiere> createState() => _SchermataQuartiereState();
}

class _SchermataQuartiereState extends State<SchermataQuartiere> {
  Map<String, dynamic>? _q;
  final _lista = GlobalKey<ListaPostState>();

  Future<(List<Post>, bool)> _carica(int prima) async {
    final j = await stato.api.quartiere(widget.slug, prima: prima);
    if (prima == 0 && mounted) {
      final primaVolta = _q == null;
      setState(() => _q = j['quartiere'] as Map<String, dynamic>);
      if (primaVolta && widget.apriResidenti) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _apriResidenti(_q!); });
    }
    return ((j['post'] as List).map((p) => Post(p as Map<String, dynamic>)).toList(), j['altri'] == true);
  }

  Future<void> _casa() async {
    final q = _q!;
    if (!await conferma(
      context,
      'Abiti a ${q['nome']}?',
      'Diventa la tua tribù: lì potrai scrivere quando ${stato.io?.viciniGaranti ?? 'i vicini'} già confermati garantiranno per te. Il quartiere di casa si cambia al massimo una volta al mese.',
      si: 'Sì, abito qui',
      pericolo: false,
    )) {
      return;
    }
    try {
      final j = await stato.api.scegliCasa((q['id'] as num).toInt());
      if (!mounted) return;
      if (j['io'] != null) stato.entra(Io(j['io'] as Map<String, dynamic>));
      messaggio(context, '${j['msg']}');
      mappaInMemoria(ricarica: true).ignore();
      _lista.currentState?.aggiorna();
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    }
  }

  Future<void> _segui() async {
    try {
      final j = await stato.api.seguiQuartiere((_q!['id'] as num).toInt());
      if (!mounted) return;
      setState(() => _q!['segui'] = j['segui'] == true);
      messaggio(context, '${j['msg']}');
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    return Scaffold(
      appBar: AppBar(title: Text(q == null ? '' : '${q['nome']}')),
      body: ListaPost(
        key: _lista,
        carica: _carica,
        testa: q == null ? null : _testa(q),
        vuoto: Vuoto(
          icona: Icons.forum_outlined,
          testo: q?['residente'] == true
              ? 'La bacheca è vuota: scrivi il primo post della tribù!'
              : 'La bacheca di questa tribù è ancora vuota.',
        ),
      ),
    );
  }

  Widget _testa(Map<String, dynamic> q) {
    final col = colore('${q['colore']}');
    final stats = (q['stats'] as Map?) ?? const {};
    final casa = q['casa'] == true;
    final copertina = img(q['copertina'] as String?);
    final mod = (q['moderatori'] as List? ?? []).map((m) => Faccia(m as Map<String, dynamic>)).toList();
    final facce = (q['facce'] as List? ?? []).map((m) => Faccia(m as Map<String, dynamic>)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 170,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (copertina != null)
                CachedNetworkImage(imageUrl: copertina, fit: BoxFit.cover)
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [col.withValues(alpha: .7), vernice],
                    ),
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, vernice]),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (assoluto(q['stemma'] as String?) != null)
                      SvgPicture.network(
                        assoluto(q['stemma'] as String?)!,
                        height: 84,
                        width: 70,
                        placeholderBuilder: (_) => const SizedBox(height: 84, width: 70),
                        errorBuilder: (_, _, _) => const SizedBox(height: 84, width: 70),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${q['nome']}', style: titolo(26)),
                          Text(
                            q['citta'] == 'Napoli' ? '${q['municipalita']} · Napoli' : '${q['citta']}',
                            style: const TextStyle(color: testo2, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(
            children: [
              _numero('${stats['residenti'] ?? 0}', 'residenti'),
              _numero('${stats['attesa'] ?? 0}', 'in attesa'),
              _numero('${stats['post'] ?? 0}', 'post'),
              _numero('${stats['seguaci'] ?? 0}', 'seguono'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(
            children: [
              if (!casa)
                Expanded(
                  child: BottoneCaldo(testo: 'Abito qui', icona: Icons.home_outlined, onPressed: _casa),
                )
              else
                Expanded(
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: terracotta.withValues(alpha: .16), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      q['residente'] == true ? 'La tua tribù' : 'Casa · residenza in attesa',
                      style: const TextStyle(color: terracotta, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              if (!casa)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _segui,
                    icon: Icon(q['segui'] == true ? Icons.check : Icons.add, size: 19),
                    label: Text(q['segui'] == true ? 'Segui già' : 'Segui'),
                  ),
                ),
              if (casa)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _apriResidenti(q),
                    icon: const Icon(Icons.groups_outlined, size: 19),
                    label: _conPallino('Residenti', _daFare(q, 'garantire')),
                  ),
                ),
            ],
          ),
        ),
        if (!casa)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: TextButton.icon(
              onPressed: () => _apriResidenti(q),
              icon: const Icon(Icons.groups_outlined, size: 18),
              label: const Text('Vedi i residenti'),
            ),
          ),
        if (facce.isNotEmpty || mod.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Carta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mod.isNotEmpty) ...[
                    const Text(
                      'MODERATORI ELETTI',
                      style: TextStyle(color: muto, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .6),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        for (final m in mod)
                          GestureDetector(
                            onTap: () => apriUtente(context, m.username),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FotoProfilo(faccia: m, lato: 26),
                                const SizedBox(width: 6),
                                Text(m.nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (facce.isNotEmpty) ...[
                    const Text(
                      'ALCUNI VICINI',
                      style: TextStyle(color: muto, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .6),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 36,
                      child: Stack(
                        children: [
                          for (var i = 0; i < facce.length; i++)
                            Positioned(
                              left: i * 26.0,
                              child: GestureDetector(
                                onTap: () => apriUtente(context, facce[i].username),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: superficie, shape: BoxShape.circle),
                                  child: FotoProfilo(faccia: facce[i], lato: 30),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if ((q['regole'] as String?)?.trim().isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Carta(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                shape: const Border(),
                leading: const Icon(Icons.gavel_rounded, color: oro),
                title: const Text('Regole della tribù', style: TextStyle(fontWeight: FontWeight.w700)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  Text('${q['regole']}', style: const TextStyle(color: testo2, height: 1.45)),
                  if (q['regole_base'] == true) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Sono le regole di base di triburba, uguali per tutte le tribù: i moderatori possono aggiungere o togliere quello che serve al quartiere.',
                      style: TextStyle(color: muto, fontSize: 12.5, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ),
        // moderatori, candidature e voto per tutti; proposte, post nascosti e regole per chi può deciderli
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SchermataModerazione(slug: '${q['slug']}')));
              _lista.currentState?.aggiorna();
            },
            icon: Icon(q['puo_moderare'] == true ? Icons.shield_outlined : Icons.how_to_vote_outlined, size: 18),
            label: _conPallino(
              q['puo_moderare'] == true ? 'Moderazione' : (q['residente'] == true ? 'Moderatori e voto' : 'Moderatori'),
              _cosaModerazione(q),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Text(
            'BACHECA',
            style: TextStyle(color: muto, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6),
          ),
        ),
      ],
    );
  }

  Widget _numero(String n, String t) => Expanded(
    child: Column(
      children: [
        Text(n, style: titolo(21)),
        Text(t, style: const TextStyle(color: muto, fontSize: 12)),
      ],
    ),
  );

  int _daFare(Map<String, dynamic> q, String k) => ((q['da_fare'] as Map?)?[k] as num?)?.toInt() ?? 0;

  /// Pallino sul tasto Moderazione: «Vota» se non ho votato, oppure quante cose aspettano una decisione.
  String _cosaModerazione(Map<String, dynamic> q) {
    final df = (q['da_fare'] as Map?) ?? const {};
    if (df['residente'] == true && df['votato'] == false) return 'Vota';
    final n = _daFare(q, 'proposte') + _daFare(q, 'segnalati');
    return n > 0 ? '$n' : '';
  }

  Widget _conPallino(String testo, Object pallino) {
    final p = '$pallino';
    if (p.isEmpty || p == '0') return Text(testo);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(testo, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(gradient: gradiente, borderRadius: BorderRadius.circular(99)),
          child: Text(p, style: const TextStyle(color: bianco, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  void _apriResidenti(Map<String, dynamic> q) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SchermataResidenti(slug: widget.slug, quartiereId: (q['id'] as num).toInt(), nome: '${q['nome']}'),
    ),
  );
}

/// Residenti confermati e vicini in attesa: i confermati garantiscono, moderatori e admin confermano direttamente.
class SchermataResidenti extends StatefulWidget {
  const SchermataResidenti({super.key, required this.slug, required this.quartiereId, required this.nome});

  final String slug, nome;
  final int quartiereId;

  @override
  State<SchermataResidenti> createState() => _SchermataResidentiState();
}

class _SchermataResidentiState extends State<SchermataResidenti> {
  Map<String, dynamic>? _r;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    try {
      final r = await stato.api.residenti(widget.slug);
      if (mounted) {
        setState(() {
          _r = r;
          _errore = null;
        });
      }
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  Future<void> _garantisci(Map<String, dynamic> u, {bool diretta = false}) async {
    final nome = '${u['nome']}';
    if (!await conferma(
      context,
      diretta ? 'Confermi $nome?' : 'Garantisci per $nome?',
      diretta
          ? 'Diventa subito residente confermato di ${widget.nome}.'
          : 'Garantisci che $nome abita davvero a ${widget.nome}. Fallo solo se lo conosci.',
      si: diretta ? 'Conferma' : 'Garantisco',
      pericolo: false,
    )) {
      return;
    }
    try {
      final j = await stato.api.garantisci(widget.quartiereId, (u['id'] as num).toInt(), conferma: diretta);
      if (!mounted) return;
      messaggio(context, '${j['msg']}');
      _carica();
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final conf = (r?['confermati'] as List? ?? []).cast<Map<String, dynamic>>();
    final att = (r?['attesa'] as List? ?? []).cast<Map<String, dynamic>>();
    final min = r?['garanzie_min'] ?? 2;
    return Scaffold(
      appBar: AppBar(title: Text('Residenti di ${widget.nome}')),
      body: r == null
          ? Center(child: _errore == null ? const CircularProgressIndicator() : Text(_errore!))
          : RefreshIndicator(
              onRefresh: _carica,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 30),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: Text(
                      'Chi arriva resta «in attesa» finché $min vicini già confermati non garantiscono per lui: così la tribù è fatta di vicini veri.',
                      style: const TextStyle(color: testo2, fontSize: 13, height: 1.4),
                    ),
                  ),
                  if (att.isNotEmpty) _sezione('In attesa (${att.length})'),
                  for (final u in att)
                    ListTile(
                      leading: FotoProfilo(faccia: Faccia(u), lato: 42),
                      title: Text('${u['nome']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${u['garanzie']}/$min garanzie', style: const TextStyle(color: muto)),
                      onTap: () => apriUtente(context, '${u['username']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (r['puo_garantire'] == true)
                            u['garantito_da_me'] == true
                                ? const Chip2(testo: 'Garantito', icona: Icons.check, colore: golfo)
                                : FilledButton(
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 36),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    onPressed: () => _garantisci(u),
                                    child: const Text('Garantisci'),
                                  ),
                          if (r['puo_confermare'] == true)
                            IconButton(
                              tooltip: 'Conferma direttamente',
                              onPressed: () => _garantisci(u, diretta: true),
                              icon: const Icon(Icons.verified_outlined, color: oro),
                            ),
                        ],
                      ),
                    ),
                  _sezione('Confermati (${conf.length})'),
                  for (final u in conf)
                    ListTile(
                      leading: FotoProfilo(faccia: Faccia(u), lato: 42),
                      title: Text('${u['nome']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('@${u['username']}', style: const TextStyle(color: muto)),
                      onTap: () => apriUtente(context, '${u['username']}'),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _sezione(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      t.toUpperCase(),
      style: const TextStyle(color: muto, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6),
    ),
  );
}
