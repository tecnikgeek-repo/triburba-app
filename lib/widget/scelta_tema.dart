// Scelta del tema: 5 scuri e 5 chiari, gli stessi del sito. Si salva sul telefono e sull'account.
import 'package:flutter/material.dart';

import '../dati/stato.dart';
import '../tema.dart';

Future<void> apriSceltaTema(BuildContext context) async {
  final scelto = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (s) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tema', style: titolo(22)),
            const SizedBox(height: 4),
            Text('Vale sul sito e su ogni telefono da cui entri.', style: TextStyle(color: muto, fontSize: 13)),
            for (final scure in [true, false]) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  scure ? 'SCURI' : 'CHIARI',
                  style: TextStyle(color: muto, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6),
                ),
              ),
              for (final t in tinte.where((x) => x.scura == scure)) _Campione(t, onTap: () => Navigator.pop(s, t.id)),
            ],
          ],
        ),
      ),
    ),
  );
  if (scelto == null || scelto == tinta.id) return;
  // sull'account (in sottofondo), poi il cambio: l'app si ridisegna con i colori nuovi
  stato.api.salvaTema(scelto).catchError((_) {});
  impostaTinta(scelto);
}

class _Campione extends StatelessWidget {
  const _Campione(this.t, {required this.onTap});

  final Tinta t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = t.id == tinta.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: t.fondo,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? t.accento : t.testo.withValues(alpha: .14), width: on ? 2 : 1),
            ),
            child: Row(
              children: [
                // il «campione»: superficie con il colore principale e il secondo
                Container(
                  width: 54,
                  height: 38,
                  decoration: BoxDecoration(color: t.sup, borderRadius: BorderRadius.circular(9)),
                  padding: const EdgeInsets.all(7),
                  child: Row(
                    children: [
                      Expanded(child: DecoratedBox(decoration: BoxDecoration(color: t.accento, borderRadius: BorderRadius.circular(5)))),
                      const SizedBox(width: 4),
                      Expanded(child: DecoratedBox(decoration: BoxDecoration(color: t.secondo, borderRadius: BorderRadius.circular(5)))),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.nome, style: TextStyle(color: t.testo, fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(t.nota, style: TextStyle(color: t.muto, fontSize: 12.5)),
                    ],
                  ),
                ),
                if (on) Icon(Icons.check_circle_rounded, color: t.accento),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
