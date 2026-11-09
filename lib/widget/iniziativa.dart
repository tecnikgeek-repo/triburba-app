// Attività e sondaggi dentro la card di un post, come sul sito.
// Attività: «Ci sarò» finché è aperta; parte solo se entro la data limite si arriva al minimo di persone.
// Sondaggio: una o più risposte, risultati visibili dopo aver votato (o a sondaggio chiuso).
import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../tema.dart';
import 'faccia.dart';

class BloccoIniziativa extends StatefulWidget {
  const BloccoIniziativa({super.key, required this.post, required this.onCambiato});

  final Post post;

  /// Dopo un'azione: il post riletto dal sito è già nei campi di [post], basta ridisegnare.
  final VoidCallback onCambiato;

  @override
  State<BloccoIniziativa> createState() => _BloccoIniziativaState();
}

class _BloccoIniziativaState extends State<BloccoIniziativa> {
  Post get p => widget.post;
  bool _occupato = false;
  final Set<int> _scelte = {};

  bool get _mio => p.autore.username == stato.io?.username;

  Future<void> _esegui(Future<String> Function() azione) async {
    if (_occupato) return;
    setState(() => _occupato = true);
    try {
      final msg = await azione();
      final nuovo = await stato.api.leggiPost(p.id);
      p.attivita = nuovo.attivita;
      p.sondaggio = nuovo.sondaggio;
      _scelte.clear();
      widget.onCambiato();
      if (mounted && msg.isNotEmpty) messaggio(context, msg);
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _occupato = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = p.attivita;
    final s = p.sondaggio;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [terracotta.withValues(alpha: .14), superficie2.withValues(alpha: .6)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: terracotta.withValues(alpha: .3)),
      ),
      child: a != null ? _attivita(a) : (s != null ? _sondaggio(s) : const SizedBox.shrink()),
    );
  }

  Widget _icona(IconData i) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(gradient: gradienteBottone, borderRadius: BorderRadius.circular(9)),
    child: Icon(i, color: Colors.white, size: 22),
  );

  Widget _etichetta(String t) => Text(
    t.toUpperCase(),
    style: const TextStyle(color: oro, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1),
  );

  // ── Attività ──

  Widget _attivita(Attivita a) {
    final (Color colSt, String st) = switch (a.stato) {
      'annullata' => (pompeiano, 'Non è partita'),
      'parte' when a.passata => (golfo, 'Fatta'),
      'parte' => (const Color(0xFF4ADE80), 'Si fa!'),
      _ => (testo2, 'Conferme entro ${a.scadenza}'),
    };
    final quota = a.minimo == 0 ? 0.0 : (a.n / a.minimo).clamp(0.0, 1.0);
    return Opacity(
      opacity: a.stato == 'annullata' ? .8 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _icona(Icons.handshake_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _etichetta('Attività'),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.event_outlined, size: 16, color: testo2),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(_maiuscola(a.quando), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                        ),
                      ],
                    ),
                    if (a.luogo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 15, color: muto),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(a.luogo!, style: const TextStyle(color: testo2, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: colSt.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
            child: Text(
              a.stato == 'annullata' ? '$st: ${a.n} su ${a.minimo}' : st,
              style: TextStyle(color: colSt, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${a.n}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: testo),
                ),
                TextSpan(text: ' su ${a.minimo} ${a.minimo == 1 ? 'persona' : 'persone'} ci saranno'),
              ],
            ),
            style: const TextStyle(color: testo2, fontSize: 14),
          ),
          const SizedBox(height: 6),
          _barra(quota),
          if (a.facce.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  for (var i = 0; i < a.facce.length; i++)
                    Align(
                      widthFactor: i == a.facce.length - 1 ? 1 : .8,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: superficie, width: 2),
                        ),
                        child: FotoProfilo(faccia: a.facce[i], lato: 28),
                      ),
                    ),
                  if (a.n > a.facce.length)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '+${a.n - a.facce.length}',
                        style: const TextStyle(color: testo2, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (a.aperta && !_mio) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: a.ciSono
                  ? OutlinedButton.icon(
                      onPressed: _occupato ? null : () => _esegui(() => stato.api.partecipa(p.id)),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Ci sarai · tocca per ritirarti'),
                    )
                  : BottoneCaldo(
                      testo: 'Ci sarò',
                      icona: Icons.handshake_outlined,
                      occupato: _occupato,
                      onPressed: () => _esegui(() => stato.api.partecipa(p.id)),
                    ),
            ),
          ] else if (a.aperta && _mio && a.stato == 'raccolta') ...[
            const SizedBox(height: 10),
            Text(
              'Se entro ${a.scadenza} non arrivate a ${a.minimo}, l\'attività non parte e avvisiamo tutti.',
              style: const TextStyle(color: muto, fontSize: 12.5, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  // ── Sondaggio ──

  Widget _sondaggio(Sondaggio s) {
    final somma = s.opzioni.fold<int>(0, (t, o) => t + (o.voti ?? 0));
    final sotto = ['${s.votanti} ${s.votanti == 1 ? 'voto' : 'voti'}', if (s.chiude != null) s.chiude!].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _icona(Icons.how_to_vote_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _etichetta(['Sondaggio', if (s.multi) 'più risposte', if (s.soloResidenti) 'solo residenti'].join(' · ')),
                  const SizedBox(height: 2),
                  Text(sotto, style: const TextStyle(color: testo2, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final o in s.opzioni) _opzione(s, o, somma),
        if (s.puo && (s.multi || s.votato)) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (s.multi)
                FilledButton.icon(
                  onPressed: _occupato || _scelte.isEmpty ? null : () => _esegui(() => stato.api.vota(p.id, _scelte.toList())),
                  icon: const Icon(Icons.how_to_vote_outlined, size: 18),
                  label: Text(s.votato ? 'Cambia voto' : 'Vota'),
                ),
              if (s.votato)
                OutlinedButton(
                  onPressed: _occupato ? null : () => _esegui(() => stato.api.vota(p.id, const [])),
                  child: const Text('Togli il voto'),
                ),
            ],
          ),
        ],
        if (s.puo && !s.risultati)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('I risultati si vedono dopo aver votato.', style: TextStyle(color: muto, fontSize: 12.5)),
          ),
        if (!s.puo && s.motivo != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(s.motivo!, style: const TextStyle(color: muto, fontSize: 12.5)),
          ),
      ],
    );
  }

  Widget _opzione(Sondaggio s, OpzioneSondaggio o, int somma) {
    final scelta = s.multi && _scelte.isNotEmpty ? _scelte.contains(o.id) : o.mia;
    final quota = s.risultati && somma > 0 ? (o.voti ?? 0) / somma : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: superficie2,
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: !s.puo || _occupato
              ? null
              : () {
                  if (s.multi) {
                    setState(() {
                      if (_scelte.isEmpty) _scelte.addAll(s.opzioni.where((x) => x.mia).map((x) => x.id));
                      _scelte.contains(o.id) ? _scelte.remove(o.id) : _scelte.add(o.id);
                    });
                  } else if (!o.mia) {
                    _esegui(() => stato.api.vota(p.id, [o.id]));
                  }
                },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: scelta ? terracotta : linea2),
            ),
            child: Stack(
              children: [
                if (s.risultati)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: quota,
                      child: ColoredBox(color: terracotta.withValues(alpha: o.mia ? .34 : .2)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(
                    children: [
                      if (s.puo && s.multi)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            scelta ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            size: 20,
                            color: scelta ? terracotta : muto,
                          ),
                        ),
                      Expanded(
                        child: Text(o.testo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                      if (s.risultati) Text('${(quota * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (o.mia)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.check_rounded, size: 18, color: terracotta),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _barra(double quota) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      width: double.infinity,
      height: 8,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: superficie2),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: quota,
            child: const DecoratedBox(decoration: BoxDecoration(gradient: gradiente)),
          ),
        ],
      ),
    ),
  );

  String _maiuscola(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}
