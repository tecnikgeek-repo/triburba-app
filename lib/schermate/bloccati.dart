// Persone bloccate: chi hai bloccato non vede i tuoi post e tu non vedi i suoi; da qui si sblocca.
import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/faccia.dart';

/// Blocca o sblocca una persona (chiede conferma per il blocco). Ritorna true se è andata.
Future<bool> bloccaPersona(BuildContext context, String username, String nome, {bool sblocca = false}) async {
  if (!sblocca &&
      !await conferma(
        context,
        'Bloccare $nome?',
        'Non vedrai più i suoi post e commenti, e non potrà più commentarti, citarti o seguirti. '
            'Non riceve nessun avviso e puoi sbloccarlo quando vuoi da Impostazioni → Persone bloccate.',
      )) {
    return false;
  }
  try {
    final j = await stato.api.blocca(username, sblocca: sblocca);
    if (context.mounted) messaggio(context, '${j['msg'] ?? (sblocca ? 'Sbloccato.' : 'Bloccato.')}');
    return true;
  } on ErroreApi catch (e) {
    if (context.mounted) messaggio(context, e.messaggio);
    return false;
  }
}

class SchermataBloccati extends StatefulWidget {
  const SchermataBloccati({super.key, this.iniziali});

  /// Solo per le anteprime: elenco già pronto, senza rete.
  final List<Map<String, dynamic>>? iniziali;

  @override
  State<SchermataBloccati> createState() => _SchermataBloccatiState();
}

class _SchermataBloccatiState extends State<SchermataBloccati> {
  List<Map<String, dynamic>>? _persone;
  String? _errore;

  @override
  void initState() {
    super.initState();
    if (widget.iniziali != null) {
      _persone = widget.iniziali;
    } else {
      _carica();
    }
  }

  Future<void> _carica() async {
    try {
      final j = await stato.api.bloccati();
      if (mounted) setState(() => _persone = (j['persone'] as List).cast<Map<String, dynamic>>());
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _persone;
    return Scaffold(
      appBar: AppBar(title: const Text('Persone bloccate')),
      body: p == null
          ? Center(child: _errore == null ? const CircularProgressIndicator(color: terracotta) : Text(_errore!, style: const TextStyle(color: muto)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Chi blocchi non vede i tuoi post e i tuoi commenti, e tu non vedi i suoi; non può commentarti, citarti né seguirti. '
                  'Non riceve nessun avviso. Per bloccare qualcuno usa «Blocca» sul suo profilo o nel menu dei suoi post.',
                  style: TextStyle(color: muto, height: 1.4),
                ),
                const SizedBox(height: 16),
                if (p.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Row(
                      children: [
                        Icon(Icons.check_rounded, color: golfo),
                        SizedBox(width: 8),
                        Text('Non hai bloccato nessuno.'),
                      ],
                    ),
                  ),
                for (final x in p)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: FotoProfilo.da(nome: '${x['nome']}', avatar: x['avatar'] as String?, lato: 42),
                    title: Text('${x['nome']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('@${x['username']}', style: const TextStyle(color: muto)),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        if (await bloccaPersona(context, '${x['username']}', '${x['nome']}', sblocca: true) && mounted) {
                          setState(() => p.remove(x));
                        }
                      },
                      child: const Text('Sblocca'),
                    ),
                  ),
              ],
            ),
    );
  }
}
