// La mappa delle tribù, come sul web: la regione sotto, le zone spente in grigio, quelle accese a colori
// (lib/widget/mappa_disegno.dart). Sotto, l'elenco dei quartieri accesi e le zone da far accendere.
import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/mappa_disegno.dart';
import '../widget/tamtam.dart';
import 'naviga.dart';

class SchermataMappa extends StatefulWidget {
  const SchermataMappa({super.key});

  @override
  State<SchermataMappa> createState() => _SchermataMappaState();
}

class _SchermataMappaState extends State<SchermataMappa> {
  Mappa? _m;
  String? _errore;
  String _filtroComuni = '';

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    try {
      final m = await mappaInMemoria(ricarica: true);
      if (mounted) {
        setState(() {
          _m = m;
          _errore = null;
        });
      }
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  Future<void> _chiedi(String chiave) async {
    try {
      final j = await stato.api.chiediZona(chiave);
      if (!mounted) return;
      messaggio(context, '${j['msg']}');
      _carica();
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    return Scaffold(
      appBar: AppBar(title: const Text('Mappa')),
      body: m == null
          ? Center(
              child: _errore == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errore!, style: const TextStyle(color: testo2)),
                        const SizedBox(height: 10),
                        OutlinedButton(onPressed: _carica, child: const Text('Riprova')),
                      ],
                    ),
            )
          : RefreshIndicator(
              onRefresh: _carica,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                children: [
                  MappaDisegno(mappa: m, onApri: (q) => apriQuartiere(context, q.slug)),
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 14),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'Confini © '),
                          TextSpan(text: 'OpenStreetMap', style: TextStyle(color: testo2, fontWeight: FontWeight.w600)),
                          TextSpan(text: ' ·\nISTAT via '),
                          TextSpan(text: 'openpolis', style: TextStyle(color: testo2, fontWeight: FontWeight.w600)),
                          TextSpan(text: ' · CC-BY 4.0'),
                        ],
                      ),
                      style: TextStyle(color: muto, fontSize: 11, height: 1.6, fontFamily: fontTesto),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (m.giorniCambio > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Potrai cambiare quartiere di casa tra ${m.giorniCambio} giorni.',
                        style: const TextStyle(color: muto, fontSize: 12.5),
                      ),
                    ),
                  for (final g in m.gruppi) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                      child: Text(
                        g.$1.toUpperCase(),
                        style: const TextStyle(color: muto, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6),
                      ),
                    ),
                    for (final q in g.$2) _rigaQuartiere(q, m),
                  ],
                  const SizedBox(height: 18),
                  _comuni(m),
                ],
              ),
            ),
    );
  }

  Widget _rigaQuartiere(QuartiereMappa q, Mappa m) {
    final casa = m.casa == q.id;
    final segui = m.seguiti.contains(q.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: superficie,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => apriQuartiere(context, q.slug),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: colore(q.colore), width: 4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.nome, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      Text(
                        '${q.residenti} residenti · ${q.post} post${q.citta != 'Napoli' ? ' · ${q.citta}' : ''}',
                        style: const TextStyle(color: muto, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                if (casa) const Chip2(testo: 'Casa', icona: Icons.home_rounded, colore: terracotta),
                if (!casa && segui) const Chip2(testo: 'Segui', icona: Icons.check, colore: golfo),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: muto),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _comuni(Mappa m) {
    final lista = m.spenti.where((c) => _filtroComuni.isEmpty || c.nome.toLowerCase().contains(_filtroComuni.toLowerCase())).toList();
    return Carta(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_twilight_rounded, color: oro),
              const SizedBox(width: 8),
              Expanded(child: Text('Accendi la tua zona', style: titolo(19))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'I quartieri di Napoli e i comuni dell\'area metropolitana restano nella nebbia finché non li chiede '
            'abbastanza gente: a ${m.sogliaApertura} richieste si accendono da soli sulla mappa.',
            style: const TextStyle(color: testo2, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _filtroComuni = v),
            decoration: const InputDecoration(hintText: 'Cerca il quartiere o il comune…', prefixIcon: Icon(Icons.search), isDense: true),
          ),
          const SizedBox(height: 6),
          for (final c in lista.take(_filtroComuni.isEmpty ? 8 : 40))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: (c.richieste / m.sogliaApertura).clamp(0, 1), minHeight: 5, color: oro),
              ),
              trailing: TextButton(
                onPressed: () => _chiedi(c.chiave),
                child: Text(c.mia ? 'Ritira ${c.richieste}/${m.sogliaApertura}' : 'Chiedi ${c.richieste}/${m.sogliaApertura}'),
              ),
            ),
        ],
      ),
    );
  }
}
