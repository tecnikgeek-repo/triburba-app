// Follower e Seguiti di una persona, come /u/nome/follower e /u/nome/seguiti sul sito:
// due schede, 25 persone per volta (le altre arrivano scorrendo), tasto «Segui / Segui già», tocco → profilo.
import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/faccia.dart';
import '../widget/lista_post.dart';
import 'naviga.dart';

class SchermataFollow extends StatelessWidget {
  const SchermataFollow({super.key, required this.username, required this.nome, this.seguiti = false});

  final String username;
  final String nome;

  /// true = apre sulla scheda «Seguiti»
  final bool seguiti;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: seguiti ? 1 : 0,
    child: Scaffold(
      appBar: AppBar(
        title: Text(nome),
        bottom: const TabBar(
          tabAlignment: TabAlignment.fill,
          labelStyle: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15),
          tabs: [Tab(text: 'Follower'), Tab(text: 'Seguiti')],
        ),
      ),
      body: TabBarView(
        children: [
          ElencoFollow(username: username, tipo: 'follower'),
          ElencoFollow(username: username, tipo: 'seguiti'),
        ],
      ),
    ),
  );
}

class ElencoFollow extends StatefulWidget {
  const ElencoFollow({super.key, required this.username, required this.tipo});

  final String username;
  final String tipo;

  @override
  State<ElencoFollow> createState() => _ElencoFollowState();
}

class _ElencoFollowState extends State<ElencoFollow> with AutomaticKeepAliveClientMixin {
  final _persone = <Map<String, dynamic>>[];
  final _occupati = <String>{};
  int _pagina = 0, _totale = 0;
  bool _altri = true, _carico = false;
  String? _errore;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _avanti();
  }

  Future<void> _avanti({bool daCapo = false}) async {
    if (_carico || (!_altri && !daCapo)) return;
    setState(() {
      _carico = true;
      _errore = null;
    });
    try {
      final p = daCapo ? 1 : _pagina + 1;
      final j = await stato.api.elencoFollow(widget.username, widget.tipo, pagina: p);
      if (!mounted) return;
      setState(() {
        if (daCapo) _persone.clear();
        _persone.addAll((j['persone'] as List? ?? []).map((x) => Map<String, dynamic>.from(x as Map)));
        _pagina = p;
        _totale = (j['totale'] as num? ?? 0).toInt();
        _altri = j['altri'] == true;
        _carico = false;
      });
    } on ErroreApi catch (e) {
      if (mounted) {
        setState(() {
          _errore = e.messaggio;
          _carico = false;
        });
      }
    }
  }

  Future<void> _segui(Map<String, dynamic> p) async {
    final u = Faccia(p['faccia'] as Map<String, dynamic>).username;
    if (_occupati.contains(u)) return;
    setState(() => _occupati.add(u));
    try {
      final j = await stato.api.segui(u);
      if (!mounted) return;
      setState(() => p['seguo'] = j['following'] == true);
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _occupati.remove(u));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_persone.isEmpty && _carico) return const Center(child: CircularProgressIndicator());
    if (_persone.isEmpty && _errore != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errore!, textAlign: TextAlign.center, style: const TextStyle(color: testo2)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => _avanti(daCapo: true), child: const Text('Riprova')),
            ],
          ),
        ),
      );
    }
    if (_persone.isEmpty) {
      return Vuoto(
        icona: Icons.people_outline_rounded,
        testo: widget.tipo == 'follower' ? 'Ancora nessun follower.' : 'Non segue ancora nessuno.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _avanti(daCapo: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _avanti();
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 24),
          itemCount: _persone.length + 2,
          itemBuilder: (c, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  _totale == 1 ? '1 persona' : '$_totale persone',
                  style: const TextStyle(fontFamily: 'Inter', color: muto, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              );
            }
            if (i == _persone.length + 1) {
              return _altri
                  ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                  : const SizedBox.shrink();
            }
            return _riga(_persone[i - 1]);
          },
        ),
      ),
    );
  }

  Widget _riga(Map<String, dynamic> p) {
    final f = Faccia(p['faccia'] as Map<String, dynamic>);
    final q = (p['quartiere'] as String?) ?? '';
    final seguo = p['seguo'] == true;
    final occupato = _occupati.contains(f.username);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => apriUtente(context, f.username),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            FotoProfilo(faccia: f, lato: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          f.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15.5),
                        ),
                      ),
                      const SizedBox(width: 5),
                      StemmaMini(stemma: f.stemma, altezza: 16),
                    ],
                  ),
                  Text(
                    '@${f.username}${q.isNotEmpty ? ' · $q' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Inter', color: muto, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (p['io'] == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: superficie2, borderRadius: BorderRadius.circular(6)),
                child: const Text('TU', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 11, color: testo2)),
              )
            else
              SizedBox(
                height: 36,
                child: seguo
                    ? OutlinedButton(
                        onPressed: occupato ? null : () => _segui(p),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 14)),
                        child: const Text('Segui già', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 13.5)),
                      )
                    : FilledButton(
                        onPressed: occupato ? null : () => _segui(p),
                        style: FilledButton.styleFrom(
                          backgroundColor: terracotta,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Segui', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 13.5, color: bianco)),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
