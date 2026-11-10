// Suggerimenti @ mentre scrivi un post o un commento (Pietro, 10/11/2026): prima chi è nel post, poi chi segui
// e chi ti segue, poi i vicini del quartiere, infine tutti; in cima i gruppi @tribu, @follower, @primopiano.
// Si mette sopra o sotto la casella: compare da solo quando la parola sotto il cursore comincia con @.
import 'dart:async';

import 'package:flutter/material.dart';

import '../dati/stato.dart';
import '../tema.dart';
import 'faccia.dart';

class SuggerimentiMenzioni extends StatefulWidget {
  const SuggerimentiMenzioni({super.key, required this.campo, this.postId, this.altezza = 230});

  final TextEditingController campo;
  final int? postId;
  final double altezza;

  @override
  State<SuggerimentiMenzioni> createState() => _SuggerimentiMenzioniState();
}

class _Voce {
  _Voce(this.tag, this.nome, this.sotto, {this.avatar, this.motivo, this.gruppo = false});
  final String tag, nome, sotto;
  final String? avatar, motivo;
  final bool gruppo;
}

class _SuggerimentiMenzioniState extends State<SuggerimentiMenzioni> {
  static final _rx = RegExp(r'(^|[\s(])@([\p{L}\p{N}_.]{0,32})$', unicode: true);
  List<_Voce> _voci = [];
  int _da = -1; // dove comincia la @ nel testo
  String? _cercato;
  Timer? _attesa;

  @override
  void initState() {
    super.initState();
    widget.campo.addListener(_cambiato);
  }

  @override
  void didUpdateWidget(SuggerimentiMenzioni old) {
    super.didUpdateWidget(old);
    if (old.campo != widget.campo) {
      old.campo.removeListener(_cambiato);
      widget.campo.addListener(_cambiato);
    }
  }

  @override
  void dispose() {
    widget.campo.removeListener(_cambiato);
    _attesa?.cancel();
    super.dispose();
  }

  void _cambiato() {
    final v = widget.campo.value;
    final pos = v.selection.baseOffset;
    final m = (pos >= 0 && v.selection.isCollapsed && pos <= v.text.length) ? _rx.firstMatch(v.text.substring(0, pos)) : null;
    if (m == null) {
      _attesa?.cancel();
      _cercato = null;
      if (_voci.isNotEmpty || _da >= 0) {
        setState(() {
          _voci = [];
          _da = -1;
        });
      }
      return;
    }
    final q = m.group(2)!;
    _da = pos - q.length - 1;
    if (q == _cercato) return;
    _cercato = q;
    _attesa?.cancel();
    _attesa = Timer(const Duration(milliseconds: 150), () => _cerca(q));
  }

  Future<void> _cerca(String q) async {
    try {
      final d = await stato.api.menzioni(q, postId: widget.postId);
      if (!mounted || _cercato != q) return;
      final voci = <_Voce>[
        for (final g in (d['gruppi'] as List? ?? const [])) _Voce('${(g as Map)['tag']}', '@${g['tag']}', '${g['descr']}', gruppo: true),
        for (final p in (d['persone'] as List? ?? const []))
          _Voce(
            '${(p as Map)['username']}',
            '${p['nome']}',
            '@${p['username']}',
            avatar: p['avatar'] as String?,
            motivo: (p['motivo'] as String?)?.trim().isEmpty ?? true ? null : p['motivo'] as String,
          ),
      ];
      setState(() => _voci = voci);
    } catch (_) {
      // senza rete niente suggerimenti: si può sempre scrivere il nome a mano
    }
  }

  void _scegli(_Voce v) {
    final c = widget.campo;
    final pos = c.selection.baseOffset;
    if (_da < 0 || pos < _da) return;
    final da = _da, testo = '@${v.tag} ';
    _cercato = null;
    setState(() {
      _voci = [];
      _da = -1;
    });
    c.value = TextEditingValue(
      text: c.text.replaceRange(da, pos, testo),
      selection: TextSelection.collapsed(offset: da + testo.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_voci.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: BoxConstraints(maxHeight: widget.altezza),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: linea2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: _voci.length,
          itemBuilder: (_, i) {
            final v = _voci[i];
            return InkWell(
              onTap: () => _scegli(v),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  children: [
                    if (v.gruppo)
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: terracotta.withValues(alpha: .16), shape: BoxShape.circle),
                        child: const Text(
                          '@',
                          style: TextStyle(color: oro, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      )
                    else
                      FotoProfilo.da(nome: v.nome, avatar: v.avatar, lato: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            v.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                          ),
                          Text(
                            v.sotto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muto, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    if (v.motivo != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        v.motivo!,
                        style: const TextStyle(color: muto, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
