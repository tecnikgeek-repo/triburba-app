// Falò (prima «Meet»): la stanza vocale del quartiere, come sul sito (19/11/2026).
// La voce passa direttamente tra chi è dentro (WebRTC, fino a 8 persone); il sito fa da centralino:
// /api/meet/battito ogni 1,5 s dice chi c'è e consegna i messaggi per collegarsi. Chi entra dopo chiama chi c'era già.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../dati/api.dart';
import '../dati/stato.dart';
import '../tema.dart';

class SchermataMeet extends StatefulWidget {
  const SchermataMeet({super.key, required this.quartiereId, required this.nomeQuartiere, this.colore});

  final int quartiereId;
  final String nomeQuartiere;
  final Color? colore;

  @override
  State<SchermataMeet> createState() => _SchermataMeetState();
}

class _SchermataMeetState extends State<SchermataMeet> {
  String _nome = 'Falò';
  int _max = 8;
  String? _blocco;
  List<Map<String, dynamic>> _presenti = [];
  bool _carico = true;

  String? _mioPeer;
  int _mioEntrato = 0;
  List<dynamic> _ice = [];
  MediaStream? _flusso;
  bool _muto = false;
  bool _altoparlante = true;
  bool _entro = false;
  final _pcs = <String, RTCPeerConnection>{};
  final _parla = <String>{};
  final _collegati = <String>{};
  final _falliti = <String>{};
  Timer? _giro, _fuori, _livelli;

  Color get _q => widget.colore ?? terracotta;

  @override
  void initState() {
    super.initState();
    _guardaFuori();
    _fuori = Timer.periodic(const Duration(seconds: 5), (_) => _guardaFuori());
  }

  @override
  void dispose() {
    _esci(chiudendo: true);
    _fuori?.cancel();
    super.dispose();
  }

  Future<void> _guardaFuori() async {
    try {
      final j = await stato.api.get('/api/meet/stato', {'q': '${widget.quartiereId}'});
      if (!mounted || _mioPeer != null) return;
      setState(() {
        _nome = '${j['nome'] ?? 'Falò'}';
        _max = (j['max'] as num?)?.toInt() ?? 8;
        _blocco = j['blocco'] as String?;
        _presenti = (j['presenti'] as List? ?? []).cast<Map<String, dynamic>>();
        _carico = false;
      });
    } catch (_) {
      if (mounted) setState(() => _carico = false);
    }
  }

  // ── collegamenti con gli altri ──
  Future<void> _aspettaIce(RTCPeerConnection pc) async {
    if (pc.iceGatheringState == RTCIceGatheringState.RTCIceGatheringStateComplete) return;
    final fatto = Completer<void>();
    pc.onIceGatheringState = (s) {
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete && !fatto.isCompleted) fatto.complete();
    };
    await fatto.future.timeout(const Duration(milliseconds: 2500), onTimeout: () {});
  }

  Future<RTCPeerConnection> _nuovaPc(String peer) async {
    final pc = await createPeerConnection({'iceServers': _ice, 'sdpSemantics': 'unified-plan'});
    for (final t in _flusso!.getTracks()) {
      await pc.addTrack(t, _flusso!);
    }
    pc.onConnectionState = (s) {
      if (!mounted) return;
      setState(() {
        if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _collegati.add(peer);
          _falliti.remove(peer);
        } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _falliti.add(peer);
          _collegati.remove(peer);
        }
      });
    };
    _pcs[peer] = pc;
    return pc;
  }

  Future<void> _chiudiPc(String peer) async {
    final pc = _pcs.remove(peer);
    _collegati.remove(peer);
    _falliti.remove(peer);
    _parla.remove(peer);
    try {
      await pc?.close();
    } catch (_) {}
  }

  Future<void> _segnale(String a, String tipo, RTCSessionDescription? d) =>
      stato.api.post('/api/meet/segnale', {'peer': _mioPeer, 'a': a, 'tipo': tipo, 'dati': d == null ? null : {'type': d.type, 'sdp': d.sdp}});

  Future<void> _offri(String peer) async {
    try {
      final pc = await _nuovaPc(peer);
      await pc.setLocalDescription(await pc.createOffer({'offerToReceiveAudio': true}));
      await _aspettaIce(pc);
      await _segnale(peer, 'offerta', await pc.getLocalDescription());
    } catch (_) {}
  }

  Future<void> _riceviSegnale(Map<String, dynamic> s) async {
    final da = '${s['da']}';
    final d = s['dati'] as Map?;
    try {
      if (s['tipo'] == 'offerta' && d != null) {
        await _chiudiPc(da);
        final pc = await _nuovaPc(da);
        await pc.setRemoteDescription(RTCSessionDescription('${d['sdp']}', '${d['type']}'));
        await pc.setLocalDescription(await pc.createAnswer({'offerToReceiveAudio': true}));
        await _aspettaIce(pc);
        await _segnale(da, 'risposta', await pc.getLocalDescription());
      } else if (s['tipo'] == 'risposta' && d != null && _pcs[da] != null) {
        await _pcs[da]!.setRemoteDescription(RTCSessionDescription('${d['sdp']}', '${d['type']}'));
      }
    } catch (_) {}
  }

  Future<void> _battito() async {
    if (_mioPeer == null) return;
    try {
      final j = await stato.api.post('/api/meet/battito', {'peer': _mioPeer, 'muto': _muto ? 1 : 0});
      for (final s in (j['segnali'] as List? ?? [])) {
        await _riceviSegnale((s as Map).cast<String, dynamic>());
      }
      final lista = (j['presenti'] as List? ?? []).cast<Map<String, dynamic>>();
      final ci = lista.map((p) => '${p['peer']}').toSet();
      for (final peer in _pcs.keys.toList()) {
        if (!ci.contains(peer)) await _chiudiPc(peer);
      }
      if (mounted) setState(() => _presenti = lista);
    } on ErroreApi catch (e) {
      // 410: non sono più dentro (connessione persa troppo a lungo)
      if (mounted && e.messaggio.contains('uscit')) {
        messaggio(context, e.messaggio);
        _esci(silenzioso: true);
      }
    } catch (_) {}
  }

  // chi sta parlando: livello audio dalle statistiche dei collegamenti
  Future<void> _misura() async {
    final ora = <String>{};
    for (final e in _pcs.entries) {
      try {
        for (final r in await e.value.getStats()) {
          if (r.type == 'inbound-rtp' && (r.values['kind'] ?? r.values['mediaType']) == 'audio') {
            final l = (r.values['audioLevel'] as num?)?.toDouble() ?? 0;
            if (l > .04) ora.add(e.key);
          }
          if (r.type == 'media-source' && !_muto && _mioPeer != null) {
            final l = (r.values['audioLevel'] as num?)?.toDouble() ?? 0;
            if (l > .04) ora.add(_mioPeer!);
          }
        }
      } catch (_) {}
    }
    if (mounted && (ora.length != _parla.length || !ora.containsAll(_parla))) {
      setState(() => _parla
        ..clear()
        ..addAll(ora));
    }
  }

  // ── entrare e uscire ──
  Future<void> _entra() async {
    setState(() => _entro = true);
    try {
      _flusso = await navigator.mediaDevices.getUserMedia({
        'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
        'video': false,
      });
    } catch (_) {
      if (mounted) {
        setState(() => _entro = false);
        messaggio(context, 'Per entrare nel $_nome serve il permesso del microfono.');
      }
      return;
    }
    try {
      final j = await stato.api.post('/api/meet/entra', {'quartiere_id': widget.quartiereId});
      _mioPeer = '${j['peer']}';
      _ice = (j['ice'] as List? ?? []);
      final lista = (j['presenti'] as List? ?? []).cast<Map<String, dynamic>>();
      final io = lista.where((p) => p['peer'] == _mioPeer);
      _mioEntrato = io.isNotEmpty ? (io.first['entrato'] as num).toInt() : DateTime.now().millisecondsSinceEpoch;
      _fuori?.cancel();
      await Helper.setSpeakerphoneOn(_altoparlante);
      if (mounted) setState(() => _presenti = lista);
      // chiamo chi c'era già; chi arriva dopo chiamerà me
      for (final p in lista) {
        if (p['peer'] != _mioPeer && (p['entrato'] as num).toInt() <= _mioEntrato) _offri('${p['peer']}');
      }
      _giro = Timer.periodic(const Duration(milliseconds: 1500), (_) => _battito());
      _livelli = Timer.periodic(const Duration(milliseconds: 500), (_) => _misura());
    } on ErroreApi catch (e) {
      _fermaMicrofono();
      if (mounted) messaggio(context, e.messaggio);
    } catch (_) {
      _fermaMicrofono();
      if (mounted) messaggio(context, 'Non riesco a entrare nel $_nome: riprova.');
    } finally {
      if (mounted) setState(() => _entro = false);
    }
  }

  void _fermaMicrofono() {
    for (final t in _flusso?.getTracks() ?? <MediaStreamTrack>[]) {
      t.stop();
    }
    _flusso?.dispose();
    _flusso = null;
  }

  void _esci({bool silenzioso = false, bool chiudendo = false}) {
    _giro?.cancel();
    _livelli?.cancel();
    final peer = _mioPeer;
    _mioPeer = null;
    for (final p in _pcs.keys.toList()) {
      _chiudiPc(p);
    }
    _fermaMicrofono();
    if (peer != null && !silenzioso) stato.api.post('/api/meet/esci', {'peer': peer}).catchError((_) => <String, dynamic>{});
    if (!chiudendo && mounted) {
      setState(() {
        _parla.clear();
        _muto = false;
      });
      _guardaFuori();
      _fuori = Timer.periodic(const Duration(seconds: 5), (_) => _guardaFuori());
    }
  }

  void _microfono() {
    setState(() => _muto = !_muto);
    for (final t in _flusso?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !_muto;
    }
    _battito();
  }

  Future<void> _cambiaAltoparlante() async {
    setState(() => _altoparlante = !_altoparlante);
    await Helper.setSpeakerphoneOn(_altoparlante);
  }

  @override
  Widget build(BuildContext context) {
    final dentro = _mioPeer != null;
    final n = _presenti.length;
    return Scaffold(
        appBar: AppBar(title: Text('$_nome di ${widget.nomeQuartiere}')),
        body: _carico
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'La stanza vocale del quartiere: entri, ascolti, parli. Fino a $_max persone, solo residenti maggiorenni.',
                    style: TextStyle(color: testo2, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    n == 0 ? 'Non c\'è nessuno: entra tu per primo.' : (n == 1 ? 'C\'è una persona.' : 'Ci sono $n persone.'),
                    style: TextStyle(fontWeight: FontWeight.w800, color: testo),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.15,
                    children: [for (final p in _presenti) _riquadro(p)],
                  ),
                  const SizedBox(height: 16),
                  if (_blocco != null && !dentro)
                    Carta(
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: muto),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_blocco!, style: TextStyle(color: testo2, height: 1.35))),
                        ],
                      ),
                    )
                  else if (!dentro)
                    BottoneCaldo(testo: 'Entra nel $_nome', icona: Icons.headset_mic_outlined, occupato: _entro, onPressed: _entra)
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _microfono,
                            style: OutlinedButton.styleFrom(foregroundColor: _muto ? pompeiano : testo),
                            icon: Icon(_muto ? Icons.mic_off_rounded : Icons.mic_rounded),
                            label: Text(_muto ? 'Microfono spento' : 'Microfono acceso'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _cambiaAltoparlante,
                            icon: Icon(_altoparlante ? Icons.volume_up_rounded : Icons.phone_in_talk_rounded),
                            label: Text(_altoparlante ? 'Altoparlante' : 'Auricolare'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _esci(),
                      style: OutlinedButton.styleFrom(foregroundColor: pompeiano),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Esci'),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'La voce passa direttamente tra chi è nel $_nome: triburba non la registra e non la ascolta. '
                    'Se qualcuno si comporta male, esci e segnala il suo profilo.',
                    style: TextStyle(color: muto, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
    );
  }

  Widget _riquadro(Map<String, dynamic> p) {
    final peer = '${p['peer']}';
    final io = peer == _mioPeer;
    final parla = _parla.contains(peer) && !(io && _muto);
    final av = assoluto('${p['avatar']}');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: linea),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: parla ? _q : linea2,
              boxShadow: parla ? [BoxShadow(color: _q.withValues(alpha: .55), blurRadius: 18, spreadRadius: 2)] : null,
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: superficie2,
              backgroundImage: av != null && !av.startsWith('data:') ? NetworkImage(av) : null,
              child: av == null || av.startsWith('data:')
                  ? Text('${p['nome']}'.isNotEmpty ? '${p['nome']}'[0].toUpperCase() : '?',
                      style: TextStyle(color: testo, fontWeight: FontWeight.w800, fontSize: 22))
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            io ? '${p['nome']} (tu)' : '${p['nome']}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: testo, fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          if (p['muto'] == true)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic_off_rounded, size: 13, color: pompeiano),
                const SizedBox(width: 3),
                Text('Microfono spento', style: TextStyle(color: pompeiano, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            )
          else if (_falliti.contains(peer))
            Text('Non si collega', style: TextStyle(color: muto, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Carta che porta al Falò (pagina del quartiere)
class CartaMeet extends StatelessWidget {
  const CartaMeet({super.key, required this.quartiereId, required this.nomeQuartiere, this.colore});

  final int quartiereId;
  final String nomeQuartiere;
  final Color? colore;

  @override
  Widget build(BuildContext context) => Carta(
    child: InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SchermataMeet(quartiereId: quartiereId, nomeQuartiere: nomeQuartiere, colore: colore),
      )),
      child: Row(
        children: [
          Icon(Icons.headset_mic_outlined, color: colore ?? terracotta, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${stato.io?.meetNome ?? 'Falò'} di $nomeQuartiere', style: TextStyle(color: testo, fontWeight: FontWeight.w800, fontSize: 15)),
                Text('La stanza vocale del quartiere: entra e parla con i vicini', style: TextStyle(color: muto, fontSize: 12.5)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: muto),
        ],
      ),
    ),
  );
}

