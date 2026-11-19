// Colori, caratteri e pezzi propri di triburba (quelli del sito triburba.it, palette «Neápolis»);
// Informazioni, licenze, aggiornamenti e dialoghi sono nel kit comune delle app TK.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kit_tk.dart';
import 'widget/icona_tk.dart';

export 'kit_tk.dart';

// ── Temi (19/11/2026): 5 scuri e 5 chiari, gli stessi del sito (app.css, [data-tinta]) ──
// I nomi dei colori restano quelli di sempre (terracotta = colore principale, oro = secondo, golfo = link…),
// ma ora li dà il tema scelto: si cambia da Impostazioni → Tema e si salva sull'account (uguale sul sito).
class Tinta {
  const Tinta(this.id, this.nome, this.nota, {required this.scura, required this.fondo, required this.fondo2, required this.sup,
      required this.sup2, required this.testo, required this.testo2, required this.muto, required this.accento,
      required this.accentoScuro, required this.secondo, required this.link});

  final String id, nome, nota;
  final bool scura;
  final Color fondo, fondo2, sup, sup2, testo, testo2, muto, accento, accentoScuro, secondo, link;
}

const tinte = <Tinta>[
  Tinta('vesuvio', 'Vesuvio', 'terracotta e oro', scura: true, fondo: Color(0xFF120D0B), fondo2: Color(0xFF1A1310), sup: Color(0xFF241A15),
      sup2: Color(0xFF2E221C), testo: Color(0xFFF6ECDF), testo2: Color(0xFFCDBFAE), muto: Color(0xFF9A8A7C), accento: Color(0xFFE0663A),
      accentoScuro: Color(0xFFC9472A), secondo: Color(0xFFF0B34A), link: Color(0xFF1AA39A)),
  Tinta('golfo', 'Golfo di notte', 'blu petrolio', scura: true, fondo: Color(0xFF08131A), fondo2: Color(0xFF0D1C24), sup: Color(0xFF122833),
      sup2: Color(0xFF183240), testo: Color(0xFFE8F2F4), testo2: Color(0xFFB5C9CF), muto: Color(0xFF7F979E), accento: Color(0xFF26B3A6),
      accentoScuro: Color(0xFF15857B), secondo: Color(0xFFF0B34A), link: Color(0xFF5CC8FF)),
  Tinta('lava', 'Lava', 'rosso pompeiano', scura: true, fondo: Color(0xFF150A0C), fondo2: Color(0xFF1E0F12), sup: Color(0xFF2A1519),
      sup2: Color(0xFF351B20), testo: Color(0xFFF7E9E7), testo2: Color(0xFFD6BCB8), muto: Color(0xFFA08480), accento: Color(0xFFEF4B3F),
      accentoScuro: Color(0xFFC2312A), secondo: Color(0xFFF0B34A), link: Color(0xFFFF8A65)),
  Tinta('capri', 'Capri di notte', 'blu notte', scura: true, fondo: Color(0xFF0A0E1C), fondo2: Color(0xFF101629), sup: Color(0xFF18203A),
      sup2: Color(0xFF1F2949), testo: Color(0xFFE9EDFB), testo2: Color(0xFFBCC4E0), muto: Color(0xFF8790B0), accento: Color(0xFF5B8CFF),
      accentoScuro: Color(0xFF3A64D8), secondo: Color(0xFFF0B34A), link: Color(0xFF7FD1FF)),
  Tinta('posillipo', 'Posillipo', 'verde pini', scura: true, fondo: Color(0xFF0B120C), fondo2: Color(0xFF111A12), sup: Color(0xFF18251A),
      sup2: Color(0xFF1F2F22), testo: Color(0xFFECF3E8), testo2: Color(0xFFC1D0BB), muto: Color(0xFF8A9C85), accento: Color(0xFF6CC04A),
      accentoScuro: Color(0xFF4E9A30), secondo: Color(0xFFE8C547), link: Color(0xFF3FBFA5)),
  Tinta('avorio', 'Avorio', 'chiaro caldo', scura: false, fondo: Color(0xFFF7F0E6), fondo2: Color(0xFFEFE4D4), sup: Color(0xFFFFFCF7),
      sup2: Color(0xFFF3EADF), testo: Color(0xFF231A15), testo2: Color(0xFF5A4A3E), muto: Color(0xFF8B7A6C), accento: Color(0xFFD4572B),
      accentoScuro: Color(0xFFB03F1D), secondo: Color(0xFFB57A0E), link: Color(0xFF138A82)),
  Tinta('mergellina', 'Mergellina', 'acqua e sabbia', scura: false, fondo: Color(0xFFEEF6F5), fondo2: Color(0xFFE0EEEC), sup: Color(0xFFFFFFFF),
      sup2: Color(0xFFEAF3F2), testo: Color(0xFF10262A), testo2: Color(0xFF3D5A5E), muto: Color(0xFF6E8A8D), accento: Color(0xFF0F8F84),
      accentoScuro: Color(0xFF0A6E66), secondo: Color(0xFFC46F1C), link: Color(0xFF1F6FD1)),
  Tinta('amalfi', 'Amalfi', 'limone', scura: false, fondo: Color(0xFFFBF7E6), fondo2: Color(0xFFF3ECCE), sup: Color(0xFFFFFDF4),
      sup2: Color(0xFFF6F0DA), testo: Color(0xFF2A2412), testo2: Color(0xFF5C5232), muto: Color(0xFF8D8261), accento: Color(0xFFC27C00),
      accentoScuro: Color(0xFF9A6200), secondo: Color(0xFF2F8F4E), link: Color(0xFF1F6FD1)),
  Tinta('vietri', 'Vietri', 'ceramica blu e gialla', scura: false, fondo: Color(0xFFEEF3FB), fondo2: Color(0xFFDFE8F6), sup: Color(0xFFFFFFFF),
      sup2: Color(0xFFE9EFF9), testo: Color(0xFF121C33), testo2: Color(0xFF3D4A66), muto: Color(0xFF6D7895), accento: Color(0xFF2160C9),
      accentoScuro: Color(0xFF184A9E), secondo: Color(0xFFC98A12), link: Color(0xFF0F8F84)),
  Tinta('tramonto', 'Tramonto', 'rosa e arancio', scura: false, fondo: Color(0xFFFBEFEC), fondo2: Color(0xFFF5E0DB), sup: Color(0xFFFFFAF8),
      sup2: Color(0xFFF7E8E4), testo: Color(0xFF2C1715), testo2: Color(0xFF5E3F3B), muto: Color(0xFF917370), accento: Color(0xFFCF3F57),
      accentoScuro: Color(0xFFA92C42), secondo: Color(0xFFD9761F), link: Color(0xFF7A4FD1)),
];

Tinta _t = tinte.first;

/// Il tema in uso.
Tinta get tinta => _t;

/// Cambia quando cambia il tema: l'app intera si ridisegna (main.dart).
final tintaCambiata = ValueNotifier<String>(tinte.first.id);

const _chiaveTinta = 'triburba_tema';

/// Cambia il tema (id del sito: vesuvio, golfo, … tramonto) e lo ricorda sul telefono. Ritorna true se è cambiato.
bool impostaTinta(String? id) {
  final nuova = tinte.firstWhere((t) => t.id == id, orElse: () => tinte.first);
  if (nuova.id == _t.id) return false;
  _t = nuova;
  configTk = configTriburba;
  SharedPreferences.getInstance().then((p) => p.setString(_chiaveTinta, nuova.id));
  tintaCambiata.value = nuova.id;
  return true;
}

/// All'avvio: il tema scelto l'ultima volta (poi arriva anche quello salvato sull'account).
Future<void> caricaTinta() async {
  final id = (await SharedPreferences.getInstance()).getString(_chiaveTinta);
  final t = tinte.where((x) => x.id == id);
  if (t.isNotEmpty) {
    _t = t.first;
    tintaCambiata.value = _t.id;
  }
}

Color get terracotta => _t.accento; // colore principale
Color get terracottaScura => _t.accentoScuro;
Color get oro => _t.secondo; // colore secondo (hashtag, dettagli)
Color get golfo => _t.link; // link e informazioni
const pompeiano = Color(0xFFEF4B3F); // rosso pompeiano: «Mi piace»
Color get vernice => _t.fondo; // fondo
Color get vernice2 => _t.fondo2;
Color get superficie => _t.sup;
Color get superficie2 => _t.sup2;
const avorio = Color(0xFFF7F0E6);
Color get testo => _t.testo;
Color get _testoChiaro => testo; // per le classi che hanno un campo «testo»
Color get testo2 => _t.testo2;
Color get muto => _t.muto;
Color get linea => _t.scura ? const Color(0x14FFFFFF) : const Color(0x1A0F172A);
Color get linea2 => _t.scura ? const Color(0x29FFFFFF) : const Color(0x330F172A);

LinearGradient get gradiente => LinearGradient(colors: [terracottaScura, terracotta, oro], stops: const [0, .45, 1]);
LinearGradient get gradienteBottone =>
    LinearGradient(colors: [terracottaScura, terracotta, Color.lerp(terracotta, oro, .45)!]);

const fontTesto = 'Inter';
const fontTitoli = 'Bricolage';

TextStyle titolo(double misura, {Color? colore, FontWeight peso = FontWeight.w800, double altezza = 1.1}) =>
    TextStyle(fontFamily: fontTitoli, fontSize: misura, fontWeight: peso, color: colore ?? testo, height: altezza, letterSpacing: -.3);

/// Colore esadecimale «#a5d42d» → Color (terracotta se non valido).
Color colore(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return terracotta;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

/// Colori del testo dei post: {oro}…{/} ecc. (gli stessi del sito)
// colori fissi, come sul sito: il testo colorato di un post resta uguale con ogni tema
const coloriTesto = {
  'terracotta': Color(0xFFE0663A),
  'oro': Color(0xFFF0B34A),
  'verde': Color(0xFF1AA39A),
  'azzurro': Color(0xFF3B9DE0),
  'rosso': pompeiano,
  'viola': Color(0xFFA678F0),
};

/// La scritta «triburba»: «trib» terracotta, «u» sfumata, «rba» oro (come marchio() sul sito).
class Marchio extends StatelessWidget {
  const Marchio({super.key, this.misura = 26});

  final double misura;

  @override
  Widget build(BuildContext context) {
    final s = TextStyle(fontFamily: fontTitoli, fontSize: misura, fontWeight: FontWeight.w800, letterSpacing: -.5, height: 1);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'trib',
            style: s.copyWith(color: terracotta),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ShaderMask(
              shaderCallback: (r) => LinearGradient(colors: [terracotta, oro]).createShader(r),
              child: Text('u', style: s.copyWith(color: bianco)),
            ),
          ),
          TextSpan(
            text: 'rba',
            style: s.copyWith(color: oro),
          ),
        ],
      ),
    );
  }
}

/// L'emblema (rete-skyline) a colori.
Widget emblema(double lato) =>
    Image.asset('assets/img/triburba-emblema-colori.png', width: lato, height: lato, filterQuality: FilterQuality.medium);

ConfigTk get configTriburba => ConfigTk(
  nome: 'triburba',
  repo: 'triburba-app',
  motto: 'Ogni quartiere una voce',
  descrizione: 'Il social dei quartieri: ogni quartiere una voce, insieme una città',
  accento: terracotta,
  accentoScuro: terracottaScura,
  simbolo: emblema,
  logoOriginale: emblema,
  scuro: _t.scura,
  avvioColorato: false,
  manifestUrl: 'https://dl.dropboxusercontent.com/scl/fi/21srjonb8hfbdcwb1lg4y/triburba-version.json?rlkey=jyh6gxf5nlri5v7w4s5u644z8',
);

/// Tema scuro dell'app: il kit (scuro) con i colori e i caratteri di triburba.
ThemeData temaTriburba() {
  final base = temaKit();
  final testi = base.textTheme.apply(fontFamily: fontTesto, bodyColor: testo, displayColor: testo);
  return base.copyWith(
    scaffoldBackgroundColor: vernice,
    canvasColor: vernice,
    textTheme: testi,
    colorScheme: base.colorScheme.copyWith(
      primary: terracotta,
      secondary: oro,
      surface: superficie,
      onSurface: testo,
      surfaceContainerHighest: superficie2,
      outline: linea2,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: vernice,
      foregroundColor: testo,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      // barra di stato chiara sui temi scuri, scura sui temi chiari
      systemOverlayStyle: _t.scura ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(fontFamily: fontTitoli, fontSize: 22, fontWeight: FontWeight.w800, color: testo),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: superficie,
      hintStyle: TextStyle(color: muto),
      labelStyle: TextStyle(color: testo2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: linea2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: linea2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: terracotta, width: 2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: testo,
        backgroundColor: superficie2,
        minimumSize: const Size(0, 46),
        side: BorderSide.none,
        textStyle: const TextStyle(fontFamily: fontTesto, fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: terracotta,
        foregroundColor: bianco,
        minimumSize: const Size(0, 46),
        textStyle: const TextStyle(fontFamily: fontTesto, fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: superficie2,
      contentTextStyle: TextStyle(color: testo, fontFamily: fontTesto),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: superficie,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    ),
    dividerTheme: DividerThemeData(color: linea, space: 1, thickness: 1),
    listTileTheme: ListTileThemeData(iconColor: testo2, textColor: testo),
    tabBarTheme: TabBarThemeData(
      labelColor: testo,
      unselectedLabelColor: muto,
      indicatorColor: terracotta,
      dividerColor: linea,
      labelStyle: TextStyle(fontFamily: fontTesto, fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle: TextStyle(fontFamily: fontTesto, fontWeight: FontWeight.w600, fontSize: 14),
      tabAlignment: TabAlignment.start,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: vernice2,
      indicatorColor: terracotta.withValues(alpha: .22),
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: fontTesto,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: s.contains(WidgetState.selected) ? testo : muto,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? terracotta : muto, size: 25),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: terracotta, linearTrackColor: superficie2),
  );
}

/// Card del sito: superficie calda, bordo sottile.
class Carta extends StatelessWidget {
  const Carta({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.margin});

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: superficie,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: linea),
    ),
    child: child,
  );
}

/// Pastiglia con il colore del quartiere (come i «reach-chip» del sito).
class Chip2 extends StatelessWidget {
  // ignore: prefer_initializing_formals
  const Chip2({super.key, required this.testo, this.icona, this.iconaTk, Color? colore, this.onTap, this.tenue = false}) : _colore = colore;

  final String testo;
  final IconData? icona;
  /// nome di un'icona disegnata come sul sito (IconaTk), al posto di [icona]
  final String? iconaTk;
  final Color? _colore;
  Color get colore => _colore ?? terracotta;
  final VoidCallback? onTap;
  final bool tenue;

  @override
  Widget build(BuildContext context) {
    final w = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colore.withValues(alpha: tenue ? .1 : .16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colore.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconaTk != null) ...[IconaTk(iconaTk!, lato: 14, colore: colore), const SizedBox(width: 4)]
          else if (icona != null) ...[Icon(icona, size: 13, color: colore), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              testo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color.lerp(colore, _testoChiaro, .35)),
            ),
          ),
        ],
      ),
    );
    return onTap == null ? w : GestureDetector(onTap: onTap, child: w);
  }
}

/// Bottone col gradiente del sito.
class BottoneCaldo extends StatelessWidget {
  const BottoneCaldo({super.key, required this.testo, this.onPressed, this.icona, this.occupato = false});

  final String testo;
  final VoidCallback? onPressed;
  final IconData? icona;
  final bool occupato;

  @override
  Widget build(BuildContext context) {
    final attivo = onPressed != null && !occupato;
    return Opacity(
      opacity: attivo ? 1 : .6,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(gradient: gradienteBottone, borderRadius: BorderRadius.circular(10)),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: attivo ? onPressed : null,
            child: SizedBox(
              height: 48,
              child: Center(
                child: occupato
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: bianco))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icona != null) ...[Icon(icona, color: bianco, size: 20), const SizedBox(width: 8)],
                          Text(
                            testo,
                            style: const TextStyle(color: bianco, fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Messaggio a comparsa (snackbar) nei colori del tema.
void messaggio(BuildContext context, String t) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));
}
