// triburba-ai nell'app (27/11/2026): la stessa schermata di Paydea AI, nei colori di triburba (nero vernice, terracotta, oro tufo, verde Golfo).
// Origine: paydea-app/lib/screens/ai_screen.dart. La domanda diventa un titolo,
// la risposta un piccolo articolo con i link, sotto le pagine e i prodotti usati («Per saperne di più»). Si può mandare
// una foto (anche di un prodotto: la cerca nei negozi) o un vocale di 30 secondi. Risponde paydea.it
// (REST paydea-ai/v1/chat), che cerca nelle sue pagine e nei negozi del circuito e chiede al motore.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dati/api.dart';
import '../dati/stato.dart';
import '../widget/aspetto_ai.dart';

/// Solo se il sito non risponde: di solito le domande suggerite arrivano dal sito, scelte a caso.
const _suggerite = [
  'Come funziona il tam-tam?',
  'Come divento residente del mio quartiere?',
  'Il mio comune non c\'è: come lo accendo?',
  'Quali quartieri e comuni sono accesi?',
];
const _pensando = [
  'Sto pensando',
  'Cerco per te',
  'Sto guardando',
  'Ci sono',
  'Un momento',
  'Mi informo',
  'Sto verificando',
  'Lo sto cercando',
  'Faccio un controllo',
  'Sto mettendo insieme tutto',
  'Vediamo un po\'',
  'Sto ragionando',
  'Ci sto pensando',
  'Do un\'occhiata',
  'Raccolgo le informazioni',
  'Sto scrivendo',
  'Un secondo soltanto',
  'Metto in ordine le idee',
  'Sto trovando le parole',
  'Ancora un istante',
  'Arrivo subito',
  'Ci penso un attimo',
  'Un attimo',
  'Fammi controllare',
  'Sto cercando',
  'Sto leggendo',
  'Cerco la risposta',
  'Controllo un attimo',
  'Preparo la risposta',
  'Verifico subito',
  'Ci guardo subito',
  'Dammi un secondo',
  'Sto controllando',
  'Guardo meglio',
  'Ci sto lavorando',
];
const _quasi = [
  'Ci sono quasi, ancora qualche secondo…',
  'Ci sto mettendo un po\', ma ci arrivo…',
  'È una ricerca lunga, abbi pazienza…',
  'Non mi sono dimenticato di te…',
  'Sto ancora cercando il meglio per te…',
  'Un altro po\' e ti rispondo…',
  'Sto controllando ancora una cosa…',
  'Grazie per la pazienza, quasi ci siamo…',
  'Ancora poco e finisco…',
  'Sto dando gli ultimi ritocchi…',
  'Eccomi quasi, resta con me…',
  'Quasi fatto, un altro momento…',
  'Manca poco, resta qui…',
  'Sto finendo, ancora un attimo…',
  'Ancora qualche secondo e ci siamo…',
];
const _titoliFonti = [
  'Per saperne di più',
  'Forse ti interessa',
  'Guarda anche',
  'Qualcosa in più',
  'Da vedere',
  'Vai più a fondo',
  'Trovi tutto qui',
  'Ecco dove guardare',
  'Ne parliamo anche qui',
  'Vuoi leggere di più?',
  'Altri dettagli',
  'Può tornarti utile',
  'Se ti incuriosisce',
  'Dai uno sguardo',
  'Tutti i dettagli',
  'Puoi vedere anche',
  'Ti lascio questi',
  'Un passo in più',
  'Da qui puoi continuare',
  'Le pagine giuste',
  'Per chi vuole di più',
  'Vuoi più info?',
  'Approfondisci qui',
  'Leggi anche',
  'Vuoi approfondire?',
  'Da leggere',
  'Ti può interessare',
  'Qui trovi di più',
  'Per approfondire',
  'Scopri di più',
  'Continua a leggere',
  'Altre informazioni',
  'Se vuoi saperne di più',
  'Dai un\'occhiata',
  'Può esserti utile',
];
final _caso = math.Random();
String _unaDi(List<String> v) => v[_caso.nextInt(v.length)];
const _turchese = Color(0xFFF0B34A); // oro tufo (nell'originale: turchese)
const _tenue = Color(0xFFC4B3A3);
const _maxStoria = 10;

/// Un turno della conversazione: la domanda (con foto o vocale) e la risposta, quando arriva.
class _Turno {
  _Turno({required this.domanda, this.foto, this.vocale = false});

  String domanda;
  final List<int>? foto;
  final bool vocale;
  RispostaAi? risposta;
  String scritto = ''; // le parole man mano, finché non arriva la risposta definitiva
  final intanto = <String>[]; // i messaggi mentre aspetta: dopo 5 secondi, poi 10, poi 5…
  final titoloFonti = _unaDi(_titoliFonti);
  final chiaveRisposta = GlobalKey(); // con i messaggi d'attesa il turno è lungo: si va alla risposta
  final chiave = GlobalKey(); // per portare la risposta in vista dall'inizio del turno
}

/// Gli auguri di compleanno, sempre diversi.
String fraseAuguri(String nome) => _unaDi([
  'Tanti auguri, $nome! Oggi è il tuo giorno: buon compleanno da tutta triburba!',
  'Buon compleanno, $nome! Che sia una giornata bellissima, con l\'affetto di tutti i tuoi vicini.',
  'Oggi si festeggia te, $nome: tanti auguri di buon compleanno!',
  '$nome, oggi è il tuo compleanno e non potevamo non dirtelo: tantissimi auguri!',
  'Auguri, $nome! Coriandoli tutti per te: buon compleanno!',
]);

class AiScreen extends StatefulWidget {
  const AiScreen({super.key, this.auguri, this.negozioUrl = '', this.negozioNome = ''});

  /// Dentro un negozio la chat è quella del suo minisito: propone solo i suoi prodotti, come sul sito.
  final String negozioUrl, negozioNome;

  /// Se c'è, la chat si apre con questo messaggio e i coriandoli.
  final String? auguri;

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _turni = <_Turno>[];
  final _storia = <Map<String, String>>[];
  final _campo = TextEditingController();
  final _scorri = ScrollController();
  final _fuoco = FocusNode();
  List<int>? _fotoPronta;
  bool _occupato = false;

  // vocale
  // creato solo al primo vocale: costruirlo subito parla col telefono anche a chi non lo usa
  AudioRecorder? _rec;
  AudioRecorder get _registratore => _rec ??= AudioRecorder();
  bool _registra = false;
  DateTime? _inizioVoce;
  Timer? _timerVoce;
  StreamSubscription<Amplitude>? _ampiezza;
  final _onde = ValueNotifier<List<double>>(List.filled(24, .15));
  String _versione = '';
  List<String>? _idee; // le domande suggerite di questa apertura

  void _scegliIdee() {
    final tutte = [..._PdAi.attuale.suggerite]..shuffle();
    _idee = tutte.isEmpty ? _suggerite : tutte.take(_PdAi.attuale.viste).toList();
  }

  @override
  void initState() {
    super.initState();
    _PdAi.attuale = _PdAi.per(widget.negozioUrl);
    if (widget.auguri != null) {
      _turni.add(_Turno(domanda: '')..risposta = RispostaAi(ok: true, testo: widget.auguri!));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _festa();
      });
    }
    // la versione del motore che risponde: la dà il sito, così cambia da sola senza aggiornare l'app
    _PdAi.attuale.chiediVersione().then((v) {
      if (!mounted) return;
      setState(() {
        _versione = v;
        _scegliIdee();
      });
    });
  }

  @override
  void dispose() {
    _campo.dispose();
    _scorri.dispose();
    _fuoco.dispose();
    _timerVoce?.cancel();
    _ampiezza?.cancel();
    _rec?.dispose();
    _onde.dispose();
    super.dispose();
  }

  void _inFondo() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scorri.hasClients) {
      _scorri.animateTo(
        _scorri.position.maxScrollExtent,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  });

  // ───────────── invio ─────────────

  Future<void> _manda({String? testo, String? vocaleB64, int secondi = 0}) async {
    final t = (testo ?? _campo.text).trim();
    final foto = _fotoPronta;
    if (_occupato || (t.isEmpty && foto == null && vocaleB64 == null)) return;
    HapticFeedback.lightImpact();
    final turno = _Turno(
      domanda: vocaleB64 != null ? 'Messaggio vocale · $secondi s' : (t.isNotEmpty ? t : 'Cosa c\'è in questa foto?'),
      foto: foto,
      vocale: vocaleB64 != null,
    );
    setState(() {
      _occupato = true;
      _fotoPronta = null;
      _campo.clear();
      _turni.add(turno);
    });
    if (vocaleB64 == null) _storia.add({'ruolo': 'utente', 'testo': turno.domanda});
    _inFondo();
    Timer? disegno;
    void suPezzo(String? t) {
      final prima = turno.scritto.isEmpty;
      turno.scritto = t == null ? '' : turno.scritto + t;
      if (!mounted || disegno != null) return;
      disegno = Timer(const Duration(milliseconds: 60), () {
        disegno = null;
        if (!mounted || turno.risposta != null) return;
        // se si sta guardando il fondo, il testo resta in vista mentre si scrive
        final segui = _scorri.hasClients && _scorri.position.maxScrollExtent - _scorri.offset < 160;
        setState(() {});
        if (prima) {
          _inFondo();
        } else if (segui) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scorri.hasClients) _scorri.jumpTo(_scorri.position.maxScrollExtent);
          });
        }
      });
    }

    // la chat non resta muta: dopo 5 secondi, poi altri 10, poi 5… finché arriva la prima parola
    Timer? catena;
    final partito = DateTime.now();
    void suIntanto(List<String> testi) {
      void prossimo(int i, int dopo) {
        if (i >= testi.length) return;
        catena = Timer(Duration(seconds: dopo), () {
          if (!mounted || turno.risposta != null || turno.scritto.isNotEmpty) return;
          setState(() => turno.intanto.add(testi[i]));
          _inFondo();
          prossimo(i + 1, i.isOdd ? 5 : 10);
        });
      }

      prossimo(0, math.max(0, 5 - DateTime.now().difference(partito).inSeconds));
    }

    RispostaAi r;
    try {
      r = await _PdAi.attuale.chiedi(
        _storia.sublist(math.max(0, _storia.length - _maxStoria)),
        foto: foto != null ? base64Encode(foto) : null,
        vocale: vocaleB64,
        suPezzo: suPezzo,
        suIntanto: suIntanto,
      );
    } on ErroreSito catch (e) {
      r = RispostaAi(ok: false, testo: e.messaggio);
    } catch (_) {
      r = const RispostaAi(
        ok: false,
        testo: 'In questo momento non riesco a rispondere: riprova tra poco o scrivi a info@triburba.it.',
      );
    }
    disegno?.cancel();
    catena?.cancel();
    if (!mounted) return;
    setState(() {
      if (turno.vocale && r.trascrizione.isNotEmpty) {
        turno.domanda = r.trascrizione;
        _storia.add({'ruolo': 'utente', 'testo': r.trascrizione});
      }
      turno.risposta = r;
      if (r.ok) {
        _storia.add({'ruolo': 'ai', 'testo': r.testo});
      } else if (!turno.vocale && _storia.isNotEmpty) {
        _storia.removeLast(); // la risposta di cortesia non torna al motore come conversazione
      }
      _occupato = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = (turno.intanto.isNotEmpty ? turno.chiaveRisposta : turno.chiave).currentContext;
      if (c != null) {
        Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      }
    });
  }

  void _festa() {
    if (MediaQuery.of(context).disableAnimations) return;
    late final OverlayEntry voce;
    voce = OverlayEntry(
      builder: (_) => IgnorePointer(child: _Coriandoli(fine: () => voce.remove())),
    );
    Overlay.of(context).insert(voce);
  }

  void _nuova() {
    if (_occupato) return;
    HapticFeedback.selectionClick();
    setState(() {
      _turni.clear();
      _storia.clear();
      _fotoPronta = null;
      _scegliIdee();
    });
  }

  // ───────────── foto ─────────────

  Future<void> _scegliFoto() async {
    if (_occupato || _registra) return;
    final da = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _notte2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              _VoceFoglio(
                icona: Icons.photo_camera_rounded,
                testo: 'Scatta una foto',
                onTap: () => Navigator.pop(c, ImageSource.camera),
              ),
              _VoceFoglio(
                icona: Icons.photo_library_rounded,
                testo: 'Scegli dalla galleria',
                onTap: () => Navigator.pop(c, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (da == null) return;
    try {
      final f = await ImagePicker().pickImage(source: da, maxWidth: 1280, maxHeight: 1280, imageQuality: 82);
      if (f == null || !mounted) return;
      final b = await f.readAsBytes();
      setState(() => _fotoPronta = b);
      _fuoco.requestFocus();
    } catch (_) {
      if (mounted) avviso(context, 'Non riesco ad aprire la foto');
    }
  }

  // ───────────── vocale (WAV 16 kHz mono, al massimo 30 secondi) ─────────────

  Future<void> _iniziaVoce() async {
    if (_occupato) return;
    if (!await _registratore.hasPermission()) {
      if (mounted) avviso(context, 'Per mandare un vocale l\'app deve poter usare il microfono');
      return;
    }
    final dir = await getTemporaryDirectory();
    final percorso = '${dir.path}/triburba-ai-vocale.wav';
    await _registratore.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: percorso,
    );
    HapticFeedback.mediumImpact();
    _ampiezza = _registratore.onAmplitudeChanged(const Duration(milliseconds: 90)).listen((a) {
      final v = ((a.current + 50) / 50).clamp(.12, 1.0);
      _onde.value = [..._onde.value.skip(1), v];
    });
    setState(() {
      _registra = true;
      _inizioVoce = DateTime.now();
    });
    _timerVoce = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() {});
      if (DateTime.now().difference(_inizioVoce!).inSeconds >= 30) _fermaVoce(manda: true);
    });
  }

  Future<void> _fermaVoce({required bool manda}) async {
    if (!_registra) return;
    _timerVoce?.cancel();
    await _ampiezza?.cancel();
    final secondi = DateTime.now().difference(_inizioVoce!).inSeconds;
    final percorso = await _registratore.stop();
    setState(() {
      _registra = false;
      _onde.value = List.filled(24, .15);
    });
    if (!manda || percorso == null || secondi < 1) return;
    final byte = await File(percorso).readAsBytes();
    _manda(vocaleB64: base64Encode(byte), secondi: secondi);
  }

  // ───────────── schermata ─────────────

  @override
  Widget build(BuildContext context) {
    final sotto = MediaQuery.paddingOf(context).bottom;
    final tastiera = View.of(context).viewInsets.bottom > 0;
    return Scaffold(
      backgroundColor: _notte,
      body: _FondoNotte(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _testata(),
              Expanded(
                child: ShaderMask(
                  // le righe sfumano sotto la testata e sopra la barra
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                    stops: [0, .03, .95, 1],
                  ).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: ListView(
                    controller: _scorri,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    children: [
                      if (_turni.isEmpty) _inizio(),
                      for (final t in _turni)
                        _VistaTurno(
                          turno: t,
                          key: t.chiave,
                          // i bottoni «che tipo» valgono solo per l'ultima risposta
                          suScelta: identical(t, _turni.last) && !_occupato ? (s) => _manda(testo: s) : null,
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                // sopra la barra delle schede; con la tastiera aperta la barra è nascosta
                padding: EdgeInsets.fromLTRB(14, 4, 14, tastiera ? 10 : sotto + 12),
                child: _compositore(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _testata() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 10, 12, 4),
    child: Row(
      children: [
        const _Avatar(lato: 40),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'triburba-ai',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -.2),
              ),
              if (_versione.isNotEmpty)
                Text(
                  'Versione $_versione',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _tenue.withValues(alpha: .95), fontSize: 11.5),
                ),
            ],
          ),
        ),
        if (_turni.isNotEmpty) ...[
          _TastoTondo(icona: Icons.add_rounded, etichetta: 'Nuova conversazione', onTap: _nuova),
          const SizedBox(width: 8),
        ],
        _TastoTondo(icona: Icons.close_rounded, etichetta: 'Chiudi', onTap: () => Navigator.of(context).maybePop()),
      ],
    ),
  );

  Widget _inizio() => Padding(
    padding: const EdgeInsets.only(top: 26),
    child: Column(
      children: [
        const Entrata(child: _LogoGalleggia()),
        const SizedBox(height: 22),
        Entrata(
          ritardo: 1,
          child: Text('Ciao!', style: _titolo(40, colore: Colors.white)),
        ),
        const SizedBox(height: 8),
        Entrata(
          ritardo: 2,
          child: Text(
            widget.negozioNome.isNotEmpty
                ? 'Sono triburba-ai. Chiedimi come funziona triburba o cosa succede nei quartieri.'
                : 'Sono triburba-ai. Chiedimi come funziona triburba o cosa succede nei quartieri.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _tenue, fontSize: 15.5, height: 1.5),
          ),
        ),
        const SizedBox(height: 26),
        for (final (i, idea) in (_idee ?? const <String>[]).indexed)
          Entrata(
            ritardo: 3 + i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Idea(
                testo: idea,
                onTap: () => _manda(testo: idea),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _compositore() {
    final haTesto = _campo.text.trim().isNotEmpty || _fotoPronta != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_fotoPronta != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _notte2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: .1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(Uint8List.fromList(_fotoPronta!), width: 44, height: 44, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                Text('Foto pronta: scrivi la domanda', style: TextStyle(color: _tenue, fontSize: 13)),
                const SizedBox(width: 6),
                _TastoTondo(
                  icona: Icons.close_rounded,
                  etichetta: 'Togli la foto',
                  piccolo: true,
                  onTap: () => setState(() => _fotoPronta = null),
                ),
              ],
            ),
          ),
        _BordoAurora(
          veloce: _occupato,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _notte2.withValues(alpha: .96), borderRadius: BorderRadius.circular(28)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_registra) ...[
                  _TastoTondo(
                    icona: Icons.close_rounded,
                    etichetta: 'Annulla il vocale',
                    onTap: () => _fermaVoce(manda: false),
                  ),
                  Expanded(
                    child: _BarraVoce(
                      onde: _onde,
                      secondi: DateTime.now().difference(_inizioVoce!).inMilliseconds / 1000,
                    ),
                  ),
                ] else ...[
                  _TastoTondo(
                    icona: Icons.photo_camera_outlined,
                    etichetta: 'Manda una foto',
                    trasparente: true,
                    onTap: _scegliFoto,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _campo,
                      focusNode: _fuoco,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 800,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _manda(),
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                      cursorColor: _turchese,
                      decoration: InputDecoration(
                        hintText: 'Chiedi qualsiasi cosa…',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: .45)),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        fillColor: Colors.transparent,
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
                      ),
                    ),
                  ),
                  if (!haTesto)
                    _TastoTondo(
                      icona: Icons.mic_none_rounded,
                      etichetta: 'Manda un vocale (fino a 30 secondi)',
                      trasparente: true,
                      onTap: _iniziaVoce,
                    ),
                ],
                const SizedBox(width: 4),
                _TastoInvia(
                  attivo: (haTesto || _registra) && !_occupato,
                  rosso: _registra,
                  onTap: _registra ? () => _fermaVoce(manda: true) : () => _manda(),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 7, left: 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              Text(
                'Risponde l\'intelligenza artificiale di triburba: può sbagliare.',
                style: TextStyle(color: _tenue.withValues(alpha: .7), fontSize: 11.5),
              ),
              GestureDetector(
                onTap: () => apriLink(context, '$sito/privacy#chat-ai'),
                child: Text(
                  'Privacy',
                  style: TextStyle(color: _tenue.withValues(alpha: .9), fontSize: 11.5, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── un turno ─────────────────────────

/// Mentre si scrive: via i riferimenti [1] e la riga del blocco prodotti, che la risposta definitiva toglie comunque.
String _soloTesto(String s) => s
    .replaceAll(RegExp(r'\s*\[\d+(?:\s*,\s*\d+)*\]'), '')
    .replaceAll(RegExp(r'^.*PRODOTTI NEI NEGOZI.*$\n?', multiLine: true, caseSensitive: false), '');

class _VistaTurno extends StatelessWidget {
  const _VistaTurno({super.key, required this.turno, this.suScelta});

  final _Turno turno;
  final void Function(String)? suScelta;

  @override
  Widget build(BuildContext context) {
    final r = turno.risposta;
    return Entrata(
      child: Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (turno.foto != null)
              Center(
                child: _FotoScan(byte: turno.foto!, scansiona: r == null),
              ),
            if (turno.foto != null) const SizedBox(height: 14),
            // la domanda, a destra: una nuvoletta senza nome, come quelle del sito
            if (turno.domanda.isNotEmpty) Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(width: 44),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_viola, _turchese]),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (turno.vocale) const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.mic_rounded, color: Colors.white, size: 18),
                        ),
                        Flexible(
                          child: Text(
                            turno.domanda,
                            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.35, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final t in turno.intanto) ...[
              Entrata(child: _NuvolaAi(child: _Articolo(testo: t))),
              const SizedBox(height: 10),
            ],
            if (r != null)
              KeyedSubtree(key: turno.chiaveRisposta, child: _Risposta(domanda: turno.domanda, risposta: r, suScelta: suScelta, titoloFonti: turno.titoloFonti))
            else
              _NuvolaAi(child: turno.scritto.isNotEmpty ? _Articolo(testo: '${_soloTesto(turno.scritto)} ▍') : const _Attesa()),
          ],
        ),
      ),
    );
  }
}

/// La nuvoletta dell'AI, a sinistra e senza nome.
class _NuvolaAi extends StatelessWidget {
  const _NuvolaAi({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .1),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: child,
        ),
      ),
      const SizedBox(width: 24),
    ],
  );
}

/// Segnalare una risposta: si sceglie il motivo e arriva nella scheda Domande del pannello del sito.
Future<void> _segnala(BuildContext context, String domanda, String risposta) async {
  final motivo = await showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('Segnala questa risposta'),
      children: [
        for (final m in const ['Sbagliata', 'Offensiva', 'Altro'])
          SimpleDialogOption(onPressed: () => Navigator.pop(c, m), child: Text(m)),
      ],
    ),
  );
  if (motivo == null || !context.mounted) return;
  final ok = await _PdAi.attuale.segnala(domanda, risposta.replaceAll('**', ''), motivo);
  if (context.mounted) avviso(context, ok ? 'Grazie: la controlliamo.' : 'Non riesco a inviare la segnalazione: riprova.');
}

class _Risposta extends StatelessWidget {
  const _Risposta({required this.domanda, required this.risposta, required this.titoloFonti, this.suScelta});

  final String domanda;
  final RispostaAi risposta;
  final String titoloFonti;
  final void Function(String)? suScelta;

  @override
  Widget build(BuildContext context) {
    final r = risposta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NuvolaAi(child: _Articolo(testo: r.testo)),
        if (r.scelte.isNotEmpty && suScelta != null) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in r.scelte)
                _Pillola(icona: Icons.auto_awesome_rounded, testo: s, onTap: () => suScelta!(s)),
            ],
          ),
        ],
        if (r.fonti.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            titoloFonti.toUpperCase(),
            style: TextStyle(color: _tenue, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < r.fonti.length; i++)
            Entrata(
              ritardo: 2 + i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _Fonte(fonte: r.fonti[i]),
              ),
            ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!r.ok)
              _Pillola(
                icona: Icons.mail_rounded,
                testo: 'Scrivi a triburba',
                pieno: true,
                onTap: () => apriLink(context, r.contatti.isNotEmpty ? r.contatti : 'mailto:info@triburba.it'),
              )
            else ...[
              _Pillola(
                icona: Icons.copy_rounded,
                testo: 'Copia',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: r.testo.replaceAll('**', '')));
                  avviso(context, 'Risposta copiata');
                },
              ),
              _Pillola(
                icona: Icons.flag_rounded,
                testo: 'Segnala',
                onTap: () => _segnala(context, domanda, r.testo),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// La risposta come un piccolo articolo: paragrafi, elenchi, **grassetto**, link cliccabili (anche senza https://).
class _Articolo extends StatelessWidget {
  const _Articolo({required this.testo});

  final String testo;

  static final _reLink = RegExp(
    r'\[([^\]]+)\]\((https?://[^)\s]+)\)|(https?://[^\s<>")]+[^\s<>").,;:!?])|([\w.+-]+@[\w-]+(?:\.[\w-]+)*\.[a-z]{2,})|((?:www\.)?[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.(?:it|com|net|org|eu)(?:/[^\s<>")]*[^\s<>").,;:!?])?)',
    caseSensitive: false,
  );
  static const _base = TextStyle(color: Color(0xFFF7F0E6), fontSize: 16.5, height: 1.62);

  List<InlineSpan> _riga(BuildContext context, String riga) {
    final out = <InlineSpan>[];
    var ultimo = 0;
    void testo(String s) {
      final parti = s.split(RegExp(r'\*\*'));
      for (var k = 0; k < parti.length; k++) {
        if (parti[k].isEmpty) continue;
        out.add(
          TextSpan(
            text: parti[k].replaceAll('*', ''),
            style: k.isOdd ? const TextStyle(color: Colors.white, fontWeight: FontWeight.w800) : null,
          ),
        );
      }
    }

    for (final m in _reLink.allMatches(riga)) {
      if (m.start > ultimo) testo(riga.substring(ultimo, m.start));
      final String url, mostra;
      var titolo = false;
      if (m.group(2) != null) {
        url = m.group(2)!;
        mostra = m.group(1)!;
        titolo = true;
      } else if (m.group(3) != null) {
        url = m.group(3)!;
        mostra = url.replaceFirst(RegExp(r'^https?://(www\.)?'), '').replaceFirst(RegExp(r'/$'), '');
      } else if (m.group(4) != null) {
        url = 'mailto:${m.group(4)}';
        mostra = m.group(4)!;
      } else {
        url = 'https://${m.group(5)}';
        mostra = m.group(5)!.replaceFirst(RegExp(r'^www\.'), '').replaceFirst(RegExp(r'/$'), '');
      }
      out.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => apriLink(context, url),
            child: Text(
              mostra,
              style: _base.copyWith(
                color: titolo ? Colors.white : const Color(0xFFF0B34A),
                fontWeight: titolo ? FontWeight.w800 : FontWeight.w500,
                decoration: TextDecoration.underline,
                decorationColor: const Color(0x66F0B34A),
              ),
            ),
          ),
        ),
      );
      ultimo = m.end;
    }
    if (ultimo < riga.length) testo(riga.substring(ultimo));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final blocchi = testo.replaceAll('\r', '').split(RegExp(r'\n{2,}'));
    final figli = <Widget>[];
    var n = 0;
    for (final b in blocchi) {
      final righe = b.split('\n').where((r) => r.trim().isNotEmpty).toList();
      if (righe.isEmpty) continue;
      final elenco = righe.every((r) => RegExp(r'^\s*([-*•]|\d+[.)])\s+').hasMatch(r));
      Widget parte;
      if (elenco) {
        parte = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in righe)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, right: 11, left: 2),
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [_viola, _turchese]),
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: _base,
                          children: _riga(context, r.replaceFirst(RegExp(r'^\s*([-*•]|\d+[.)])\s+'), '')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      } else {
        parte = Text.rich(
          TextSpan(
            style: _base,
            children: [
              for (var i = 0; i < righe.length; i++) ...[
                if (i > 0) const TextSpan(text: '\n'),
                ..._riga(
                  context,
                  righe[i].replaceFirst(RegExp(r'^\s*#{1,6}\s+'), '').replaceFirst(RegExp(r'^\s*[-*]\s+'), '• '),
                ),
              ],
            ],
          ),
        );
      }
      figli.add(
        Entrata(
          ritardo: n++,
          spostamento: 10,
          child: Padding(padding: const EdgeInsets.only(bottom: 12), child: parte),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: figli);
  }
}

class _Fonte extends StatelessWidget {
  const _Fonte({required this.fonte});

  final FonteAi fonte;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: () => apriLink(context, fonte.url),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .11)),
      ),
      child: Row(
        children: [
          if (fonte.immagine.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Image.network(fonte.immagine, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fonte.tipo.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFF0B34A),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fonte.titolo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                if (fonte.estratto.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      fonte.estratto,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _tenue, fontSize: 12.5, height: 1.35),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.north_east_rounded, color: _tenue, size: 18),
        ],
      ),
    ),
  );
}

// ───────────────────────── attesa: passi che si accendono e righe che luccicano ─────────────────────────

class _Attesa extends StatefulWidget {
  const _Attesa();

  @override
  State<_Attesa> createState() => _AttesaState();
}

class _AttesaState extends State<_Attesa> {
  String _frase = _unaDi(_pensando);
  Timer? _lento;

  @override
  void initState() {
    super.initState();
    _lento = Timer(const Duration(seconds: 45), () {
      if (mounted) setState(() => _frase = _unaDi(_quasi));
    });
  }

  @override
  void dispose() {
    _lento?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(_frase, style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 15, height: 1.3)),
      ),
      const SizedBox(width: 8),
      const PuntiniAi(),
    ],
  );
}

// ───────────────────────── pezzi ─────────────────────────

/// Logo di triburba-ai: l'emblema di triburba (stesso disegno del logo «Emblema triburba» della chat del sito).
const String _logoAiSvg = '<svg viewBox="-20 -230 1300 1300" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="#fff" stroke-width="40" stroke-linecap="round" stroke-linejoin="round"><line x1="70" y1="483" x2="225" y2="518"/> <line x1="225" y1="518" x2="55" y2="702"/> <line x1="55" y1="702" x2="340" y2="672"/> <line x1="225" y1="518" x2="340" y2="672"/> <line x1="340" y1="672" x2="515" y2="540"/> <line x1="225" y1="518" x2="515" y2="540"/> <line x1="225" y1="518" x2="225" y2="345"/> <line x1="225" y1="345" x2="345" y2="345"/> <line x1="345" y1="345" x2="515" y2="540"/> <line x1="515" y1="540" x2="560" y2="722"/> <line x1="515" y1="540" x2="728" y2="657"/> <line x1="515" y1="540" x2="645" y2="440"/> <line x1="560" y1="722" x2="728" y2="657"/> <line x1="728" y1="657" x2="870" y2="520"/> <line x1="728" y1="657" x2="950" y2="715"/> <line x1="870" y1="520" x2="950" y2="715"/> <line x1="870" y1="520" x2="1068" y2="515"/> <line x1="1068" y1="515" x2="950" y2="715"/> <line x1="870" y1="520" x2="645" y2="440"/> <line x1="870" y1="520" x2="980" y2="400"/> <line x1="980" y1="400" x2="870" y2="320"/> <line x1="870" y1="320" x2="787" y2="365"/> <line x1="787" y1="365" x2="645" y2="440"/> <line x1="787" y1="365" x2="765" y2="232"/> <polyline points="515,540 515,135 530,135 530,100 580,64 630,100 630,135 645,135 645,440"/> <polyline points="645,232 765,232"/> <polyline points="349,345 349,285"/> <path d="M349,285 A83,83 0 0 1 515,285"/> <line x1="432" y1="180" x2="432" y2="202"/> <line x1="580" y1="46" x2="580" y2="64"/></g><g fill="#fff"><circle cx="515" cy="540" r="46"/> <circle cx="225" cy="345" r="38"/> <circle cx="345" cy="345" r="38"/> <circle cx="765" cy="232" r="38"/> <circle cx="787" cy="365" r="32"/> <circle cx="870" cy="320" r="38"/> <circle cx="980" cy="400" r="38"/> <circle cx="645" cy="440" r="43"/> <circle cx="870" cy="520" r="46"/> <circle cx="1068" cy="515" r="40"/> <circle cx="950" cy="715" r="43"/> <circle cx="728" cy="657" r="43"/> <circle cx="560" cy="722" r="38"/> <circle cx="340" cy="672" r="40"/> <circle cx="225" cy="518" r="43"/> <circle cx="70" cy="483" r="35"/> <circle cx="55" cy="702" r="40"/> <circle cx="580" cy="46" r="27"/> <circle cx="432" cy="180" r="27"/></g></svg>';

class _Avatar extends StatelessWidget {
  const _Avatar({required this.lato});

  final double lato;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AspettoAi>(
    valueListenable: aspettoAi,
    builder: (_, a, _) => Container(
    width: lato,
    height: lato,
    padding: EdgeInsets.all(lato * .14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(lato * .3),
      color: a.logoColore,
      gradient: a.logoColore != null ? null : const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_viola, Color(0xFFF0B34A)],
      ),
      boxShadow: [
        BoxShadow(color: _viola.withValues(alpha: .45), blurRadius: lato * .5, offset: Offset(0, lato * .15)),
      ],
    ),
    child: LogoAi(predefinito: SvgPicture.string(_logoAiSvg)),
    ),
  );
}

/// Il logo grande della schermata iniziale: galleggia piano, con un alone colorato che gira.
class _LogoGalleggia extends StatefulWidget {
  const _LogoGalleggia();

  @override
  State<_LogoGalleggia> createState() => _LogoGalleggiaState();
}

class _LogoGalleggiaState extends State<_LogoGalleggia> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, figlio) => Transform.translate(
      offset: Offset(0, math.sin(_c.value * 2 * math.pi) * 6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: SweepGradient(
                colors: const [_viola, _turchese, Color(0xFF1AA39A), _viola],
                transform: GradientRotation(_c.value * 2 * math.pi),
              ),
              boxShadow: [BoxShadow(color: _viola.withValues(alpha: .55), blurRadius: 40, spreadRadius: 2)],
            ),
          ),
          figlio!,
        ],
      ),
    ),
    child: const _Avatar(lato: 86),
  );
}

/// Bordo che gira (blu, turchese, rosa) attorno alla barra in basso: più veloce mentre l'AI pensa.
class _BordoAurora extends StatefulWidget {
  const _BordoAurora({required this.child, required this.veloce});

  final Widget child;
  final bool veloce;

  @override
  State<_BordoAurora> createState() => _BordoAuroraState();
}

class _BordoAuroraState extends State<_BordoAurora> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void didUpdateWidget(covariant _BordoAurora old) {
    super.didUpdateWidget(old);
    if (old.veloce != widget.veloce) {
      _c.duration = Duration(milliseconds: widget.veloce ? 1600 : 6000);
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, figlio) => Container(
      padding: const EdgeInsets.all(1.6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: SweepGradient(
          colors: [
            _viola,
            _turchese,
            const Color(0xFF1AA39A),
            _viola,
          ].map((c) => c.withValues(alpha: widget.veloce ? 1 : .6)).toList(),
          transform: GradientRotation(_c.value * 2 * math.pi),
        ),
        boxShadow: [
          BoxShadow(
            color: (widget.veloce ? _turchese : Colors.black).withValues(alpha: widget.veloce ? .35 : .4),
            blurRadius: widget.veloce ? 26 : 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: figlio,
    ),
    child: widget.child,
  );
}

/// La foto mandata, intera e centrata; mentre l'AI la guarda passa lo «scan» con gli angoli del mirino.
class _FotoScan extends StatefulWidget {
  const _FotoScan({required this.byte, required this.scansiona});

  final List<int> byte;
  final bool scansiona;

  @override
  State<_FotoScan> createState() => _FotoScanState();
}

class _FotoScanState extends State<_FotoScan> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  late final _img = Uint8List.fromList(widget.byte);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300, maxHeight: 320),
      child: Stack(
        children: [
          Image.memory(_img, fit: BoxFit.contain),
          if (widget.scansiona)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) => CustomPaint(painter: _PittoreScan(_c.value)),
              ),
            ),
        ],
      ),
    ),
  );
}

class _PittoreScan extends CustomPainter {
  _PittoreScan(this.v);

  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height * .34;
    final y = -h + (size.height + h) * Curves.easeInOut.transform(v);
    canvas.drawRect(
      Rect.fromLTWH(0, y, size.width, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, _turchese.withValues(alpha: .45), Colors.white],
          stops: const [0, .85, 1],
        ).createShader(Rect.fromLTWH(0, y, size.width, h)),
    );
    final angolo = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const m = 10.0, l = 20.0;
    final w = size.width, hh = size.height;
    for (final (a, b, c) in [
      (Offset(m, m + l), const Offset(m, m), const Offset(m + l, m)),
      (Offset(w - m - l, m), Offset(w - m, m), Offset(w - m, m + l)),
      (Offset(m, hh - m - l), Offset(m, hh - m), Offset(m + l, hh - m)),
      (Offset(w - m - l, hh - m), Offset(w - m, hh - m), Offset(w - m, hh - m - l)),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy),
        angolo,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PittoreScan old) => old.v != v;
}

class _BarraVoce extends StatelessWidget {
  const _BarraVoce({required this.onde, required this.secondi});

  final ValueNotifier<List<double>> onde;
  final double secondi;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: Row(
      children: [
        const SizedBox(width: 6),
        const PuntinoVivo(colore: Color(0xFFEF4444)),
        const SizedBox(width: 10),
        Expanded(
          child: ValueListenableBuilder<List<double>>(
            valueListenable: onde,
            builder: (_, v, _) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final a in v)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    width: 3,
                    height: 4 + 24 * a,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [_viola, _turchese],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '0:${secondi.floor().toString().padLeft(2, '0')}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 6),
      ],
    ),
  );
}

class _Idea extends StatelessWidget {
  const _Idea({required this.testo, required this.onTap});

  final String testo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .11)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: LinearGradient(colors: [_viola.withValues(alpha: .9), _turchese.withValues(alpha: .8)]),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              testo,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3),
            ),
          ),
          Icon(Icons.north_east_rounded, color: _tenue, size: 17),
        ],
      ),
    ),
  );
}

class _TastoTondo extends StatelessWidget {
  const _TastoTondo({
    required this.icona,
    required this.etichetta,
    required this.onTap,
    this.trasparente = false,
    this.piccolo = false,
  });

  final IconData icona;
  final String etichetta;
  final VoidCallback onTap;
  final bool trasparente, piccolo;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: etichetta,
    child: Tooltip(
      message: etichetta,
      child: Premibile(
        onTap: onTap,
        child: Container(
          width: piccolo ? 28 : 44,
          height: piccolo ? 28 : 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: trasparente ? Colors.transparent : Colors.white.withValues(alpha: .08),
            border: trasparente ? null : Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Icon(icona, color: trasparente ? _tenue : Colors.white, size: piccolo ? 16 : 22),
        ),
      ),
    ),
  );
}

class _TastoInvia extends StatelessWidget {
  const _TastoInvia({required this.attivo, required this.rosso, required this.onTap});

  final bool attivo, rosso;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: rosso ? 'Manda il vocale' : 'Invia',
    child: Premibile(
      onTap: attivo ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: attivo
              ? LinearGradient(colors: rosso ? const [Color(0xFFEF4444), Color(0xFF1AA39A)] : const [_viola, _turchese])
              : null,
          color: attivo ? null : Colors.white.withValues(alpha: .1),
          boxShadow: attivo
              ? [
                  BoxShadow(
                    color: (rosso ? const Color(0xFFEF4444) : _viola).withValues(alpha: .5),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          color: attivo ? Colors.white : Colors.white.withValues(alpha: .45),
          size: 22,
        ),
      ),
    ),
  );
}

class _Pillola extends StatelessWidget {
  const _Pillola({required this.icona, required this.testo, required this.onTap, this.pieno = false});

  final IconData icona;
  final String testo;
  final VoidCallback onTap;
  final bool pieno;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: pieno ? 18 : 14, vertical: pieno ? 11 : 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: pieno ? const LinearGradient(colors: [_viola, _indaco]) : null,
        border: pieno ? null : Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icona, size: 16, color: pieno ? Colors.white : _tenue),
          const SizedBox(width: 6),
          Text(
            testo,
            style: TextStyle(color: pieno ? Colors.white : _tenue, fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ],
      ),
    ),
  );
}

class _VoceFoglio extends StatelessWidget {
  const _VoceFoglio({required this.icona, required this.testo, required this.onTap});

  final IconData icona;
  final String testo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(colors: [_viola, _turchese]),
      ),
      child: Icon(icona, color: Colors.white, size: 21),
    ),
    title: Text(
      testo,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    ),
  );
}

// ───────────────────────── pezzi comuni (nell'app del sito stanno nel tema) ─────────────────────────

const _viola = Color(0xFFE0663A); // terracotta (nell'originale: viola)
const _indaco = Color(0xFFC9472A);
const _notte = Color(0xFF120D0B); // nero vernice
const _notte2 = Color(0xFF2A1912);

TextStyle _titolo(double misura, {Color colore = Colors.white, double altezza = 1.12}) =>
    TextStyle(fontSize: misura, fontWeight: FontWeight.w800, color: colore, height: altezza, letterSpacing: -.6);

void avviso(BuildContext context, String testo) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo), behavior: SnackBarBehavior.floating));

Future<void> apriLink(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) avviso(context, 'Non riesco ad aprire il link');
}

/// Fondo notte di triburba con la griglia sottile e tre luci (terracotta, oro tufo, verde Golfo).
class _FondoNotte extends StatelessWidget {
  const _FondoNotte({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    color: _notte,
    child: CustomPaint(painter: _PittoreNotte(), child: child),
  );
}

class _PittoreNotte extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void luce(Offset c, double r, Color col, double a) => canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            col.withValues(alpha: a),
            col.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    luce(Offset(size.width * .1, size.height * .02), size.width * .95, _viola, .55);
    luce(Offset(size.width * 1.05, size.height * .35), size.width * .7, _turchese, .3);
    luce(Offset(size.width * .5, size.height * 1.05), size.width * .7, const Color(0xFF1AA39A), .22);
    final punto = Paint()..color = Colors.white.withValues(alpha: .06);
    for (double y = 11; y < size.height * .6; y += 22) {
      for (double x = 11; x < size.width; x += 22) {
        canvas.drawCircle(Offset(x, y), .9, punto);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Entra in scena scivolando dal basso, con un ritardo (liste che si compongono una card alla volta).
class Entrata extends StatelessWidget {
  const Entrata({super.key, required this.child, this.ritardo = 0, this.spostamento = 24});

  final Widget child;
  final int ritardo; // in passi da 60 ms
  final double spostamento;

  @override
  Widget build(BuildContext context) {
    final durata = 420 + math.min(ritardo, 8) * 60;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: durata),
      curve: Interval((durata - 420) / durata, 1, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * spostamento), child: c),
      ),
      child: child,
    );
  }
}

/// Si abbassa un poco sotto il dito.
class Premibile extends StatefulWidget {
  const Premibile({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Premibile> createState() => _PremibileState();
}

class _PremibileState extends State<Premibile> {
  bool _giu = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => _giu = true),
    onTapUp: (_) => setState(() => _giu = false),
    onTapCancel: () => setState(() => _giu = false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: _giu ? .965 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

/// Puntino che pulsa (stato «acceso», registrazione in corso).
class PuntinoVivo extends StatefulWidget {
  const PuntinoVivo({super.key, this.colore = const Color(0xFF22C55E), this.lato = 8});

  final Color colore;
  final double lato;

  @override
  State<PuntinoVivo> createState() => _PuntinoVivoState();
}

class _PuntinoVivoState extends State<PuntinoVivo> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Container(
      width: widget.lato,
      height: widget.lato,
      decoration: BoxDecoration(
        color: widget.colore,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.colore.withValues(alpha: .6 * (1 - _c.value)),
            spreadRadius: 6 * _c.value,
          ),
        ],
      ),
    ),
  );
}

// ───────────────────────── collegamento a triburba.it (/ai/v1) ─────────────────────────

class ErroreSito implements Exception {
  const ErroreSito(this.messaggio);
  final String messaggio;
  @override
  String toString() => messaggio;
}

class FonteAi {
  const FonteAi({required this.titolo, required this.url, this.tipo = '', this.immagine = '', this.estratto = ''});

  final String titolo, url, tipo, immagine, estratto;

  factory FonteAi.daJson(Map<String, dynamic> j) => FonteAi(
    titolo: '${j['titolo'] ?? ''}',
    url: '${j['url'] ?? ''}',
    tipo: '${j['tipo'] ?? ''}',
    immagine: '${j['immagine'] ?? ''}',
    estratto: '${j['estratto'] ?? ''}',
  );
}

class RispostaAi {
  const RispostaAi({
    required this.ok,
    required this.testo,
    this.fonti = const [],
    this.contatti = '',
    this.trascrizione = '',
    this.scelte = const [],
  });

  final bool ok;
  final String testo, contatti, trascrizione;
  final List<FonteAi> fonti;
  final List<String> scelte; // i bottoni «che tipo cerchi?»

  factory RispostaAi.daJson(Map<String, dynamic> j) => RispostaAi(
    ok: j['ok'] == true,
    testo: '${j['risposta'] ?? ''}',
    contatti: '${j['contatti'] ?? ''}',
    trascrizione: '${j['trascrizione'] ?? ''}',
    scelte: [
      for (final s in (j['scelte'] is List ? j['scelte'] as List : const [])) '$s',
    ],
    fonti: [
      for (final f in (j['fonti'] is List ? j['fonti'] as List : const []))
        if (f is Map && f['url'] != null) FonteAi.daJson(f.cast()),
    ],
  );
}

/// La chat di triburba-ai su triburba.it: token dell'app, nonce (rinnovato se scade) e domanda con foto o vocale.
class _PdAi {
  _PdAi._(this._sito, this.pagina);
  static final _tutti = <String, _PdAi>{};

  /// La chat di triburba.it.
  static _PdAi per(String negozioUrl) {
    final u = negozioUrl.replaceAll(RegExp(r'/+$'), '');
    return _tutti.putIfAbsent(u, () => _PdAi._(u.isEmpty ? sito : u, u.isEmpty ? null : '$u/'));
  }

  /// Quella della schermata aperta.
  static _PdAi attuale = per('');

  final String _sito;
  final String? pagina; // nel negozio: così «dove mi trovo?» risponde col suo nome

  final _c = http.Client();
  String? _nonce;
  String _versione = ''; // del motore che risponde: la dà il sito insieme al nonce
  List<String> suggerite = const []; // le domande suggerite: anche queste le dà il sito
  int viste = 5;
  String get _base => '$_sito/ai/v1';

  Map<String, String> get _intestazioni => {
    'Accept': 'application/json',
    'User-Agent': 'triburba-app/${stato.api.versione} (${Platform.operatingSystem})',
    // col token dell'app il sito sa chi scrive (niente cookie): vale come prova al posto del nonce
    'X-Token': ?stato.api.token,
  };

  Future<String> _prendiNonce({bool nuovo = false}) async {
    if (_nonce != null && !nuovo) return _nonce!;
    final r = await _c.get(Uri.parse('$_base/nonce'), headers: _intestazioni).timeout(const Duration(seconds: 20));
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
    _nonce = (j['nonce'] as String?) ?? '';
    _versione = (j['versione'] as String?) ?? '';
    if (j['suggerite'] is List) suggerite = [for (final s in j['suggerite'] as List) '$s'];
    if (j['viste'] is int) viste = j['viste'] as int;
    if (j['aspetto'] is Map) aspettoAi.value = AspettoAi.daJson(j['aspetto'] as Map);
    return _nonce!;
  }

  /// La versione del motore per la testata: se il sito non risponde, niente numero e nessun errore.
  Future<String> chiediVersione() async {
    try {
      await _prendiNonce();
    } catch (_) {}
    return _versione;
  }

  /// Segnala una risposta al sito; false se non è arrivata.
  Future<bool> segnala(String domanda, String risposta, String motivo) async {
    final corpo = jsonEncode({'domanda': domanda, 'risposta': risposta, 'motivo': motivo});
    Future<http.Response> manda(String n) => _c
        .post(
          Uri.parse('$_base/segnala'),
          headers: {..._intestazioni, 'Content-Type': 'application/json', 'X-WP-Nonce': n},
          body: corpo,
        )
        .timeout(const Duration(seconds: 20));
    try {
      var r = await manda(await _prendiNonce());
      if (r.statusCode == 403) r = await manda(await _prendiNonce(nuovo: true));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// suPezzo riceve le parole man mano (null = si ricomincia: il PC si è fermato e risponde il box).
  /// Se il sito risponde tutto insieme funziona lo stesso, solo senza parole man mano.
  Future<RispostaAi> chiedi(
    List<Map<String, String>> messaggi, {
    String? foto,
    String? vocale,
    void Function(String?)? suPezzo,
    void Function(List<String>)? suIntanto,
  }) async {
    final corpo = jsonEncode({'messaggi': messaggi, 'foto': ?foto, 'vocale': ?vocale, 'flusso': true, 'pagina': ?pagina});
    Future<http.StreamedResponse> manda(String n) => _c
        .send(
          http.Request('POST', Uri.parse('$_base/chat'))
            ..headers.addAll({..._intestazioni, 'Content-Type': 'application/json', 'X-WP-Nonce': n})
            ..body = corpo,
        )
        .timeout(const Duration(seconds: 200));
    const persa = ErroreSito('Non riesco a raggiungere triburba: controlla la connessione.');
    http.StreamedResponse r;
    try {
      r = await manda(await _prendiNonce());
      if (r.statusCode == 403) {
        await r.stream.drain<void>();
        r = await manda(await _prendiNonce(nuovo: true));
      }
    } catch (_) {
      throw persa;
    }
    if ((r.headers['content-type'] ?? '').contains('ndjson')) {
      Map? finale;
      try {
        final righe = r.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .timeout(const Duration(seconds: 200));
        await for (final riga in righe) {
          if (riga.isEmpty) continue;
          final d = jsonDecode(riga);
          if (d is! Map) continue;
          if (d['pezzo'] is String) {
            suPezzo?.call(d['pezzo'] as String);
          } else if (d['azzera'] == true) {
            suPezzo?.call(null);
          } else if (d['intanto'] is List) {
            suIntanto?.call([for (final x in d['intanto'] as List) '$x']);
          } else if (d['fine'] == true && d['dati'] is Map) {
            finale = d['dati'] as Map;
          }
        }
      } catch (_) {
        throw persa;
      }
      if (finale == null) throw persa;
      return RispostaAi.daJson(finale.cast<String, dynamic>());
    }
    try {
      final tutta = await http.Response.fromStream(r);
      return RispostaAi.daJson((jsonDecode(utf8.decode(tutta.bodyBytes)) as Map).cast<String, dynamic>());
    } catch (_) {
      throw ErroreSito('triburba ha risposto ${r.statusCode}: riprova tra poco.');
    }
  }
}

/// La bolla di triburba-ai: luce terracotta, oro e verde che gira; il tocco apre la modalità AI.
class BollaAi extends StatefulWidget {
  const BollaAi({super.key, this.negozioUrl = '', this.negozioNome = ''});

  final String negozioUrl, negozioNome;

  @override
  State<BollaAi> createState() => _BollaAiState();
}

class _BollaAiState extends State<BollaAi> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Apri triburba-ai',
    child: Premibile(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context, rootNavigator: true).push(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 380),
            reverseTransitionDuration: const Duration(milliseconds: 280),
            pageBuilder: (_, _, _) => AiScreen(negozioUrl: widget.negozioUrl, negozioNome: widget.negozioNome),
            transitionsBuilder: (_, anim, _, figlio) {
              final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
              return FadeTransition(
                opacity: c,
                child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(c), child: figlio),
              );
            },
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, figlio) => Container(
          width: 62,
          height: 62,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: const [_viola, _turchese, Color(0xFF1AA39A), _viola],
              transform: GradientRotation(_c.value * 2 * math.pi),
            ),
            boxShadow: [BoxShadow(color: _viola.withValues(alpha: .55), blurRadius: 22, offset: const Offset(0, 8))],
          ),
          child: figlio,
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_viola, Color(0xFFF0B34A)],
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: LogoAi(predefinito: SvgPicture.string(_logoAiSvg)),
        ),
      ),
    ),
  );
}

/// Un pezzetto di carta: frenato dall'aria, poi scende ondeggiando e girandosi su se stesso.
class _Carta {
  _Carta(this.daSinistra, double forza, this.ritardo)
    : vx = (daSinistra ? 1 : -1) * forza * (.2 + _caso.nextDouble() * .55),
      vy = 0,
      w = 6 + _caso.nextDouble() * 5,
      h = 4 + _caso.nextDouble() * 6,
      tondo = _caso.nextDouble() > .85,
      giro = _caso.nextDouble() * 6.28,
      vGiro = (_caso.nextDouble() - .5) * .12,
      flip = _caso.nextDouble() * 6.28,
      vFlip = .08 + _caso.nextDouble() * .16,
      onda = _caso.nextDouble() * 6.28,
      vOnda = .03 + _caso.nextDouble() * .05,
      ampiezza = .3 + _caso.nextDouble() * .9,
      caduta = 1 + _caso.nextDouble() * 1.2,
      colore = const [
        Color(0xFF7C3AED), Color(0xFFA855F7), Color(0xFF22B8C9), Color(0xFF1AA39A), Color(0xFFF59E0B),
        Color(0xFFFDE047), Colors.white, Color(0xFF4F46E5), Color(0xFF34D399),
      ][_caso.nextInt(9)] {
    vy = -forza * (.55 + _caso.nextDouble() * .7);
  }

  final bool daSinistra;
  final double ritardo, w, h, vGiro, vFlip, vOnda, ampiezza, caduta;
  final bool tondo;
  final Color colore;
  double vx, vy, giro, flip, onda;
  double? x, y;
}

/// I coriandoli del compleanno: due spari dagli angoli in basso, circa 6 secondi, poi si tolgono da soli.
class _Coriandoli extends StatefulWidget {
  const _Coriandoli({required this.fine});

  final VoidCallback fine;

  @override
  State<_Coriandoli> createState() => _CoriandoliState();
}

class _CoriandoliState extends State<_Coriandoli> with SingleTickerProviderStateMixin {
  late final _t = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  List<_Carta>? _carte;
  double _prima = 0;

  @override
  void initState() {
    super.initState();
    _t.forward().whenComplete(widget.fine);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _muovi(Size s) {
    final forza = s.height / 40 + 3;
    _carte ??= [
      for (final (quanti, ritardo) in [(70, 0.0), (45, .5)])
        for (var i = 0; i < quanti * 2; i++) _Carta(i.isEven, forza, ritardo),
    ];
    final ora = _t.value * 6;
    final d = math.min(2.5, (ora - _prima) * 60);
    _prima = ora;
    final freno = math.pow(.975, d).toDouble();
    for (final c in _carte!) {
      if (ora < c.ritardo) continue;
      c.x ??= c.daSinistra ? 0 : s.width;
      c.y ??= s.height;
      c.vx *= freno;
      c.vy = math.min(c.caduta, c.vy * freno + .13 * d);
      c.onda += c.vOnda * d;
      c.flip += c.vFlip * d;
      c.giro += c.vGiro * d;
      c.x = c.x! + (c.vx + math.sin(c.onda) * c.ampiezza) * d;
      c.y = c.y! + c.vy * d;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, vincoli) => AnimatedBuilder(
      animation: _t,
      builder: (_, _) {
        _muovi(vincoli.biggest);
        return CustomPaint(size: Size.infinite, painter: _PittoreCoriandoli(_carte!, _t.value * 6));
      },
    ),
  );
}

class _PittoreCoriandoli extends CustomPainter {
  _PittoreCoriandoli(this.carte, this.ora);

  final List<_Carta> carte;
  final double ora;

  @override
  void paint(Canvas canvas, Size size) {
    final alfa = ora > 4.8 ? (6 - ora) / 1.2 : 1.0;
    for (final c in carte) {
      final x = c.x, y = c.y;
      if (x == null || y == null || y > size.height + 20) continue;
      final faccia = math.cos(c.flip);
      final colore = faccia < 0 ? Color.lerp(c.colore, Colors.black, .28)! : c.colore;
      final paint = Paint()..color = colore.withValues(alpha: alfa);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(c.giro);
      canvas.scale(1, math.max(.08, faccia.abs()));
      if (c.tondo) {
        canvas.drawCircle(Offset.zero, c.w / 2, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: c.w, height: c.h), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PittoreCoriandoli vecchio) => true;
}
