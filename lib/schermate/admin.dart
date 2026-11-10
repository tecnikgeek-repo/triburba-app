// Pannello admin dentro l'app (solo staff), con gli stessi contenuti del pannello del sito:
// Gestione · Statistiche · Iscritti · Visite · Registro, più l'elenco dei commenti.
// Le azioni passano dagli endpoint /app/v1/admin/…, che usano le stesse regole del sito.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/faccia.dart';
import '../widget/grafici.dart';
import 'naviga.dart';

// ───────────────────────── aiuti ─────────────────────────

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String _s(Object? v) => v == null ? '' : '$v';

/// «2026-11-10 10:31:00» → «10/11 10:31»
String quandoAdmin(Object? v) {
  final d = DateTime.tryParse(_s(v));
  if (d == null) return _s(v);
  String due(int n) => n.toString().padLeft(2, '0');
  final oggi = DateTime.now();
  final anno = d.year == oggi.year ? '' : '/${d.year}';
  return '${d.day}/${d.month}$anno ${due(d.hour)}:${due(d.minute)}';
}

String _accorcia(String t, int n) {
  final s = t.replaceAll(RegExp(r'\*\*|\{[a-z]+\}|\{/\}'), '').replaceAll('\n', ' ').trim();
  return s.length <= n ? s : '${s.substring(0, n).trimRight()}…';
}

/// Esegue un'azione dell'admin: messaggio del server e poi ricarica.
Future<void> _azione(BuildContext context, Future<Map<String, dynamic>> Function() f, Future<void> Function() ricarica) async {
  try {
    final j = await f();
    if (context.mounted && _s(j['msg']).isNotEmpty) messaggio(context, _s(j['msg']));
    await ricarica();
  } on ErroreApi catch (e) {
    if (context.mounted) messaggio(context, e.messaggio);
  }
}

/// Riquadro con un numero, come sul sito (il primo arancio a tutta riga va in fondo).
class _Numero extends StatelessWidget {
  const _Numero({required this.icona, required this.n, required this.testo, this.caldo = false, this.onTap});

  final IconData icona;
  final Object n;
  final String testo;
  final bool caldo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          gradient: caldo ? gradiente : null,
          color: caldo ? null : superficie,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: caldo ? Colors.transparent : linea),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icona, size: 21, color: caldo ? bianco : terracotta),
            const SizedBox(height: 6),
            Text('$n', style: titolo(26, colore: bianco)),
            const SizedBox(height: 2),
            Row(
              children: [
                Flexible(
                  child: Text(testo, style: TextStyle(color: caldo ? bianco.withValues(alpha: .9) : testo2, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
                if (onTap != null) ...[const SizedBox(width: 4), Icon(Icons.arrow_forward_rounded, size: 13, color: caldo ? bianco : terracotta)],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Griglia di riquadri: due per riga, l'arancio (caldo) in fondo a tutta riga.
class _Numeri extends StatelessWidget {
  const _Numeri(this.voci);

  final List<_Numero> voci;

  @override
  Widget build(BuildContext context) {
    final normali = voci.where((v) => !v.caldo).toList();
    final caldi = voci.where((v) => v.caldo).toList();
    return Column(
      children: [
        for (var i = 0; i < normali.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: normali[i]),
                  const SizedBox(width: 10),
                  Expanded(child: i + 1 < normali.length ? normali[i + 1] : const SizedBox()),
                ],
              ),
            ),
          ),
        for (final c in caldi) Padding(padding: const EdgeInsets.only(bottom: 10), child: SizedBox(width: double.infinity, child: c)),
      ],
    );
  }
}

/// Card con titolo e icona.
class _Sezione extends StatelessWidget {
  const _Sezione({super.key, required this.icona, required this.intestazione, this.spiega, required this.figli, this.coda});

  final IconData icona;
  final String intestazione;
  final String? spiega;
  final List<Widget> figli;
  final Widget? coda;

  @override
  Widget build(BuildContext context) => Carta(
    margin: const EdgeInsets.only(bottom: 14),
    // Material trasparente: tocchi e interruttori delle righe si vedono sopra lo sfondo della card
    child: Material(type: MaterialType.transparency, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icona, size: 20, color: terracotta),
            const SizedBox(width: 8),
            Expanded(child: Text(intestazione, style: titolo(16.5))),
            ?coda,
          ],
        ),
        if (spiega != null) ...[const SizedBox(height: 6), Text(spiega!, style: const TextStyle(color: muto, fontSize: 13, height: 1.35))],
        const SizedBox(height: 10),
        ...figli,
      ],
    ),
  ));
}

/// Tasto «Mostra altri» degli elenchi impaginati.
Widget _mostraAltri(int visti, int tot, bool occupato, VoidCallback carica) {
  if (visti >= tot) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Center(
      child: occupato
          ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)))
          : TextButton.icon(onPressed: carica, icon: const Icon(Icons.expand_more_rounded), label: Text('Mostra altri · $visti di $tot')),
    ),
  );
}

/// Scelta del periodo (7 / 30 / 90 giorni, e «Da sempre» se c'è).
class _Periodi extends StatelessWidget {
  const _Periodi({required this.scelto, required this.voci, required this.onScelta});

  final int scelto;
  final Map<int, String> voci;
  final ValueChanged<int> onScelta;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: SegmentedButton<int>(
      segments: [for (final e in voci.entries) ButtonSegment(value: e.key, label: Text(e.value, maxLines: 1, softWrap: false))],
      selected: {scelto},
      showSelectedIcon: false,
      style: ButtonStyle(
        textStyle: WidgetStateProperty.all(const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600)),
        visualDensity: VisualDensity.compact,
      ),
      onSelectionChanged: (s) => onScelta(s.first),
    ),
  );
}

/// Contenitore che carica i dati e mostra rotella o errore.
class _Carica extends StatelessWidget {
  const _Carica({required this.errore, required this.pronto, required this.figlio, required this.ricarica});

  final String? errore;
  final bool pronto;
  final Widget Function() figlio;
  final Future<void> Function() ricarica;

  @override
  Widget build(BuildContext context) {
    if (!pronto) {
      return Center(
        child: errore == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errore!, textAlign: TextAlign.center, style: const TextStyle(color: muto)),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: ricarica, child: const Text('Riprova')),
                  ],
                ),
              ),
      );
    }
    return RefreshIndicator(onRefresh: ricarica, child: figlio());
  }
}

// ───────────────────────── schermata ─────────────────────────

class SchermataAdmin extends StatelessWidget {
  const SchermataAdmin({super.key, this.iniziali, this.scheda = 0});

  /// Solo per le anteprime: dati già pronti per scheda ('gestione', 'statistiche', 'iscritti', 'visite', 'registro').
  final Map<String, Map<String, dynamic>>? iniziali;
  final int scheda;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 5,
    initialIndex: scheda,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Pannello admin'),
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 14.5),
          tabs: [Tab(text: 'Gestione'), Tab(text: 'Statistiche'), Tab(text: 'Iscritti'), Tab(text: 'Visite'), Tab(text: 'Registro')],
        ),
      ),
      body: TabBarView(
        children: [
          _Gestione(iniziali: iniziali?['gestione']),
          _Statistiche(iniziali: iniziali?['statistiche']),
          _Iscritti(iniziali: iniziali?['iscritti']),
          _Visite(iniziali: iniziali?['visite']),
          _Registro(iniziali: iniziali?['registro']),
        ],
      ),
    ),
  );
}

// ───────────────────────── Gestione ─────────────────────────

class _Gestione extends StatefulWidget {
  const _Gestione({this.iniziali});

  final Map<String, dynamic>? iniziali;

  @override
  State<_Gestione> createState() => _GestioneState();
}

class _GestioneState extends State<_Gestione> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _d;
  String? _errore;
  bool _post7 = false;
  List<dynamic> _utenti = [], _post = [];
  int _pu = 1, _pp = 1;
  bool _altriU = false, _altriP = false;
  final _cercaComune = TextEditingController();
  final _soglie = <String, TextEditingController>{};
  final _pub = <String, String>{};
  final _pubNum = <String, TextEditingController>{};
  final _kPost = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.iniziali != null) {
      _usa(widget.iniziali!);
    } else {
      _carica();
    }
  }

  @override
  void dispose() {
    _cercaComune.dispose();
    for (final c in [..._soglie.values, ..._pubNum.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _usa(Map<String, dynamic> j) {
    _d = j;
    _utenti = List.of(j['utenti'] as List);
    _post = List.of(j['post'] as List);
    _pu = 1;
    _pp = 1;
    for (final s in j['soglie'] as List) {
      (_soglie[_s(s['chiave'])] ??= TextEditingController()).text = '${s['valore']}';
    }
    for (final p in j['pubblicazione'] as List) {
      final k = _s(p['chiave']);
      if (p['scelte'] == null) {
        (_pubNum[k] ??= TextEditingController()).text = _s(p['valore']);
      } else {
        _pub[k] = _s(p['valore']);
      }
    }
  }

  Future<void> _carica() async {
    try {
      final j = await stato.api.adminGestione(post7: _post7);
      if (mounted) setState(() => _usa(j));
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  Future<void> _altriUtenti() async {
    setState(() => _altriU = true);
    try {
      final j = await stato.api.adminGestione(pu: _pu + 1, post7: _post7);
      if (mounted) {
        setState(() {
        _pu++;
        _utenti.addAll(j['utenti'] as List);
        });
      }
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _altriU = false);
    }
  }

  Future<void> _altriPost() async {
    setState(() => _altriP = true);
    try {
      final j = await stato.api.adminGestione(pp: _pp + 1, post7: _post7);
      if (mounted) {
        setState(() {
        _pp++;
        _post.addAll(j['post'] as List);
        });
      }
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _altriP = false);
    }
  }

  void _vaiPost({required bool sette}) {
    if (_post7 != sette) {
      setState(() => _post7 = sette);
      _carica().then((_) => _scorriPost());
    } else {
      _scorriPost();
    }
  }

  void _scorriPost() {
    final c = _kPost.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _Carica(errore: _errore, pronto: _d != null, ricarica: _carica, figlio: () => _corpo(_d!));
  }

  Widget _corpo(Map<String, dynamic> d) {
    final st = d['stats'] as Map;
    final superadmin = (d['io'] as Map)['superadmin'] == true;
    final schede = DefaultTabController.maybeOf(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        _Numeri([
          _Numero(icona: Icons.group_outlined, n: _i(st['users']), testo: 'Iscritti', onTap: () => schede?.animateTo(2)),
          _Numero(icona: Icons.chat_bubble_outline, n: _i(st['posts']), testo: 'Post', onTap: () => _vaiPost(sette: false)),
          _Numero(
            icona: Icons.mode_comment_outlined,
            n: _i(st['comments']),
            testo: 'Commenti',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SchermataAdminCommenti())),
          ),
          _Numero(icona: Icons.favorite_border, n: _i(st['likes']), testo: 'Reazioni', onTap: () => schede?.animateTo(1)),
          _Numero(icona: Icons.auto_awesome_outlined, n: _i(st['week']), testo: 'Post in 7 giorni', caldo: true, onTap: () => _vaiPost(sette: true)),
        ]),
        _immagini(d),
        _attesa(d),
        _nascosti(d),
        _telefoni(d),
        _zoneNapoli(d),
        _comuni(d),
        _pubblicazione(d),
        _soglieCarta(d),
        _utentiCarta(d, superadmin),
        _postCarta(d),
      ],
    );
  }

  Widget _immagini(Map<String, dynamic> d) {
    final l = d['immagini'] as List;
    return _Sezione(
      icona: Icons.image_outlined,
      intestazione: 'Immagini da rivedere',
      spiega: 'Foto sfocate dal controllo automatico o segnalate come contenuto sessuale o violento. Le vedi solo tu, in chiaro.',
      figli: [
        if (l.isEmpty) const Text('Nessuna immagine in attesa.', style: TextStyle(color: muto)),
        for (final im in l) _immagine(im as Map),
      ],
    );
  }

  Widget _immagine(Map im) {
    final id = _i(im['id']);
    final url = assoluto(_s(im['image_path']));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (url != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(imageUrl: url, height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: 6),
          Text('@${im['username']} · ${_s(im['q_nome'])} · ${quandoAdmin(im['created_at'])}', style: const TextStyle(color: muto, fontSize: 12.5)),
          if (_s(im['img_motivo']).isNotEmpty) Text(_s(im['img_motivo']), style: const TextStyle(color: oro, fontSize: 12.5)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton(onPressed: () => _azione(context, () => stato.api.adminImmagine(id, 'approva'), _carica), child: const Text('Approva')),
              OutlinedButton(onPressed: () => _azione(context, () => stato.api.adminImmagine(id, 'elimina'), _carica), child: const Text('Elimina')),
              OutlinedButton(onPressed: () => _azione(context, () => stato.api.adminImmagine(id, 'sospendi'), _carica), child: const Text('Elimina e sospendi')),
              TextButton(
                onPressed: () async {
                  if (!await conferma(context, 'Possibile abuso su minori?', 'La foto viene tolta e conservata come prova, l\'autore sospeso. Poi va segnalata alla Polizia Postale.', si: 'Conferma')) return;
                  if (!mounted) return;
                  await _azione(context, () => stato.api.adminImmagine(id, 'minori'), _carica);
                },
                child: const Text('Abuso su minori', style: TextStyle(color: pompeiano)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attesa(Map<String, dynamic> d) {
    final l = d['attesa'] as List;
    return _Sezione(
      icona: Icons.handshake_outlined,
      intestazione: 'Residenti in attesa',
      spiega: 'I primi residenti di ogni quartiere non hanno vicini confermati che possano garantire: confermali tu, se sai che abitano lì.',
      figli: [
        if (l.isEmpty) const Text('Nessuno in attesa.', style: TextStyle(color: muto)),
        for (final u in l)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: FotoProfilo.da(nome: _s(u['display_name']).isEmpty ? _s(u['username']) : _s(u['display_name']), avatar: u['avatar_path'] as String?, lato: 38),
            title: Text(_s(u['display_name']).isEmpty ? '@${u['username']}' : _s(u['display_name']), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${u['quartiere_nome']} · ${_i(u['garanzie'])} garanzie', style: const TextStyle(color: muto)),
            trailing: OutlinedButton(
              onPressed: () => _azione(context, () => stato.api.adminResidente(_i(u['id'])), _carica),
              child: const Text('Conferma'),
            ),
            onTap: () => apriUtente(context, _s(u['username'])),
          ),
      ],
    );
  }

  Widget _nascosti(Map<String, dynamic> d) {
    final l = d['nascosti'] as List;
    return _Sezione(
      icona: Icons.visibility_off_outlined,
      intestazione: 'Post nascosti dalle segnalazioni',
      figli: [
        if (l.isEmpty) const Text('Nessun post nascosto.', style: TextStyle(color: muto)),
        for (final n in l)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => apriPost(context, _i(n['id'])),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${n['username']} · ${_s(n['q_nome'])} · ${_i(n['segnalazioni'])} segnalazioni${_s(n['motivi']).isEmpty ? '' : ': ${n['motivi']}'} · ${_i(n['ovunque']) == 0 ? 'nascosto ovunque' : 'nascosto in un quartiere'}',
                    style: const TextStyle(color: oro, fontSize: 12.5),
                  ),
                  Text(_accorcia(_s(n['content']), 140)),
                ],
              ),
            ),
          ),
        if (l.isNotEmpty) const Text('Per rimetterli visibili o eliminarli apri la Moderazione del quartiere d\'origine.', style: TextStyle(color: muto, fontSize: 12.5)),
      ],
    );
  }

  Widget _telefoni(Map<String, dynamic> d) {
    final t = d['telefoni'] as Map;
    final err = d['push_errori'] as List;
    return _Sezione(
      icona: Icons.notifications_active_outlined,
      intestazione: 'Notifiche sul telefono',
      spiega: d['push_attive'] == true ? null : 'Le notifiche push non sono configurate sul server.',
      figli: [
        Text(
          '${_i(t['push'])} telefoni ricevono le notifiche (${_i(t['android'])} Android, ${_i(t['ios'])} iPhone) su ${_i(t['tot'])} collegati all\'app · ${_i(t['webapp'])} nella webapp',
          style: const TextStyle(height: 1.4),
        ),
        if (err.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Ultimi errori', style: TextStyle(fontWeight: FontWeight.w700)),
          for (final e in err) Text(_s(e is Map ? (e['riga'] ?? e['testo'] ?? e) : e), style: const TextStyle(color: muto, fontSize: 12)),
        ],
      ],
    );
  }

  Future<void> _zona(String tipo, Map z, bool acceso) async {
    final nome = _s(z['nome']);
    final ok = acceso
        ? await conferma(context, 'Accendi $nome?', 'Si accende sulla mappa e triburba lo annuncia a tutti con un post e una notifica (solo la prima volta).', si: 'Accendi', pericolo: false)
        : await conferma(context, 'Spegni $nome?', 'Sparisce da mappa, liste, ricerca e registrazione. I suoi dati restano e tornano quando lo riaccendi.', si: 'Spegni');
    if (!ok || !mounted) return;
    await _azione(context, () => stato.api.adminZona(tipo, _i(z['id']), acceso), _carica);
  }

  Widget _zoneNapoli(Map<String, dynamic> d) {
    final l = d['quartieri'] as List;
    final righe = <Widget>[];
    String? gruppo;
    for (final q in l) {
      if (_s(q['mun_nome']) != gruppo) {
        gruppo = _s(q['mun_nome']);
        righe.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 2),
          child: Text(gruppo.toUpperCase(), style: const TextStyle(color: terracotta, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .6)),
        ));
      }
      righe.add(_interruttore(q as Map, _i(q['attivo']) == 1, (v) => _zona('q', q, v)));
    }
    return _Sezione(
      icona: Icons.map_outlined,
      intestazione: 'Quartieri di Napoli e comuni delle isole',
      spiega: 'Accendi o spegni i singoli quartieri. Uno spento sparisce da mappa, liste, ricerca e registrazione; i suoi dati restano.',
      figli: righe,
    );
  }

  Widget _interruttore(Map z, bool acceso, ValueChanged<bool> cambia) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    value: acceso,
    onChanged: cambia,
    title: Text(_s(z['nome']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
    subtitle: _i(z['iscritti']) > 0 ? Text('${_i(z['iscritti'])} iscritti', style: const TextStyle(color: muto, fontSize: 12)) : null,
  );

  Widget _comuni(Map<String, dynamic> d) {
    final l = (d['comuni'] as List).cast<Map>();
    final f = _cercaComune.text.trim().toLowerCase();
    final accesi = l.where((c) => _i(c['attiva']) == 1).length;
    final vis = f.isEmpty ? l.where((c) => _i(c['attiva']) == 1 || _i(c['iscritti']) > 0).toList() : l.where((c) => _s(c['nome']).toLowerCase().contains(f)).toList();
    return _Sezione(
      icona: Icons.location_city_outlined,
      intestazione: "Comuni dell'area metropolitana",
      spiega: '$accesi accesi su ${l.length}. Cerca un comune per accenderlo o spegnerlo.',
      figli: [
        TextField(
          controller: _cercaComune,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Cerca un comune…', prefixIcon: Icon(Icons.search_rounded)),
        ),
        const SizedBox(height: 4),
        if (vis.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(f.isEmpty ? 'Nessun comune acceso.' : 'Nessun comune con questo nome.', style: const TextStyle(color: muto))),
        for (final c in vis.take(40)) _interruttore(c, _i(c['attiva']) == 1, (v) => _zona('c', c, v)),
      ],
    );
  }

  Widget _pubblicazione(Map<String, dynamic> d) => _Sezione(
    icona: Icons.tune_rounded,
    intestazione: 'Pubblicazione',
    figli: [
      for (final p in d['pubblicazione'] as List) ...[
        Text(_s(p['titolo']), style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(_s(p['spiega']), style: const TextStyle(color: muto, fontSize: 12.5)),
        const SizedBox(height: 6),
        if (p['scelte'] != null)
          DropdownButtonFormField<String>(
            initialValue: _pub[_s(p['chiave'])],
            isExpanded: true,
            items: [for (final s in p['scelte'] as List) DropdownMenuItem(value: _s(s['valore']), child: Text(_s(s['titolo']), overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _pub[_s(p['chiave'])] = v ?? ''),
          )
        else
          TextField(controller: _pubNum[_s(p['chiave'])], keyboardType: TextInputType.number),
        const SizedBox(height: 12),
      ],
      SizedBox(
        width: double.infinity,
        child: BottoneCaldo(
          testo: 'Salva',
          icona: Icons.check_rounded,
          onPressed: () => _azione(context, () => stato.api.adminPubblicazione({..._pub, for (final e in _pubNum.entries) e.key: e.value.text.trim()}), _carica),
        ),
      ),
    ],
  );

  Widget _soglieCarta(Map<String, dynamic> d) {
    final lancio = d['lancio'] as Map;
    final fino = DateTime.tryParse(_s(lancio['fino']));
    const mesi = ['gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'];
    return _Sezione(
      icona: Icons.speed_rounded,
      intestazione: 'Soglie',
      figli: [
        if (fino != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: oro.withValues(alpha: .12), borderRadius: BorderRadius.circular(10), border: Border.all(color: oro.withValues(alpha: .4))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.rocket_launch_outlined, color: oro, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Soglia di lancio: fino al ${fino.day} ${mesi[fino.month - 1]} per aprire un quartiere o un comune bastano ${_soglie['soglia_apertura']?.text ?? '?'} richieste. Il giorno dopo torna da sola a ${_i(lancio['dopo'])}.',
                    style: const TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        for (final s in d['soglie'] as List) ...[
          Text(_s(s['titolo']), style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(_s(s['spiega']), style: const TextStyle(color: muto, fontSize: 12.5)),
          const SizedBox(height: 6),
          TextField(controller: _soglie[_s(s['chiave'])], keyboardType: TextInputType.number),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: BottoneCaldo(
            testo: 'Salva le soglie',
            icona: Icons.check_rounded,
            onPressed: () => _azione(
              context,
              () => stato.api.adminSoglie({for (final e in _soglie.entries) e.key: int.tryParse(e.value.text.trim()) ?? 1}),
              _carica,
            ),
          ),
        ),
      ],
    );
  }

  Widget _utentiCarta(Map<String, dynamic> d, bool superadmin) {
    final mio = _i((d['io'] as Map)['id']);
    const ruoli = {'user': 'Utente', 'admin': 'Admin', 'superadmin': 'Super admin'};
    return _Sezione(
      icona: Icons.manage_accounts_outlined,
      intestazione: 'Utenti',
      coda: Text('${_i(d['tot_utenti'])}', style: const TextStyle(color: muto, fontWeight: FontWeight.w700)),
      figli: [
        for (final u in _utenti)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: superficie2, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => apriUtente(context, _s(u['username'])),
                          child: Text('@${u['username']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      Chip2(testo: ruoli[_s(u['role'])] ?? _s(u['role']), colore: _s(u['role']) == 'user' ? muto : oro, tenue: true),
                      const SizedBox(width: 6),
                      Chip2(testo: _i(u['is_banned']) == 1 ? 'Sospeso' : 'Attivo', colore: _i(u['is_banned']) == 1 ? pompeiano : golfo, tenue: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${_s(u['email'])}\n${_s(u['q_nome']).isEmpty ? 'Senza quartiere' : _s(u['q_nome'])} · iscritto il ${quandoAdmin(u['created_at']).split(' ').first}', style: const TextStyle(color: muto, fontSize: 12.5, height: 1.35)),
                  if (_i(u['id']) != mio) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            final ban = _i(u['is_banned']) != 1;
                            if (ban && !await conferma(context, 'Sospendere @${u['username']}?', 'Non potrà più entrare finché non lo riattivi.', si: 'Sospendi')) return;
                            if (!mounted) return;
                            await _azione(context, () => stato.api.adminSospendi(_i(u['id']), ban), _carica);
                          },
                          child: Text(_i(u['is_banned']) == 1 ? 'Riattiva' : 'Sospendi'),
                        ),
                        if (superadmin)
                          DropdownButton<String>(
                            value: ruoli.containsKey(_s(u['role'])) ? _s(u['role']) : 'user',
                            underline: const SizedBox(),
                            items: [for (final e in ruoli.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                            onChanged: (v) {
                              if (v != null && v != _s(u['role'])) _azione(context, () => stato.api.adminRuolo(_i(u['id']), v), _carica);
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        _mostraAltri(_utenti.length, _i(d['tot_utenti']), _altriU, _altriUtenti),
      ],
    );
  }

  Widget _postCarta(Map<String, dynamic> d) => _Sezione(
    key: _kPost,
    icona: Icons.article_outlined,
    intestazione: _post7 ? 'Post degli ultimi 7 giorni' : 'Ultimi post',
    coda: Text('${_i(d['tot_post'])}', style: const TextStyle(color: muto, fontWeight: FontWeight.w700)),
    figli: [
      _Periodi(
        scelto: _post7 ? 7 : 0,
        voci: const {0: 'Tutti', 7: 'Ultimi 7 giorni'},
        onScelta: (v) {
          setState(() => _post7 = v == 7);
          _carica();
        },
      ),
      const SizedBox(height: 8),
      if (_post.isEmpty) const Text('Nessun post.', style: TextStyle(color: muto)),
      for (final p in _post)
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => apriPost(context, _i(p['id'])),
          title: Text(_accorcia(_s(p['content']), 120)),
          subtitle: Text('@${p['username']} · ${_s(p['q_nome'])} · ${quandoAdmin(p['created_at'])}', style: const TextStyle(color: muto, fontSize: 12.5)),
          trailing: IconButton(
            tooltip: 'Elimina',
            icon: const Icon(Icons.delete_outline_rounded, color: pompeiano),
            onPressed: () async {
              if (!await conferma(context, 'Eliminare il post?', 'Si cancella con commenti e reazioni.')) return;
              if (!mounted) return;
              await _azione(context, () => stato.api.adminEliminaPost(_i(p['id'])), _carica);
            },
          ),
        ),
      _mostraAltri(_post.length, _i(d['tot_post']), _altriP, _altriPost),
    ],
  );
}

// ───────────────────────── Statistiche ─────────────────────────

class _Statistiche extends StatefulWidget {
  const _Statistiche({this.iniziali});

  final Map<String, dynamic>? iniziali;

  @override
  State<_Statistiche> createState() => _StatisticheState();
}

class _StatisticheState extends State<_Statistiche> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _d;
  String? _errore;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _d = widget.iniziali;
    if (_d == null) _carica();
  }

  Future<void> _carica() async {
    try {
      final j = await stato.api.adminStatistiche();
      if (mounted) setState(() => _d = j);
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _Carica(errore: _errore, pronto: _d != null, ricarica: _carica, figlio: () => _corpo(_d!));
  }

  Widget _corpo(Map<String, dynamic> d) {
    final s = d['stat'] as Map;
    final nomiRx = {for (final e in ((d['nomi_reazioni'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'};
    final schede = DefaultTabController.maybeOf(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        _Numeri([
          _Numero(icona: Icons.group_outlined, n: _i(s['iscritti']), testo: _i(s['iscritti_7']) > 0 ? 'Iscritti · +${_i(s['iscritti_7'])} in 7 giorni' : 'Iscritti', onTap: () => schede?.animateTo(2)),
          _Numero(icona: Icons.chat_bubble_outline, n: _i(s['post']), testo: _i(s['post_7']) > 0 ? 'Post · ${_i(s['post_7'])} in 7 giorni' : 'Post'),
          _Numero(icona: Icons.favorite_border, n: _i(s['reazioni']), testo: 'Reazioni'),
          _Numero(icona: Icons.handshake_outlined, n: _i(s['residenti']), testo: 'Residenti confermati · ${_i(s['attesa'])} in attesa'),
          _Numero(icona: Icons.auto_awesome_outlined, n: _i(s['attivi_7']), testo: 'Attivi negli ultimi 7 giorni', caldo: true),
        ]),
        _Sezione(
          icona: Icons.group_add_outlined,
          intestazione: 'Iscrizioni, ultimi 30 giorni',
          figli: [GraficoBarre(a: serieDa(s['iscrizioni_giorni']))],
        ),
        _Sezione(
          icona: Icons.chat_bubble_outline,
          intestazione: 'Post, ultimi 30 giorni',
          figli: [GraficoBarre(a: serieDa(s['post_giorni']))],
        ),
        _Sezione(
          icona: Icons.favorite_border,
          intestazione: 'Reazioni, ultimi 30 giorni',
          figli: [
            GraficoBarre(a: serieDa(s['reazioni_giorni'])),
            const SizedBox(height: 10),
            Classifica(righe: (s['reazioni_tipi'] as List?) ?? const [], nomi: nomiRx, vuoto: 'Ancora nessuna reazione.'),
          ],
        ),
        _Sezione(
          icona: Icons.local_fire_department_outlined,
          intestazione: 'Post con più reazioni',
          figli: [
            if (((s['post_top'] as List?) ?? const []).isEmpty) const Text('Ancora nessuno.', style: TextStyle(color: muto)),
            for (final p in (s['post_top'] as List?) ?? const [])
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => apriPost(context, _i(p['id'])),
                title: Text(_accorcia(_s(p['nome']), 110)),
                trailing: Text('${p['n']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
          ],
        ),
        _Sezione(icona: Icons.place_outlined, intestazione: 'Quartieri più vivi', figli: [Classifica(righe: (s['quartieri_vivi'] as List?) ?? const [])]),
        _Sezione(icona: Icons.home_outlined, intestazione: 'Residenti per quartiere', figli: [Classifica(righe: (s['quartieri_residenti'] as List?) ?? const [])]),
        _Sezione(
          icona: Icons.location_city_outlined,
          intestazione: 'Comuni più richiesti',
          spiega: 'Si aprono da soli a ${_i(s['soglia_apertura'])} richieste.',
          figli: [Classifica(righe: (s['comuni_richiesti'] as List?) ?? const [])],
        ),
      ],
    );
  }
}

// ───────────────────────── Iscritti ─────────────────────────

class _Iscritti extends StatefulWidget {
  const _Iscritti({this.iniziali});

  final Map<String, dynamic>? iniziali;

  @override
  State<_Iscritti> createState() => _IscrittiState();
}

class _IscrittiState extends State<_Iscritti> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _d;
  String? _errore;
  int _giorni = 30, _pn = 1, _pv = 1;
  List<dynamic> _nuovi = [], _via = [];
  bool _altriN = false, _altriV = false;
  final _cerca = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.iniziali != null) {
      _usa(widget.iniziali!);
    } else {
      _carica();
    }
  }

  @override
  void dispose() {
    _cerca.dispose();
    super.dispose();
  }

  void _usa(Map<String, dynamic> j) {
    _d = j;
    _nuovi = List.of(j['nuovi'] as List);
    _via = List.of(j['cancellati'] as List);
    _pn = 1;
    _pv = 1;
  }

  Future<void> _carica() async {
    try {
      final j = await stato.api.adminIscritti(giorni: _giorni, cerca: _cerca.text.trim());
      if (mounted) setState(() => _usa(j));
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  Future<void> _altri(bool cancellati) async {
    setState(() => cancellati ? _altriV = true : _altriN = true);
    try {
      final j = await stato.api.adminIscritti(giorni: _giorni, cerca: _cerca.text.trim(), pn: cancellati ? 1 : _pn + 1, pv: cancellati ? _pv + 1 : 1);
      if (!mounted) return;
      setState(() {
        if (cancellati) {
          _pv++;
          _via.addAll(j['cancellati'] as List);
        } else {
          _pn++;
          _nuovi.addAll(j['nuovi'] as List);
        }
      });
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => cancellati ? _altriV = false : _altriN = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _Carica(errore: _errore, pronto: _d != null, ricarica: _carica, figlio: () => _corpo(_d!));
  }

  Widget _corpo(Map<String, dynamic> d) {
    final r = d['rapporto'] as Map;
    final saldo = _i(r['nuovi_periodo']) - _i(r['via_periodo']);
    final periodo = _giorni == 0 ? 'da sempre' : '$_giorni giorni';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        _Periodi(
          scelto: _giorni,
          voci: const {7: '7 giorni', 30: '30 giorni', 90: '90 giorni', 0: 'Sempre'},
          onScelta: (g) {
            setState(() => _giorni = g);
            _carica();
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _cerca,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _carica(),
          decoration: const InputDecoration(hintText: 'Cerca per nome, @username o quartiere', prefixIcon: Icon(Icons.search_rounded)),
        ),
        const SizedBox(height: 12),
        _Numeri([
          _Numero(icona: Icons.group_outlined, n: _i(r['totale_ora']), testo: 'Iscritti in tutto'),
          _Numero(icona: Icons.logout_rounded, n: _i(r['via_periodo']), testo: 'Cancellati · $periodo'),
          _Numero(icona: Icons.trending_up_rounded, n: '${saldo > 0 ? '+' : ''}$saldo', testo: 'Saldo del periodo'),
          _Numero(icona: Icons.handshake_outlined, n: _i(r['residenti']), testo: 'Residenti confermati'),
          _Numero(icona: Icons.auto_awesome_outlined, n: _i(r['nuovi_periodo']), testo: 'Nuovi · $periodo', caldo: true),
        ]),
        _Sezione(
          icona: Icons.group_outlined,
          intestazione: 'Iscrizioni e cancellazioni',
          spiega: _i(r['passo']) > 1 ? 'Per settimana.' : 'Per giorno.',
          figli: [
            GraficoBarre(a: serieDa(r['nuovi_giorni']), b: serieDa(r['via_giorni'])),
            const SizedBox(height: 8),
            const Legenda([('Iscrizioni', terracotta), ('Cancellazioni', oro)]),
          ],
        ),
        _Sezione(
          icona: Icons.show_chart_rounded,
          intestazione: 'Totale iscritti nel tempo',
          spiega: 'Quanti erano iscritti alla fine di ogni giorno.',
          figli: [GraficoLinea(serie: serieDa(r['totale_giorni']))],
        ),
        _Sezione(icona: Icons.map_outlined, intestazione: 'Iscritti per quartiere', figli: [Classifica(righe: (r['quartieri'] as List?) ?? const [])]),
        _Sezione(
          icona: Icons.person_add_alt_outlined,
          intestazione: 'Nuovi iscritti',
          coda: Text('${_i(d['tot_nuovi'])}', style: const TextStyle(color: muto, fontWeight: FontWeight.w700)),
          figli: [
            if (_nuovi.isEmpty) const Text('Nessuno in questo periodo.', style: TextStyle(color: muto)),
            for (final u in _nuovi)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => apriUtente(context, _s(u['username'])),
                leading: FotoProfilo.da(nome: _s(u['display_name']).isEmpty ? _s(u['username']) : _s(u['display_name']), avatar: u['avatar_path'] as String?, lato: 38),
                title: Text(_s(u['display_name']).isEmpty ? '@${u['username']}' : _s(u['display_name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '@${u['username']} · ${_s(u['q_nome']).isEmpty ? 'senza quartiere' : '${u['q_nome']} (${_s(u['residenza']) == 'confermata' ? 'residente' : 'in attesa'})'}\n'
                  '${quandoAdmin(u['created_at'])} · ${_s(u['iscritto_da']) == 'app' ? 'dall\'app' : (_s(u['iscritto_da']).isEmpty ? '' : 'dal sito web')}'
                  '${_s(u['ultimo_accesso']).isEmpty ? '' : ' · ultimo accesso ${quandoAdmin(u['ultimo_accesso'])}'}',
                  style: const TextStyle(color: muto, fontSize: 12.5, height: 1.35),
                ),
              ),
            _mostraAltri(_nuovi.length, _i(d['tot_nuovi']), _altriN, () => _altri(false)),
          ],
        ),
        _Sezione(
          icona: Icons.person_remove_outlined,
          intestazione: 'Chi si è cancellato',
          spiega: 'Di chi elimina l\'account resta solo questa riga, per 12 mesi.',
          coda: Text('${_i(d['tot_cancellati'])}', style: const TextStyle(color: muto, fontWeight: FontWeight.w700)),
          figli: [
            if (_via.isEmpty) const Text('Nessuno in questo periodo.', style: TextStyle(color: muto)),
            for (final u in _via)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_s(u['nome']).isNotEmpty ? _s(u['nome']) : '@${u['username']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '@${u['username']} · ${_s(u['quartiere']).isEmpty ? 'senza quartiere' : u['quartiere']}\n'
                  'Iscritto ${quandoAdmin(u['iscritto_il']).split(' ').first} · cancellato ${quandoAdmin(u['cancellato_il'])}${_s(u['da']).isEmpty ? '' : ' · ${u['da']}'}',
                  style: const TextStyle(color: muto, fontSize: 12.5, height: 1.35),
                ),
              ),
            _mostraAltri(_via.length, _i(d['tot_cancellati']), _altriV, () => _altri(true)),
          ],
        ),
      ],
    );
  }
}


// ───────────────────────── Visite ─────────────────────────

class _Visite extends StatefulWidget {
  const _Visite({this.iniziali});

  final Map<String, dynamic>? iniziali;

  @override
  State<_Visite> createState() => _VisiteState();
}

class _VisiteState extends State<_Visite> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _d;
  String? _errore;
  int _giorni = 30, _pa = 1;
  String _ordine = 'ultimo';
  List<dynamic> _accessi = [];
  bool _altriA = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.iniziali != null) {
      _usa(widget.iniziali!);
    } else {
      _carica();
    }
  }

  void _usa(Map<String, dynamic> j) {
    _d = j;
    _accessi = List.of(j['accessi'] as List);
    _pa = 1;
  }

  Future<void> _carica() async {
    try {
      final j = await stato.api.adminVisite(giorni: _giorni, ordine: _ordine);
      if (mounted) setState(() => _usa(j));
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  Future<void> _altri() async {
    setState(() => _altriA = true);
    try {
      final j = await stato.api.adminVisite(giorni: _giorni, ordine: _ordine, pa: _pa + 1);
      if (mounted) {
        setState(() {
        _pa++;
        _accessi.addAll(j['accessi'] as List);
        });
      }
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _altriA = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _Carica(errore: _errore, pronto: _d != null, ricarica: _carica, figlio: () => _corpo(_d!));
  }

  Map<String, String> _nomi(Map<String, dynamic> d, String k) => {for (final e in ((d[k] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'};

  /// Classifica col numero giusto: visitatori unici (u) per le provenienze, pagine viste (n) per il resto.
  List<dynamic> _righe(Object? l, {bool unici = false}) {
    final r = ((l as List?) ?? const []).map((x) => {'nome': (x as Map)['nome'], 'n': unici ? x['u'] : x['n']}).where((x) => (double.tryParse('${x['n']}') ?? 0) > 0).toList();
    r.sort((a, b) => (double.tryParse('${b['n']}') ?? 0).compareTo(double.tryParse('${a['n']}') ?? 0));
    return r.take(10).toList();
  }

  Widget _corpo(Map<String, dynamic> d) {
    final r = d['rapporto'] as Map;
    final giorniN = serieDa(r['unici_giorni']).length;
    final media = giorniN == 0 ? 0 : _i(r['unici']) / giorniN;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        _Periodi(
          scelto: _giorni,
          voci: const {7: '7 giorni', 30: '30 giorni', 90: '90 giorni'},
          onScelta: (g) {
            setState(() => _giorni = g);
            _carica();
          },
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 15, color: muto),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Conteggio anonimo, senza cookie: non si salvano indirizzi IP né chi è il visitatore. Esclusi robot, anteprime dei social e pannello admin.',
                style: TextStyle(color: muto, fontSize: 12.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Numeri([
          _Numero(icona: Icons.menu_book_outlined, n: _i(r['viste']), testo: 'Pagine viste'),
          _Numero(icona: Icons.auto_awesome_outlined, n: media.toStringAsFixed(1).replaceAll('.', ','), testo: 'Visitatori al giorno, in media'),
          _Numero(icona: Icons.check_rounded, n: _i(r['entrati_oggi']), testo: 'Iscritti entrati oggi'),
          _Numero(
            icona: Icons.schedule_rounded,
            n: _i(r['unici']) == 0 ? '0' : (_i(r['viste']) / _i(r['unici'])).toStringAsFixed(1).replaceAll('.', ','),
            testo: 'Pagine per visitatore',
          ),
          _Numero(icona: Icons.group_outlined, n: _i(r['unici']), testo: 'Visitatori unici · $_giorni giorni', caldo: true),
        ]),
        _Sezione(
          icona: Icons.group_outlined,
          intestazione: 'Visitatori e pagine viste',
          figli: [
            GraficoBarre(a: serieDa(r['unici_giorni']), b: serieDa(r['viste_giorni'])),
            const SizedBox(height: 8),
            const Legenda([('Visitatori', terracotta), ('Pagine viste', oro)]),
          ],
        ),
        _Sezione(
          icona: Icons.check_rounded,
          intestazione: 'Iscritti attivi al giorno',
          spiega: 'Iscritti che sono entrati almeno una volta, dal sito o dall\'app.',
          figli: [GraficoBarre(a: serieDa(r['attivi_giorni']))],
        ),
        _Sezione(icona: Icons.menu_book_outlined, intestazione: 'Pagine più viste', figli: [Classifica(righe: _righe(r['pagine']), nomi: _nomi(d, 'nomi_pagine'))]),
        _Sezione(
          icona: Icons.north_east_rounded,
          intestazione: 'Da dove arrivano',
          spiega: 'Visitatori unici. Chi apre un link da WhatsApp o Telegram sul telefono di solito risulta «diretto».',
          figli: [Classifica(righe: _righe(r['provenienze'], unici: true), nomi: _nomi(d, 'nomi_provenienze'))],
        ),
        _Sezione(
          icona: Icons.devices_outlined,
          intestazione: 'Sito web o app, telefono o computer',
          spiega: 'Pagine viste.',
          figli: [
            Classifica(righe: _righe(r['canali']), nomi: _nomi(d, 'nomi_canali')),
            const Divider(height: 18),
            Classifica(righe: _righe(r['dispositivi']), nomi: _nomi(d, 'nomi_dispositivi')),
          ],
        ),
        _Sezione(
          icona: Icons.schedule_rounded,
          intestazione: 'Chi entra',
          coda: Text('${_i(d['tot_accessi'])}', style: const TextStyle(color: muto, fontWeight: FontWeight.w700)),
          figli: [
            _Periodi(
              scelto: ['ultimo', 'nome', 'iscritto'].indexOf(_ordine),
              voci: const {0: 'Ultimo accesso', 1: 'Nome', 2: 'Iscrizione'},
              onScelta: (i) {
                setState(() => _ordine = ['ultimo', 'nome', 'iscritto'][i]);
                _carica();
              },
            ),
            const SizedBox(height: 8),
            for (final u in _accessi)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => apriUtente(context, _s(u['username'])),
                leading: FotoProfilo.da(nome: _s(u['display_name']).isEmpty ? _s(u['username']) : _s(u['display_name']), avatar: u['avatar_path'] as String?, lato: 38),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(_s(u['display_name']).isEmpty ? '@${u['username']}' : _s(u['display_name']), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    if (_oggi(u['ultimo_accesso'])) ...[const SizedBox(width: 6), const Chip2(testo: 'oggi', colore: golfo, tenue: true)],
                  ],
                ),
                subtitle: Text(
                  '${_s(u['q_nome']).isEmpty ? 'senza quartiere' : u['q_nome']} · '
                  '${_s(u['ultimo_accesso']).isEmpty ? 'mai entrato da oggi' : 'ultimo accesso ${quandoAdmin(u['ultimo_accesso'])}'} · ${_i(u['giorni_30'])} giorni attivi su 30',
                  style: const TextStyle(color: muto, fontSize: 12.5, height: 1.35),
                ),
              ),
            _mostraAltri(_accessi.length, _i(d['tot_accessi']), _altriA, _altri),
          ],
        ),
      ],
    );
  }

  bool _oggi(Object? v) {
    final d = DateTime.tryParse(_s(v));
    final o = DateTime.now();
    return d != null && d.year == o.year && d.month == o.month && d.day == o.day;
  }
}

// ───────────────────────── Registro ─────────────────────────

class _Registro extends StatefulWidget {
  const _Registro({this.iniziali});

  final Map<String, dynamic>? iniziali;

  @override
  State<_Registro> createState() => _RegistroState();
}

class _RegistroState extends State<_Registro> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _d;
  String? _errore;
  String _azioneScelta = '';
  int _pg = 1;
  List<dynamic> _righe = [];
  bool _altriR = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.iniziali != null) {
      _usa(widget.iniziali!);
    } else {
      _carica();
    }
  }

  void _usa(Map<String, dynamic> j) {
    _d = j;
    _righe = List.of(j['righe'] as List);
    _pg = 1;
  }

  Future<void> _carica() async {
    try {
      final j = await stato.api.adminRegistro(azione: _azioneScelta);
      if (mounted) setState(() => _usa(j));
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  Future<void> _altri() async {
    setState(() => _altriR = true);
    try {
      final j = await stato.api.adminRegistro(azione: _azioneScelta, pg: _pg + 1);
      if (mounted) {
        setState(() {
        _pg++;
        _righe.addAll(j['righe'] as List);
        });
      }
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _altriR = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _Carica(errore: _errore, pronto: _d != null, ricarica: _carica, figlio: () => _corpo(_d!));
  }

  Widget _corpo(Map<String, dynamic> d) {
    final tipi = (d['tipi'] as List).cast<Map>();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _azioneScelta,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tipo di azione'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Tutte')),
            for (final t in tipi) DropdownMenuItem(value: _s(t['chiave']), child: Text('${t['titolo']} (${t['n']})', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            setState(() => _azioneScelta = v ?? '');
            _carica();
          },
        ),
        const SizedBox(height: 8),
        const Text('Il registro non salva indirizzi IP né il testo dei post. Il voto per i moderatori resta segreto.', style: TextStyle(color: muto, fontSize: 12.5)),
        const SizedBox(height: 10),
        if (_righe.isEmpty) const Text('Nessuna riga.', style: TextStyle(color: muto)),
        for (final r in _righe)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: superficie, borderRadius: BorderRadius.circular(10), border: Border.all(color: linea)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_s(r['username']).isEmpty ? 'triburba' : '@${r['username']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text(quandoAdmin(r['created_at']), style: const TextStyle(color: muto, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Chip2(testo: _s(r['titolo']).toUpperCase(), colore: oro, tenue: true),
                if (_s(r['dettaglio']).isNotEmpty) ...[const SizedBox(height: 4), Text(_s(r['dettaglio']), style: const TextStyle(color: testo2, fontSize: 13))],
              ],
            ),
          ),
        _mostraAltri(_righe.length, _i(d['tot']), _altriR, _altri),
      ],
    );
  }
}

// ───────────────────────── Commenti ─────────────────────────

class SchermataAdminCommenti extends StatefulWidget {
  const SchermataAdminCommenti({super.key, this.iniziali});

  final Map<String, dynamic>? iniziali;

  @override
  State<SchermataAdminCommenti> createState() => _SchermataAdminCommentiState();
}

class _SchermataAdminCommentiState extends State<SchermataAdminCommenti> {
  Map<String, dynamic>? _d;
  String? _errore;
  int _pc = 1;
  List<dynamic> _righe = [];
  bool _altriC = false;

  @override
  void initState() {
    super.initState();
    if (widget.iniziali != null) {
      _usa(widget.iniziali!);
    } else {
      _carica();
    }
  }

  void _usa(Map<String, dynamic> j) {
    _d = j;
    _righe = List.of(j['commenti'] as List);
    _pc = 1;
  }

  Future<void> _carica() async {
    try {
      final j = await stato.api.adminCommenti();
      if (mounted) setState(() => _usa(j));
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  Future<void> _altri() async {
    setState(() => _altriC = true);
    try {
      final j = await stato.api.adminCommenti(pc: _pc + 1);
      if (mounted) {
        setState(() {
        _pc++;
        _righe.addAll(j['commenti'] as List);
        });
      }
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _altriC = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Commenti')),
    body: _Carica(
      errore: _errore,
      pronto: _d != null,
      ricarica: _carica,
      figlio: () => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
        children: [
          Text('${_i(_d!['tot'])} commenti', style: const TextStyle(color: muto, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_righe.isEmpty) const Text('Ancora nessun commento.', style: TextStyle(color: muto)),
          for (final c in _righe)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              decoration: BoxDecoration(color: superficie, borderRadius: BorderRadius.circular(10), border: Border.all(color: linea)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => apriPost(context, _i(c['post_id'])),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${c['username']}${c['parent_id'] != null ? ' · risposta' : ''} · ${quandoAdmin(c['created_at'])}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 3),
                          Text(_accorcia(_s(c['content']), 200)),
                          const SizedBox(height: 4),
                          Text('Sul post di @${c['post_autore']}: «${_accorcia(_s(c['post_testo']), 60)}»', style: const TextStyle(color: muto, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Elimina',
                    icon: const Icon(Icons.delete_outline_rounded, color: pompeiano),
                    onPressed: () async {
                      if (!await conferma(this.context, 'Eliminare il commento?', 'Si cancellano anche le sue risposte.')) return;
                      if (!mounted) return;
                      await _azione(this.context, () => stato.api.adminEliminaCommento(_i(c['id'])), _carica);
                    },
                  ),
                ],
              ),
            ),
          _mostraAltri(_righe.length, _i(_d!['tot']), _altriC, _altri),
        ],
      ),
    ),
  );
}
