// Colori, caratteri e pezzi propri di triburba (quelli del sito triburba.it, palette «Neápolis»);
// Informazioni, licenze, aggiornamenti e dialoghi sono nel kit comune delle app TK.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kit_tk.dart';

export 'kit_tk.dart';

// ── Palette Neápolis (app.css del sito) ──
const terracotta = Color(0xFFE0663A); // colore principale
const terracottaScura = Color(0xFFC9472A);
const oro = Color(0xFFF0B34A); // oro di tufo
const golfo = Color(0xFF1AA39A); // verde del Golfo: link e informazioni
const pompeiano = Color(0xFFEF4B3F); // rosso pompeiano: «Mi piace»
const vernice = Color(0xFF120D0B); // nero vernice: fondo
const vernice2 = Color(0xFF1A1310);
const superficie = Color(0xFF241A15);
const superficie2 = Color(0xFF2E221C);
const avorio = Color(0xFFF7F0E6);
const testo = Color(0xFFF6ECDF);
const _testoChiaro = testo; // per le classi che hanno un campo «testo»
const testo2 = Color(0xFFCDBFAE);
const muto = Color(0xFF9A8A7C);
const linea = Color(0x14FFFFFF);
const linea2 = Color(0x29FFFFFF);

const gradiente = LinearGradient(colors: [terracottaScura, terracotta, oro], stops: [0, .45, 1]);
const gradienteBottone = LinearGradient(colors: [terracottaScura, terracotta, Color(0xFFE98C3A)]);

const fontTesto = 'Inter';
const fontTitoli = 'Bricolage';

TextStyle titolo(double misura, {Color colore = testo, FontWeight peso = FontWeight.w800, double altezza = 1.1}) =>
    TextStyle(fontFamily: fontTitoli, fontSize: misura, fontWeight: peso, color: colore, height: altezza, letterSpacing: -.3);

/// Colore esadecimale «#a5d42d» → Color (terracotta se non valido).
Color colore(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return terracotta;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

/// Colori del testo dei post: {oro}…{/} ecc. (gli stessi del sito)
const coloriTesto = {
  'terracotta': terracotta,
  'oro': oro,
  'verde': golfo,
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
              shaderCallback: (r) => const LinearGradient(colors: [terracotta, oro]).createShader(r),
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

const configTriburba = ConfigTk(
  nome: 'triburba',
  repo: 'triburba-app',
  motto: 'Ogni quartiere una voce',
  descrizione: 'Il social dei quartieri: ogni quartiere una voce, insieme una città',
  accento: terracotta,
  accentoScuro: terracottaScura,
  simbolo: emblema,
  logoOriginale: emblema,
  scuro: true,
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
    appBarTheme: const AppBarTheme(
      backgroundColor: vernice,
      foregroundColor: testo,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(fontFamily: fontTitoli, fontSize: 22, fontWeight: FontWeight.w800, color: testo),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: superficie,
      hintStyle: const TextStyle(color: muto),
      labelStyle: const TextStyle(color: testo2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: linea2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: linea2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: terracotta, width: 2),
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
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: superficie2,
      contentTextStyle: TextStyle(color: testo, fontFamily: fontTesto),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: superficie,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    ),
    dividerTheme: const DividerThemeData(color: linea, space: 1, thickness: 1),
    listTileTheme: const ListTileThemeData(iconColor: testo2, textColor: testo),
    tabBarTheme: const TabBarThemeData(
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
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: terracotta, linearTrackColor: superficie2),
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
  const Chip2({super.key, required this.testo, this.icona, this.colore = terracotta, this.onTap, this.tenue = false});

  final String testo;
  final IconData? icona;
  final Color colore;
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
          if (icona != null) ...[Icon(icona, size: 13, color: colore), const SizedBox(width: 4)],
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
