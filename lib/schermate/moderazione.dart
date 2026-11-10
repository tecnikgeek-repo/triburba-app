// Moderatori e moderazione di un quartiere, dentro l'app (come le schede «Moderatori», «Proposti»,
// «Segnalati» e «Regole» del quartiere su triburba): candidature e voto segreto, sfiducia,
// post proposti da altri quartieri da accettare, post nascosti dalle segnalazioni da rivedere, regole.
import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/faccia.dart';
import 'naviga.dart';

class SchermataModerazione extends StatefulWidget {
  const SchermataModerazione({super.key, required this.slug, this.datiIniziali});

  final String slug;

  /// Solo per le anteprime: dati già pronti, senza rete.
  final Map<String, dynamic>? datiIniziali;

  @override
  State<SchermataModerazione> createState() => _SchermataModerazioneState();
}

class _SchermataModerazioneState extends State<SchermataModerazione> {
  Map<String, dynamic>? _d;
  String? _errore;
  final _occupati = <String>{};
  final _regole = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.datiIniziali != null) {
      _usa(widget.datiIniziali!);
    } else {
      _carica();
    }
  }

  @override
  void dispose() {
    _regole.dispose();
    super.dispose();
  }

  void _usa(Map<String, dynamic> j) {
    _d = j;
    _regole.text = '${(j['quartiere'] as Map)['regole'] ?? ''}';
  }

  Future<void> _carica() async {
    try {
      final j = await stato.api.moderazione(widget.slug);
      if (mounted) setState(() => _usa(j));
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  int get _qId => ((_d!['quartiere'] as Map)['id'] as num).toInt();

  /// Esegue un'azione, mostra il messaggio e ricarica i dati.
  Future<void> _fai(String chiave, Future<String> Function() azione) async {
    setState(() => _occupati.add(chiave));
    try {
      final msg = await azione();
      if (mounted && msg.isNotEmpty) messaggio(context, msg);
      await _carica();
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _occupati.remove(chiave));
    }
  }

  Future<void> _candidati() async {
    final candidato = _d!['candidato'] == true;
    if (candidato) {
      if (!await conferma(context, 'Ritiri la candidatura?', 'Perdi i voti ricevuti e il post in bacheca sparisce.', si: 'Ritira')) return;
      await _fai('cand', () async => '${(await stato.api.candidatura(_qId))['msg'] ?? ''}');
      return;
    }
    final m = await chiediTesto(context, 'Perché ti candidi?', suggerimento: 'Due righe per i vicini (facoltativo)', ok: 'Candidati');
    if (m == null || !mounted) return;
    await _fai('cand', () async => '${(await stato.api.candidatura(_qId, motivazione: m))['msg'] ?? ''}');
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moderazione')),
        body: Center(
          child: _errore == null
              ? const CircularProgressIndicator()
              : Padding(padding: const EdgeInsets.all(24), child: Text(_errore!, textAlign: TextAlign.center, style: const TextStyle(color: muto))),
        ),
      );
    }
    final residente = d['residente'] == true;
    final puoMod = d['puo_moderare'] == true;
    final schede = <(String, Widget)>[
      ('Moderatori', _moderatori(d)),
      if (residente || puoMod) ('Proposte ${(d['proposte'] as List).isEmpty ? '' : '· ${(d['proposte'] as List).length}'}'.trim(), _proposte(d)),
      if (puoMod) ('Nascosti ${(d['nascosti'] as List).isEmpty ? '' : '· ${(d['nascosti'] as List).length}'}'.trim(), _nascosti(d)),
      if (puoMod) ('Regole', _scheda([_cartaRegole()])),
    ];
    return DefaultTabController(
      length: schede.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${(d['quartiere'] as Map)['nome']}'),
          bottom: TabBar(
            isScrollable: schede.length > 3,
            tabAlignment: schede.length > 3 ? TabAlignment.start : TabAlignment.fill,
            labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 14.5),
            tabs: [for (final s in schede) Tab(text: s.$1)],
          ),
        ),
        body: TabBarView(children: [for (final s in schede) s.$2]),
      ),
    );
  }

  Widget _scheda(List<Widget> figli) => RefreshIndicator(
    onRefresh: _carica,
    child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 30), children: figli),
  );

  Widget _nota(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: const TextStyle(color: muto, height: 1.4)),
  );

  // ── Moderatori e candidati ──

  Widget _moderatori(Map<String, dynamic> d) {
    final candidati = (d['candidati'] as List).cast<Map<String, dynamic>>();
    final residente = d['residente'] == true;
    final bloccato = d['bloccato_fino'] as String?;
    return _scheda([
      _nota(
        'I moderatori li scelgono i residenti: diventano moderatori i ${d['max_moderatori']} candidati più votati '
        'con almeno ${d['voti_min']} voti. Il voto è segreto e si può spostare o ritirare.',
      ),
      if (residente)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: bloccato != null && d['candidato'] != true
              ? Text('I residenti ti hanno sfiduciato: potrai ricandidarti dal $bloccato.', style: const TextStyle(color: pompeiano))
              : d['candidato'] == true
              ? OutlinedButton.icon(
                  onPressed: _occupati.contains('cand') ? null : _candidati,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Ritira la candidatura'),
                )
              : BottoneCaldo(testo: 'Candidati', icona: Icons.how_to_vote_outlined, occupato: _occupati.contains('cand'), onPressed: _candidati),
        ),
      if (candidati.isEmpty) _nota('Ancora nessun candidato.'),
      for (final c in candidati) _candidato(c, residente),
    ]);
  }

  Widget _candidato(Map<String, dynamic> c, bool residente) {
    final id = (c['id'] as num).toInt();
    final voti = (c['voti'] as num).toInt();
    final eletto = c['eletto'] == true;
    final mio = c['mio_voto'] == true;
    final kv = 'v$id', ks = 's$id';
    return Carta(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(onTap: () => apriUtente(context, '${c['username']}'), child: FotoProfilo(faccia: Faccia(c), lato: 42)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text('${c['nome']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                        if (eletto) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: oro.withValues(alpha: .18), borderRadius: BorderRadius.circular(6)),
                            child: const Text('MODERATORE', style: TextStyle(color: oro, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .4)),
                          ),
                        ],
                      ],
                    ),
                    Text('$voti ${voti == 1 ? 'voto' : 'voti'}${c['io'] == true ? ' · sei tu' : ''}',
                        style: const TextStyle(color: oro, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (residente && c['io'] != true)
                SizedBox(
                  width: 124,
                  child: mio
                      ? OutlinedButton.icon(
                          onPressed: _occupati.contains(kv) ? null : () => _fai(kv, () async => '${(await stato.api.votaCandidato(_qId, id))['msg'] ?? ''}'),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Votato', maxLines: 1, softWrap: false),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                        )
                      : BottoneCaldo(
                          testo: 'Vota',
                          occupato: _occupati.contains(kv),
                          onPressed: () => _fai(kv, () async => '${(await stato.api.votaCandidato(_qId, id))['msg'] ?? ''}'),
                        ),
                ),
            ],
          ),
          if ((c['motivazione'] as String?)?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('${c['motivazione']}', style: const TextStyle(color: testo2, height: 1.4)),
          ],
          if (eletto && residente && c['io'] != true) ...[
            const SizedBox(height: 8),
            if (c['puo_sfiduciare'] == true)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sfiducia: ${c['sfiducie']} su ${c['sfiducie_servono']} per farlo decadere. È segreta.',
                      style: const TextStyle(color: muto, fontSize: 12.5),
                    ),
                  ),
                  TextButton(
                    onPressed: _occupati.contains(ks)
                        ? null
                        : () async {
                            if (c['mia_sfiducia'] != true &&
                                !await conferma(context, 'Togli la fiducia?', 'Se abbastanza residenti la tolgono, ${c['nome']} non è più moderatore.', si: 'Togli la fiducia')) {
                              return;
                            }
                            await _fai(ks, () async => '${(await stato.api.sfiducia(_qId, id))['msg'] ?? ''}');
                          },
                    child: Text(c['mia_sfiducia'] == true ? 'Ridai la fiducia' : 'Togli la fiducia'),
                  ),
                ],
              )
            else if (c['sfiducia_dal'] != null)
              Text('La fiducia si potrà togliere dal ${c['sfiducia_dal']}.', style: const TextStyle(color: muto, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }

  // ── Post proposti da altri quartieri ──

  Widget _proposte(Map<String, dynamic> d) {
    final proposte = (d['proposte'] as List).cast<Map<String, dynamic>>();
    return _scheda([
      _nota('Post che vicini di altri quartieri vogliono far arrivare qui. Entrano nella bacheca quando un residente li accetta.'),
      if (proposte.isEmpty) _nota('Nessuna proposta da decidere.'),
      for (final p in proposte) _cartaPost(
        p,
        sopra: '${p['livello'] == 'municipalita' ? 'Per tutta la ${(d['quartiere'] as Map)['municipalita']}' : 'Per questo quartiere'}'
            '${p['da'] != null ? ' · da ${p['da']}' : ''}${p['portato_da'] != null ? ' · portato da @${p['portato_da']}' : ''}',
        tasti: [
          Expanded(
            child: OutlinedButton(
              onPressed: _occupati.contains('r${p['post_id']}')
                  ? null
                  : () => _fai('r${p['post_id']}', () => stato.api.decidiProposta(_qId, (p['post_id'] as num).toInt(), '${p['livello']}', false)),
              child: const Text('Rifiuta'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BottoneCaldo(
              testo: 'Accetta',
              occupato: _occupati.contains('a${p['post_id']}'),
              onPressed: () => _fai('a${p['post_id']}', () => stato.api.decidiProposta(_qId, (p['post_id'] as num).toInt(), '${p['livello']}', true)),
            ),
          ),
        ],
      ),
    ]);
  }

  // ── Post nascosti dalle segnalazioni ──

  Widget _nascosti(Map<String, dynamic> d) {
    final nascosti = (d['nascosti'] as List).cast<Map<String, dynamic>>();
    return _scheda([
      _nota('Post segnalati dai residenti o nascosti dopo le segnalazioni. Se non c\'è niente di male, rimettili visibili; altrimenti eliminali.'),
      if (nascosti.isEmpty) _nota('Nessun post da rivedere.'),
      for (final p in nascosti) _cartaPost(
        p,
        sopra: '${p['segnalazioni']} ${p['segnalazioni'] == 1 ? 'segnalazione' : 'segnalazioni'}${p['motivi'] != null ? ': ${p['motivi']}' : ''}',
        tasti: [
          Expanded(
            child: OutlinedButton(
              onPressed: _occupati.contains('e${p['post_id']}')
                  ? null
                  : () async {
                      if (!await conferma(context, 'Elimini il post?', 'Sparisce per sempre, per tutti.')) return;
                      await _fai('e${p['post_id']}', () async {
                        await stato.api.elimina((p['post_id'] as num).toInt());
                        return 'Post eliminato.';
                      });
                    },
              child: const Text('Elimina', style: TextStyle(color: pompeiano)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BottoneCaldo(
              testo: 'Rimetti visibile',
              occupato: _occupati.contains('p${p['post_id']}'),
              onPressed: () => _fai('p${p['post_id']}', () => stato.api.ripristina(_qId, (p['post_id'] as num).toInt())),
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _cartaPost(Map<String, dynamic> p, {required String sopra, required List<Widget> tasti}) {
    final a = (p['autore'] as Map).cast<String, dynamic>();
    return Carta(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sopra, style: const TextStyle(color: oro, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              FotoProfilo(faccia: Faccia(a), lato: 32),
              const SizedBox(width: 8),
              Expanded(child: Text('${a['nome']}', style: const TextStyle(fontWeight: FontWeight.w700))),
              Text('${p['quando'] ?? ''}', style: const TextStyle(color: muto, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${p['testo']}', style: const TextStyle(height: 1.4)),
          const SizedBox(height: 12),
          Row(children: tasti),
        ],
      ),
    );
  }

  // ── Regole del quartiere ──

  Widget _cartaRegole() => Carta(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Le regole valgono per tutti i post del quartiere e si aggiungono al regolamento di triburba.',
            style: TextStyle(color: muto, height: 1.4)),
        const SizedBox(height: 12),
        TextField(
          controller: _regole,
          maxLines: 10,
          minLines: 5,
          maxLength: 5000,
          decoration: const InputDecoration(hintText: 'Es. niente pubblicità, niente annunci di vendita…'),
        ),
        const SizedBox(height: 8),
        BottoneCaldo(
          testo: 'Salva le regole',
          occupato: _occupati.contains('regole'),
          onPressed: () => _fai('regole', () => stato.api.salvaRegole(_qId, _regole.text)),
        ),
      ],
    ),
  );
}
