// Tappe del tam-tam sotto il post (27/11/2026), come sul sito: il posto d'origine, poi Napoli, la provincia, la Campania.
// Piena = raggiunta, cerchio che si riempie = in corso, vuota = da fare. Sempre su una riga, i nomi lunghi vanno a capo.
import 'package:flutter/material.dart';
import '../dati/modelli.dart';
import '../schermate/naviga.dart';
import '../tema.dart';
import 'icona_tk.dart';

class TappeTamtam extends StatelessWidget {
  const TappeTamtam({super.key, required this.tappe, required this.colore});

  final List<Tappa> tappe;

  /// colore del quartiere o comune d'origine
  final Color colore;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 2, 14, 10),
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
    decoration: BoxDecoration(color: superficie2, borderRadius: BorderRadius.circular(10), border: Border.all(color: linea)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (var i = 0; i < tappe.length; i++) Expanded(child: _tappa(context, i))],
    ),
  );

  /// Linea tra la tappa prima e questa: colorata se questa è raggiunta, a metà se è in corso con qualche rilancio.
  Color _lineaPrima(int i) {
    final t = tappe[i];
    if (t.stato == 'fatta') return oro;
    if (t.stato == 'corso' && t.n > 0) return oro.withValues(alpha: .55);
    return linea2;
  }

  Widget _tappa(BuildContext context, int i) {
    final t = tappe[i];
    final primo = i == 0, ultimo = i == tappe.length - 1;
    final fatta = t.stato == 'fatta', corso = t.stato == 'corso';
    final nome = Text(
      t.nome,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w700, color: fatta || corso ? testo : testo2),
    );
    return Tooltip(
      message: t.titolo,
      child: Column(
        children: [
          SizedBox(
            height: 24,
            child: Row(
              children: [
                Expanded(child: Container(height: 2, color: primo ? Colors.transparent : _lineaPrima(i))),
                _pallino(t),
                Expanded(child: Container(height: 2, color: ultimo ? Colors.transparent : _lineaPrima(i + 1))),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: t.origine && t.slug != null ? GestureDetector(onTap: () => apriQuartiere(context, t.slug!), child: nome) : nome,
          ),
          const SizedBox(height: 3),
          Text(
            t.info.isEmpty ? ' ' : t.info,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: corso ? oro : (fatta ? testo2 : muto)),
          ),
        ],
      ),
    );
  }

  Widget _pallino(Tappa t) {
    if (t.origine) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: colore, shape: BoxShape.circle),
        child: const Icon(Icons.place_outlined, size: 14, color: Colors.white),
      );
    }
    if (t.stato == 'fatta') {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(gradient: gradiente, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 14, color: Color(0xFF1A110C)),
      );
    }
    if (t.stato == 'corso') {
      return SizedBox(
        width: 24,
        height: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(decoration: BoxDecoration(color: superficie, shape: BoxShape.circle)),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: t.soglia > 0 ? (t.n / t.soglia).clamp(0.0, 1.0) : 0,
                strokeWidth: 2.4,
                color: oro,
                backgroundColor: oro.withValues(alpha: .25),
              ),
            ),
            IconaTk('tamtam', lato: 13, colore: oro),
          ],
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(color: superficie, shape: BoxShape.circle, border: Border.all(color: linea2, width: 2)),
    );
  }
}
