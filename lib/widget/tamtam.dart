// Tam-tam: far girare un post alle altre tribù (un quartiere, una municipalità) o rilanciarlo a tutta la città.
import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../tema.dart';

Mappa? _mappaInMemoria;

Future<Mappa> mappaInMemoria({bool ricarica = false}) async {
  if (_mappaInMemoria == null || ricarica) _mappaInMemoria = await stato.api.mappa();
  return _mappaInMemoria!;
}

/// Ritorna true se il post è cambiato (tam-tam fatto o ritirato).
Future<bool> apriTamtam(BuildContext context, Post p) async {
  final t = stato.io?.tamtam ?? const {};
  final dest = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .62,
      maxChildSize: .92,
      builder: (c, scorri) => FutureBuilder<Mappa>(
        future: mappaInMemoria(),
        builder: (c, s) {
          final m = s.data;
          return ListView(
            controller: scorri,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Row(
                children: [
                  const Icon(Icons.campaign_outlined, color: oro, size: 28),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Tam-tam', style: titolo(24))),
                ],
              ),
              const SizedBox(height: 4),
              Text('Fai girare il post ${t['titolo'] ?? 'alle altre tribù'}.', style: const TextStyle(color: testo2)),
              const SizedBox(height: 14),
              // tutta la città: il rilancio conta come un voto
              _Opzione(
                icona: Icons.location_city,
                colore: oro,
                titolo: p.citta ? 'È già arrivato a tutta Napoli' : (t['grande'] ?? 'A tutta Napoli'),
                testo: p.mioRilancio ? 'Hai già rilanciato: tocca per ritirare il tuo voto.' : (t['nota'] ?? ''),
                attivo: !p.citta || p.mioRilancio,
                evidenza: p.mioRilancio,
                ritira: p.mioRilancio,
                onTap: () => Navigator.pop(c, 'c:1'),
              ),
              const SizedBox(height: 16),
              Text(
                (t['vicino'] ?? 'Negli altri quartieri').toUpperCase(),
                style: const TextStyle(color: muto, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .6),
              ),
              const SizedBox(height: 4),
              const Text(
                'Arriva quando un residente di lì lo accetta (nella tua municipalità subito).',
                style: TextStyle(color: muto, fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              if (m == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                for (final mu in m.municipalita)
                  _Opzione(
                    icona: Icons.layers_outlined,
                    colore: golfo,
                    titolo: mu.nome,
                    testo: 'Tutti i quartieri della municipalità',
                    evidenza: p.mieiTamtam.contains('m:${mu.id}'),
                    ritira: p.mieiTamtam.contains('m:${mu.id}'),
                    onTap: () => Navigator.pop(c, 'm:${mu.id}'),
                  ),
                for (final q in m.tutti.where((q) => q.nome != p.quartiere?.nome))
                  _Opzione(
                    icona: Icons.place_outlined,
                    colore: colore(q.colore),
                    titolo: q.nome,
                    testo: q.citta == 'Napoli' ? '${q.residenti} residenti' : q.citta,
                    evidenza: p.mieiTamtam.contains('q:${q.id}'),
                    ritira: p.mieiTamtam.contains('q:${q.id}'),
                    onTap: () => Navigator.pop(c, 'q:${q.id}'),
                  ),
              ],
            ],
          );
        },
      ),
    ),
  );
  if (dest == null || !context.mounted) return false;
  final ritira = dest == 'c:1' ? p.mioRilancio : p.mieiTamtam.contains(dest);
  try {
    if (ritira) {
      final j = await stato.api.ritiraTamtam(p.id, dest);
      p.mieiTamtam.remove(dest);
      if (j['citta'] == true) {
        p.mioRilancio = false;
        p.rilanci = (j['rilanci'] as num? ?? 0).toInt();
        p.citta = j['arrivato'] == true;
      } else {
        p.portate.removeWhere((x) => x.nome == '${j['nome']}');
      }
      if (context.mounted) messaggio(context, (j['msg'] ?? 'Tam-tam ritirato').toString());
      return true;
    }
    final msg = await stato.api.tamtam(p.id, dest);
    if (!p.mieiTamtam.contains(dest)) p.mieiTamtam.add(dest);
    if (dest == 'c:1') {
      p.mioRilancio = true;
      p.rilanci += 1;
    }
    if (context.mounted) messaggio(context, msg);
    return true;
  } on ErroreApi catch (e) {
    if (context.mounted) messaggio(context, e.messaggio);
    return false;
  }
}

class _Opzione extends StatelessWidget {
  const _Opzione({
    required this.icona,
    required this.colore,
    required this.titolo,
    required this.testo,
    required this.onTap,
    this.attivo = true,
    this.evidenza = false,
    this.ritira = false,
  });

  final IconData icona;
  final Color colore;
  final String titolo, testo;
  final VoidCallback onTap;
  final bool attivo, evidenza;

  /// Tam-tam già fatto da me: mostra «RITIRA» e toccandolo si annulla.
  final bool ritira;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: evidenza ? colore.withValues(alpha: .16) : superficie2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: ritira ? BorderSide(color: terracotta.withValues(alpha: .6)) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: attivo ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: colore.withValues(alpha: .18), borderRadius: BorderRadius.circular(10)),
                child: Icon(icona, color: colore),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titolo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    if (testo.isNotEmpty) Text(testo, style: const TextStyle(color: testo2, fontSize: 12.5, height: 1.3)),
                  ],
                ),
              ),
              if (ritira)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: terracotta.withValues(alpha: .18), borderRadius: BorderRadius.circular(99)),
                  child: const Text(
                    'RITIRA',
                    style: TextStyle(color: terracotta, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
