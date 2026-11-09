// Home: schede del feed come sul sito (Per te, Quartiere, Municipalità, Napoli, Area metro, Persone),
// avviso della residenza in attesa e ricerca.
import 'package:flutter/material.dart';

import '../dati/stato.dart';
import '../tema.dart';
import '../widget/lista_post.dart';
import '../widget/primi_passi.dart';
import 'cerca.dart';
import 'naviga.dart';

class SchermataFeed extends StatefulWidget {
  const SchermataFeed({super.key});

  @override
  State<SchermataFeed> createState() => SchermataFeedState();
}

class SchermataFeedState extends State<SchermataFeed> with TickerProviderStateMixin {
  TabController? _schede;
  List<(String, String)> _elenco = const [];
  final _liste = <String, GlobalKey<ListaPostState>>{};

  @override
  void initState() {
    super.initState();
    _prepara();
    stato.addListener(_prepara);
  }

  @override
  void dispose() {
    stato.removeListener(_prepara);
    _schede?.dispose();
    super.dispose();
  }

  void _prepara() {
    final nuove = stato.io?.schede ?? const [('perte', 'Per te')];
    if (nuove.map((e) => e.$1).join(',') == _elenco.map((e) => e.$1).join(',')) {
      if (mounted) setState(() {}); // la carta «Primi passi» segue i dati aggiornati
      return;
    }
    final vecchio = _schede;
    setState(() {
      _elenco = nuove;
      _schede = TabController(length: nuove.length, vsync: this);
    });
    vecchio?.dispose();
  }

  /// Dopo aver pubblicato: torna su «Per te» e ricarica.
  void aggiornaTutto() {
    _schede?.animateTo(0);
    for (final k in _liste.values) {
      k.currentState?.aggiorna();
    }
  }

  @override
  Widget build(BuildContext context) {
    final io = stato.io;
    final guida = io?.guida;
    final guidaVisibile = guida != null && !guida.nascosta;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [emblema(30), const SizedBox(width: 8), const Marchio(misura: 25)]),
        actions: [
          IconButton(
            tooltip: 'Cerca',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SchermataCerca())),
          ),
          const SizedBox(width: 4),
        ],
        bottom: _schede == null
            ? null
            : TabBar(
                controller: _schede,
                isScrollable: true,
                tabs: [for (final s in _elenco) Tab(text: s.$2)],
              ),
      ),
      body: Column(
        children: [
          if (io != null && !guidaVisibile && io.casa != null && io.residenza == 'in_attesa') _attesa(io.casa!),
          if (io != null && !guidaVisibile && io.casa == null) _senzaCasa(),
          Expanded(
            child: _schede == null
                ? const SizedBox.shrink()
                : TabBarView(
                    controller: _schede,
                    children: [
                      for (final s in _elenco)
                        ListaPost(
                          key: _liste.putIfAbsent(s.$1, () => GlobalKey<ListaPostState>()),
                          testa: s.$1 == 'perte' && guidaVisibile
                              ? PrimiPassi(
                                  key: ValueKey('guida-${guida.fatti}-${guida.completa}'),
                                  guida: guida,
                                  onLeggi: () {
                                    final k = _elenco.indexWhere((e) => e.$1 == 'citta');
                                    if (k >= 0) _schede?.animateTo(k);
                                  },
                                )
                              : null,
                          carica: (prima) async {
                            final pg = await stato.api.feed(s.$1, prima: prima);
                            if (pg.notifiche != null) stato.impostaNotifiche(pg.notifiche!);
                            return (pg.post, pg.altri);
                          },
                          vuoto: Vuoto(
                            icona: Icons.forum_outlined,
                            testo: switch (s.$1) {
                              'seguiti' => 'Qui trovi i post delle persone che segui. Cerca i tuoi vicini e seguili.',
                              'citta' => 'Qui arrivano i post che le tribù rilanciano a tutta Napoli col tam-tam.',
                              'area' => "Qui arrivano i post rilanciati a tutta l'area metropolitana.",
                              _ => 'Ancora nessun post. Racconta qualcosa al tuo quartiere!',
                            },
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _attesa(Map<String, dynamic> casa) => Material(
    color: oro.withValues(alpha: .12),
    child: InkWell(
      onTap: () => apriQuartiere(context, '${casa['slug']}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded, color: oro, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Residenza in attesa a ${casa['nome']}. ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: 'Servono ${stato.io!.viciniGaranti} già confermati che garantiscano per te: poi potrai pubblicare.'),
                  ],
                ),
                style: const TextStyle(fontSize: 13, color: testo2, height: 1.35),
              ),
            ),
            const Icon(Icons.chevron_right, color: muto),
          ],
        ),
      ),
    ),
  );

  Widget _senzaCasa() => Material(
    color: terracotta.withValues(alpha: .12),
    child: InkWell(
      onTap: () => stato.apri({'tipo': 'mappa'}),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Icon(Icons.home_outlined, color: terracotta, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Scegli il tuo quartiere sulla mappa: è la tua tribù, lì potrai scrivere.',
                style: TextStyle(fontSize: 13, color: testo2, height: 1.35),
              ),
            ),
            Icon(Icons.chevron_right, color: muto),
          ],
        ),
      ),
    ),
  );
}
