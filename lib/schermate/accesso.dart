// Benvenuto, accesso e iscrizione (stesse regole del sito: nome vero, quartiere o comune, 14 anni e consensi).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/push.dart';
import '../dati/stato.dart';
import '../tema.dart';
import 'legale.dart';

class SchermataBenvenuto extends StatelessWidget {
  const SchermataBenvenuto({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        // aloni caldi dietro, come l'aurora del sito
        Positioned(
          top: -120,
          right: -100,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [terracotta.withValues(alpha: .35), terracotta.withValues(alpha: 0)]),
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          left: -120,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [oro.withValues(alpha: .22), oro.withValues(alpha: 0)]),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(child: emblema(130)),
                const SizedBox(height: 18),
                const Center(child: Marchio(misura: 48)),
                const SizedBox(height: 12),
                Text(
                  'Ogni quartiere una voce,\ninsieme una città.',
                  textAlign: TextAlign.center,
                  style: titolo(22, colore: testo2, peso: FontWeight.w600, altezza: 1.25),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tribus + urbs: la tribù della città. Scrivi nel tuo quartiere, garantisci per i vicini veri, '
                  'fai girare le notizie con il tam-tam fino a tutta Napoli.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muto, height: 1.45, fontSize: 14),
                ),
                const Spacer(flex: 2),
                BottoneCaldo(
                  testo: 'Iscriviti',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SchermataIscrizione())),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SchermataAccesso())),
                  child: const Text('Ho già un account'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class SchermataAccesso extends StatefulWidget {
  const SchermataAccesso({super.key});

  @override
  State<SchermataAccesso> createState() => _SchermataAccessoState();
}

class _SchermataAccessoState extends State<SchermataAccesso> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _vedi = false;
  bool _invio = false;
  String? _errore;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _entra() async {
    setState(() {
      _invio = true;
      _errore = null;
    });
    try {
      final io = await stato.api.accedi(_id.text.trim(), _pw.text);
      stato.entra(io);
      collegaPush();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    } finally {
      if (mounted) setState(() => _invio = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Center(child: emblema(72)),
        const SizedBox(height: 12),
        Text('Bentornato', style: titolo(30), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        const Text(
          'Entra con il tuo account triburba.',
          style: TextStyle(color: muto),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _id,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Username o email', prefixIcon: Icon(Icons.person_outline)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pw,
          obscureText: !_vedi,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _entra(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _vedi = !_vedi),
              icon: Icon(_vedi ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              tooltip: _vedi ? 'Nascondi la password' : 'Mostra la password',
            ),
          ),
        ),
        if (_errore != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_errore!, style: const TextStyle(color: pompeiano)),
          ),
        const SizedBox(height: 20),
        BottoneCaldo(testo: 'Entra', occupato: _invio, onPressed: _entra),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => launchUrl(Uri.parse('mailto:info@triburba.it?subject=Password%20dimenticata')),
          child: const Text('Password dimenticata? Scrivici'),
        ),
      ],
    ),
  );
}

class SchermataIscrizione extends StatefulWidget {
  const SchermataIscrizione({super.key});

  @override
  State<SchermataIscrizione> createState() => _SchermataIscrizioneState();
}

class _SchermataIscrizioneState extends State<SchermataIscrizione> {
  final _nome = TextEditingController();
  final _cognome = TextEditingController();
  final _user = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _altro = TextEditingController();
  DatiIscrizione? _dati;
  String? _scelta; // id quartiere, «c<id>» comune spento, «altro»
  String? _sceltaNome;
  bool _eta = false, _consenso = false, _invio = false, _vedi = false;
  String? _errore;
  final _tocchi = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    stato.api
        .datiIscrizione()
        .then((d) {
          if (mounted) setState(() => _dati = d);
        })
        .catchError((Object e) {
          if (mounted) setState(() => _errore = '$e');
        });
  }

  @override
  void dispose() {
    for (final c in [_nome, _cognome, _user, _email, _pw, _altro]) {
      c.dispose();
    }
    for (final t in _tocchi) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _scegli() async {
    final d = _dati;
    if (d == null) return;
    final r = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _SceltaZona(dati: d),
    );
    if (r != null) {
      setState(() {
        _scelta = r.$1;
        _sceltaNome = r.$2;
      });
    }
  }

  Future<void> _iscriviti() async {
    setState(() {
      _invio = true;
      _errore = null;
    });
    try {
      final (io, msg) = await stato.api.iscriviti({
        'nome': _nome.text.trim(),
        'cognome': _cognome.text.trim(),
        'username': _user.text.trim(),
        'email': _email.text.trim(),
        'password': _pw.text,
        'quartiere': _scelta ?? '',
        'citta_altro': _altro.text.trim(),
        'eta': _eta ? 1 : 0,
        'consenso': _consenso ? 1 : 0,
      });
      stato.entra(io);
      collegaPush();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      if (msg.isNotEmpty) messaggio(context, msg);
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    } finally {
      if (mounted) setState(() => _invio = false);
    }
  }

  TapGestureRecognizer _link(String percorso) {
    // regolamento, termini e privacy si leggono dentro l'app
    final pagina = percorso.replaceAll('/', '');
    final t = TapGestureRecognizer()
      ..onTap = () => pagineLegali.containsKey(pagina) ? apriLegale(context, pagina) : launchUrl(Uri.parse('$sito$percorso'), mode: LaunchMode.externalApplication);
    _tocchi.add(t);
    return t;
  }

  @override
  Widget build(BuildContext context) {
    const stileLink = TextStyle(color: golfo, fontWeight: FontWeight.w700);
    return Scaffold(
      appBar: AppBar(title: const Text('Iscriviti')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        children: [
          const Text(
            'Su triburba si usa il nome vero: i vicini devono riconoscerti per garantire che abiti davvero lì.',
            style: TextStyle(color: testo2, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nome,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _cognome,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Cognome'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // dove abito
          InkWell(
            onTap: _scegli,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Dove abiti', prefixIcon: Icon(Icons.place_outlined)),
              child: Text(
                _sceltaNome ?? (_dati == null ? 'Carico i quartieri…' : 'Scegli quartiere o comune'),
                style: TextStyle(color: _sceltaNome == null ? muto : testo),
              ),
            ),
          ),
          if (_scelta == 'altro') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _altro,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'La tua città'),
            ),
          ],
          if (_scelta != null && _scelta!.startsWith('c'))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Il comune non è ancora aperto: la tua iscrizione vale come richiesta. A ${_dati?.soglia ?? 20} richieste si accende.',
                style: const TextStyle(color: oro, fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _user,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Username', helperText: '3-32 caratteri: lettere, numeri, punto e trattino basso'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pw,
            obscureText: !_vedi,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: 'Almeno 8 caratteri',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _vedi = !_vedi),
                icon: Icon(_vedi ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                tooltip: _vedi ? 'Nascondi la password' : 'Mostra la password',
              ),
            ),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _eta,
            onChanged: (v) => setState(() => _eta = v == true),
            title: const Text('Ho almeno 14 anni', style: TextStyle(fontSize: 14)),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _consenso,
            onChanged: (v) => setState(() => _consenso = v == true),
            title: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 14, height: 1.35),
                children: [
                  const TextSpan(text: 'Accetto il '),
                  TextSpan(text: 'Regolamento', style: stileLink, recognizer: _link('/regolamento')),
                  const TextSpan(text: ', i '),
                  TextSpan(text: 'Termini', style: stileLink, recognizer: _link('/termini')),
                  const TextSpan(text: ' e ho letto la '),
                  TextSpan(text: 'Privacy', style: stileLink, recognizer: _link('/privacy')),
                ],
              ),
            ),
          ),
          if (_errore != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_errore!, style: const TextStyle(color: pompeiano)),
            ),
          const SizedBox(height: 16),
          BottoneCaldo(testo: 'Crea il mio account', occupato: _invio, onPressed: (_eta && _consenso) ? _iscriviti : null),
        ],
      ),
    );
  }
}

/// Scelta del quartiere acceso, del comune da aprire o «la mia città non c'è», con ricerca.
class _SceltaZona extends StatefulWidget {
  const _SceltaZona({required this.dati});

  final DatiIscrizione dati;

  @override
  State<_SceltaZona> createState() => _SceltaZonaState();
}

class _SceltaZonaState extends State<_SceltaZona> {
  String _q = '';

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[àá]'), 'a')
      .replaceAll(RegExp('[èé]'), 'e')
      .replaceAll(RegExp('[ìí]'), 'i')
      .replaceAll(RegExp('[òó]'), 'o')
      .replaceAll(RegExp('[ùú]'), 'u');

  bool _va(String nome) => _q.isEmpty || _norm(nome).contains(_norm(_q));

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .8,
    maxChildSize: .95,
    builder: (c, scorri) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(hintText: 'Cerca quartiere o comune…', prefixIcon: Icon(Icons.search), isDense: true),
          ),
        ),
        Expanded(
          child: ListView(
            controller: scorri,
            children: [
              for (final g in widget.dati.gruppi)
                if (g.$2.any((q) => _va(q.$2))) ...[
                  _titolo(g.$1),
                  for (final q in g.$2.where((q) => _va(q.$2)))
                    ListTile(
                      leading: CircleAvatar(radius: 8, backgroundColor: colore(q.$3)),
                      title: Text(q.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                      onTap: () => Navigator.pop(context, (q.$1, q.$2)),
                    ),
                ],
              if (widget.dati.spenti.any((c) => _va(c.$2))) _titolo('Non ancora aperti'),
              for (final x in widget.dati.spenti.where((c) => _va(c.$2)).take(_q.isEmpty ? 12 : 60))
                ListTile(
                  leading: const Icon(Icons.wb_twilight_rounded, color: muto, size: 20),
                  title: Text(x.$2),
                  subtitle: Text('${x.$3}/${widget.dati.soglia} richieste', style: const TextStyle(color: muto, fontSize: 12)),
                  onTap: () => Navigator.pop(context, (x.$1, '${x.$2} (da aprire)')),
                ),
              ListTile(
                leading: const Icon(Icons.travel_explore_rounded, color: oro),
                title: const Text('La mia città non c\'è'),
                onTap: () => Navigator.pop(context, ('altro', 'Un\'altra città')),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _titolo(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Text(
      t.toUpperCase(),
      style: const TextStyle(color: muto, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6),
    ),
  );
}
