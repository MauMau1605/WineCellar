import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Color(0xFF0C0A06),
      body: Center(child: WineCaveScene()),
    ),
  ));
}

// ─── Models ───────────────────────────────────────────────────────────────────

enum WineType { rouge, blanc, rose, petillant, moelleux }

class WineBottle {
  final String name;
  final int year;
  final WineType type;
  const WineBottle({required this.name, required this.year, required this.type});
}

class WineTypeStyle {
  final Color body, rim, neck, cork;
  const WineTypeStyle({
    required this.body,
    required this.rim,
    required this.neck,
    required this.cork,
  });

  static WineTypeStyle of(WineType t) => switch (t) {
        WineType.rouge => const WineTypeStyle(
            body: Color(0xFF4A1010),
            rim: Color(0xFF8B2020),
            neck: Color(0xFF5E1414),
            cork: Color(0xFFC8A040)),
        WineType.blanc => const WineTypeStyle(
            body: Color(0xFF6A5A0A),
            rim: Color(0xFFC0A030),
            neck: Color(0xFF887210),
            cork: Color(0xFFC8A840)),
        WineType.rose => const WineTypeStyle(
            body: Color(0xFF7A3040),
            rim: Color(0xFFC06070),
            neck: Color(0xFF9A3C50),
            cork: Color(0xFFC8A040)),
        WineType.petillant => const WineTypeStyle(
            body: Color(0xFF103A3A),
            rim: Color(0xFF2A7878),
            neck: Color(0xFF164A4A),
            cork: Color(0xFFD0B850)),
        WineType.moelleux => const WineTypeStyle(
            body: Color(0xFF4E2C08),
            rim: Color(0xFF9A6020),
            neck: Color(0xFF623A10),
            cork: Color(0xFFC8A040)),
      };
}

// ─── Sample data ──────────────────────────────────────────────────────────────

final List<List<WineBottle?>> sampleShelves = [
  [
    const WineBottle(name: 'Château Belgrave', year: 2011, type: WineType.rouge),
    const WineBottle(name: 'Côtes du Rhône', year: 2019, type: WineType.rouge),
    const WineBottle(name: 'Chablis 1er Cru', year: 2020, type: WineType.blanc),
    const WineBottle(name: 'Terrasses Larzac', year: 2019, type: WineType.rouge),
    const WineBottle(name: 'Sancerre', year: 2021, type: WineType.blanc),
    const WineBottle(name: 'Pauillac', year: 2016, type: WineType.rouge),
  ],
  [
    const WineBottle(name: 'Château La Faurie', year: 2009, type: WineType.rouge),
    const WineBottle(name: 'Provence Rosé', year: 2022, type: WineType.rose),
    const WineBottle(name: 'Chantegrive', year: 2018, type: WineType.rouge),
    const WineBottle(name: 'Vouvray', year: 2019, type: WineType.moelleux),
    const WineBottle(name: 'Bourgogne', year: 2017, type: WineType.rouge),
    const WineBottle(name: 'Chinon', year: 2020, type: WineType.rouge),
  ],
  [
    const WineBottle(name: 'Champagne Brut', year: 2018, type: WineType.petillant),
    const WineBottle(name: 'Haut-Médoc', year: 2015, type: WineType.rouge),
    const WineBottle(name: 'Pomerol', year: 2016, type: WineType.rouge),
    const WineBottle(name: 'Saint-Émilion', year: 2014, type: WineType.rouge),
    const WineBottle(name: 'Cahors', year: 2019, type: WineType.rouge),
    null,
  ],
  [
    const WineBottle(name: 'Muscadet', year: 2021, type: WineType.blanc),
    const WineBottle(name: 'Gewurztraminer', year: 2020, type: WineType.blanc),
    const WineBottle(name: 'Riesling', year: 2019, type: WineType.blanc),
    const WineBottle(name: 'Condrieu', year: 2018, type: WineType.blanc),
    const WineBottle(name: 'Meursault', year: 2017, type: WineType.blanc),
    const WineBottle(name: 'Chablis Grand Cru', year: 2016, type: WineType.blanc),
  ],
  [
    const WineBottle(name: 'Sauternes', year: 2015, type: WineType.moelleux),
    const WineBottle(name: 'Jurançon', year: 2020, type: WineType.moelleux),
    const WineBottle(name: 'Monbazillac', year: 2018, type: WineType.moelleux),
    const WineBottle(name: 'Tokaji', year: 2017, type: WineType.moelleux),
    null,
    null,
  ],
  [
    const WineBottle(name: 'Margaux', year: 2015, type: WineType.rouge),
    const WineBottle(name: 'Bandol Rosé', year: 2021, type: WineType.rose),
    null,
    null,
    null,
    null,
  ],
  [null, null, null, null, null, null],
];

// ─── Scene widget ─────────────────────────────────────────────────────────────

class WineCaveScene extends StatefulWidget {
  const WineCaveScene({super.key});

  @override
  State<WineCaveScene> createState() => _WineCaveSceneState();
}

class _WineCaveSceneState extends State<WineCaveScene> {
  late List<List<WineBottle?>> shelves;
  int? selShelf;
  int? selSlot;

  @override
  void initState() {
    super.initState();
    shelves = sampleShelves.map((r) => List<WineBottle?>.from(r)).toList();
  }

  WineBottle? get selectedBottle {
    if (selShelf == null || selSlot == null) return null;
    return shelves[selShelf!][selSlot!];
  }

  void _onTap(TapUpDetails details, Size canvasSize) {
    final painter = WineCavePainter(
        shelves: shelves, selectedShelf: -1, selectedSlot: -1);
    final hit = painter.hitTestBottle(details.localPosition, canvasSize);
    if (hit != null) {
      setState(() {
        if (selShelf == hit.$1 && selSlot == hit.$2) {
          selShelf = null;
          selSlot = null;
        } else {
          selShelf = hit.$1;
          selSlot = hit.$2;
        }
      });
    } else {
      setState(() {
        selShelf = null;
        selSlot = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return Stack(
        children: [
          GestureDetector(
            onTapUp: (d) => _onTap(d, size),
            child: CustomPaint(
              painter: WineCavePainter(
                shelves: shelves,
                selectedShelf: selShelf ?? -1,
                selectedSlot: selSlot ?? -1,
              ),
              size: size,
            ),
          ),
          if (selectedBottle != null)
            Positioned(
              right: 20,
              bottom: 40,
              child: _InfoCard(
                bottle: selectedBottle!,
                onRemove: () {
                  setState(() {
                    shelves[selShelf!][selSlot!] = null;
                    selShelf = null;
                    selSlot = null;
                  });
                },
              ),
            ),
        ],
      );
    });
  }
}

// ─── Info card overlay ────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final WineBottle bottle;
  final VoidCallback onRemove;
  const _InfoCard({required this.bottle, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final style = WineTypeStyle.of(bottle.type);
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xF0100E08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x20C8A040)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: style.body,
                shape: BoxShape.circle,
                border: Border.all(
                    color: style.rim.withValues(alpha: 0.5), width: 1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              bottle.type.name[0].toUpperCase() +
                  bottle.type.name.substring(1),
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF8A8478),
                letterSpacing: 0.8,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(bottle.name,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFE0D8CC),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('${bottle.year}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF5A5448))),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x30C8A040)),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text('Retirer',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8A5030))),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Main painter ─────────────────────────────────────────────────────────────

class WineCavePainter extends CustomPainter {
  final List<List<WineBottle?>> shelves;
  final int selectedShelf;
  final int selectedSlot;

  final Map<String, Offset> _bottleCenters = {};
  final double _bottleRadius = 12.0;
  Size? _lastSize;

  WineCavePainter({
    required this.shelves,
    required this.selectedShelf,
    required this.selectedSlot,
  });

  // ── Layout constants (reference canvas 680×780) ──
  static const _w = 680.0, _h = 780.0;

  // Cooler frame
  static const _cfX = 195.0, _cfY = 22.0, _cfW = 290.0, _cfH = 618.0;

  // Glass area (inside frame)
  static const _gX = 206.0, _gY = 58.0, _gW = 268.0, _gH = 572.0;

  // Upper zone (shelves 0–3, red/mixed wines)
  static const _uzY = _gY + 6;
  static const _uzH = 296.0;
  static const _upperShelfCount = 4;

  // Divider
  static const _divY = _uzY + _uzH;
  static const _divH = 16.0;

  // Lower zone (shelves 4–5, white/sweet wines)
  static const _lzY = _divY + _divH;
  static const _lzH = 148.0;
  static const _lowerShelfCount = 2;

  // Bottom display (decorative lying bottles)
  static const _bdY = _lzY + _lzH;

  // Base pedestal
  static const _bX = 172.0, _bY = _cfY + _cfH + 6;
  static const _bW = 336.0, _bH = 48.0;

  // Bottles per row
  static const _slotsPerRow = 6;

  // ── Hit test ─────────────────────────────────────────────────────────────────
  (int, int)? hitTestBottle(Offset pos, Size size) {
    if (_lastSize == null) return null;
    for (final entry in _bottleCenters.entries) {
      final parts = entry.key.split(',');
      final s = int.parse(parts[0]), sl = int.parse(parts[1]);
      if (s < shelves.length &&
          sl < shelves[s].length &&
          shelves[s][sl] != null) {
        if ((pos - entry.value).distance <= _bottleRadius + 4) return (s, sl);
      }
    }
    return null;
  }

  // ── Paint ────────────────────────────────────────────────────────────────────
  @override
  void paint(Canvas canvas, Size size) {
    _lastSize = size;
    _bottleCenters.clear();

    final scale = math.min(size.width / _w, size.height / _h);
    canvas.save();
    canvas.translate((size.width - _w * scale) / 2, (size.height - _h * scale) / 2);
    canvas.scale(scale, scale);
    _drawScene(canvas);
    canvas.restore();
  }

  void _drawScene(Canvas canvas) {
    _drawDarkWoodPanels(canvas);
    _drawWallAmbientGlow(canvas);
    _drawCoolerRecess(canvas);
    _drawCoolerBody(canvas);
    _drawControlPanel(canvas);
    _drawGlassDoor(canvas);
    _drawHandle(canvas);
    _drawBase(canvas);
    _drawAmbientGlow(canvas);
    _drawVignette(canvas);
  }

  // ── Dark wood panel background ───────────────────────────────────────────────
  void _drawDarkWoodPanels(Canvas canvas) {
    final p = Paint();

    // Base fill – very dark warm brown
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1C1810), Color(0xFF181410), Color(0xFF14100A)],
    ).createShader(const Rect.fromLTWH(0, 0, _w, _h));
    canvas.drawRect(const Rect.fromLTWH(0, 0, _w, _h), p);
    p.shader = null;

    // Vertical planks
    final rng = math.Random(7);
    const plankCount = 9;
    const plankW = _w / plankCount;

    for (int i = 0; i < plankCount; i++) {
      final x = i * plankW;

      // Plank base with slight per-plank tint variation
      final v = rng.nextDouble() * 0.06;
      p.color = Color.fromRGBO(
        (36 + 20 * v).round(),
        (28 + 16 * v).round(),
        (16 + 10 * v).round(),
        1,
      );
      canvas.drawRect(Rect.fromLTWH(x + 1.2, 0, plankW - 2.4, _h), p);

      // Grain lines – subtle curved vertical strokes
      for (int g = 0; g < 14; g++) {
        final gx = x + 3 + (g * (plankW - 6) / 14);
        final alpha = 0.04 + rng.nextDouble() * 0.07;
        p.color = Color.fromRGBO(55 + rng.nextInt(18), 42 + rng.nextInt(12),
            25 + rng.nextInt(10), alpha);
        p.style = PaintingStyle.stroke;
        p.strokeWidth = 0.4 + rng.nextDouble() * 1.0;

        final path = Path()..moveTo(gx, 0);
        double cx = gx;
        for (double y = 0; y < _h; y += 30 + rng.nextDouble() * 20) {
          cx += (rng.nextDouble() - 0.5) * 1.8;
          path.lineTo(cx, y + 30);
        }
        canvas.drawPath(path, p);
      }
      p.style = PaintingStyle.fill;

      // Plank gap (very dark narrow line)
      p.color = const Color(0xFF060402);
      canvas.drawRect(Rect.fromLTWH(x, 0, 1.2, _h), p);
    }
    // Right edge gap
    p.color = const Color(0xFF060402);
    canvas.drawRect(Rect.fromLTWH(_w - 1.2, 0, 1.2, _h), p);

    // Subtle knots – a few darker ovals scattered on planks
    final knotRng = math.Random(321);
    for (int k = 0; k < 6; k++) {
      final kx = 40.0 + knotRng.nextDouble() * (_w - 80);
      final ky = 80.0 + knotRng.nextDouble() * (_h - 200);
      final kr = 4 + knotRng.nextDouble() * 6;
      p.shader = RadialGradient(
        colors: [
          const Color(0xFF0C0804),
          const Color(0x000C0804),
        ],
      ).createShader(Rect.fromCircle(center: Offset(kx, ky), radius: kr));
      canvas.drawCircle(Offset(kx, ky), kr, p);
      p.shader = null;
    }
  }

  // ── Warm wall glow from cooler's ambient light ───────────────────────────────
  void _drawWallAmbientGlow(Canvas canvas) {
    final p = Paint();

    // Subtle warm light on the wall around the cooler
    p.shader = RadialGradient(
      center: Alignment.center,
      radius: 0.7,
      colors: [
        const Color(0x0CC89030),
        const Color(0x06A07020),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(
      _cfX - 80, _cfY + _cfH * 0.4, _cfW + 160, _cfH * 0.8,
    ));
    canvas.drawRect(Rect.fromLTWH(
      _cfX - 80, _cfY + _cfH * 0.4, _cfW + 160, _cfH * 0.8,
    ), p);
    p.shader = null;
  }

  // ── Shadow recess behind cooler ──────────────────────────────────────────────
  void _drawCoolerRecess(Canvas canvas) {
    final p = Paint();

    // Soft shadow halo
    p.shader = RadialGradient(
      center: Alignment.center,
      colors: [const Color(0x50000000), Colors.transparent],
    ).createShader(Rect.fromLTWH(
      _cfX - 30, _cfY - 15, _cfW + 60, _cfH + 40,
    ));
    canvas.drawRect(Rect.fromLTWH(
      _cfX - 30, _cfY - 15, _cfW + 60, _cfH + 40,
    ), p);
    p.shader = null;
  }

  // ── Cooler body (dark steel unit) ────────────────────────────────────────────
  void _drawCoolerBody(Canvas canvas) {
    final p = Paint();

    // Right side 3D depth
    p.color = const Color(0xFF121210);
    canvas.drawRect(Rect.fromLTWH(_cfX + _cfW, _cfY + 5, 7, _cfH - 10), p);
    p.color = const Color(0xFF0A0A08);
    canvas.drawRect(
        Rect.fromLTWH(_cfX + _cfW + 7, _cfY + 10, 3, _cfH - 16), p);

    // Main body – dark brushed-steel gradient
    p.shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color(0xFF1A1A18),
        Color(0xFF262624),
        Color(0xFF2E2E2C),
        Color(0xFF262624),
        Color(0xFF161614),
      ],
      stops: [0.0, 0.12, 0.5, 0.88, 1.0],
    ).createShader(Rect.fromLTWH(_cfX, _cfY, _cfW, _cfH));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(_cfX, _cfY, _cfW, _cfH), const Radius.circular(4)),
      p,
    );
    p.shader = null;

    // Brushed metal micro-texture
    final rng = math.Random(42);
    for (double x = _cfX; x < _cfX + _cfW; x += 2.5) {
      p.color = Color.fromRGBO(255, 255, 255, rng.nextDouble() * 0.008);
      canvas.drawRect(Rect.fromLTWH(x, _cfY, 0.6, _cfH), p);
    }

    // Top cap
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF363634), Color(0xFF1E1E1C)],
    ).createShader(Rect.fromLTWH(_cfX, _cfY, _cfW, 12));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(_cfX, _cfY, _cfW, 12), const Radius.circular(4)),
      p,
    );
    p.shader = null;

    // Door frame inset
    p.color = const Color(0xFF080806);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(_gX - 3, _gY - 3, _gW + 6, _gH + 6),
          const Radius.circular(3)),
      p,
    );

    // Bottom edge
    p.color = const Color(0xFF121210);
    canvas.drawRect(
        Rect.fromLTWH(_cfX + 6, _cfY + _cfH - 4, _cfW - 12, 4), p);

    // Brand text
    final brand = TextPainter(
      text: const TextSpan(
        text: 'VINO RESERVE',
        style: TextStyle(
          fontSize: 7,
          color: Color(0x66908A80),
          letterSpacing: 2.5,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(minWidth: _cfW);
    brand.paint(canvas, Offset(_cfX, _cfY + _cfH - 18));

    // Feet
    p.color = const Color(0xFF0C0C0A);
    for (final fx in [_cfX + 20.0, _cfX + _cfW - 38.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(fx, _cfY + _cfH, 18, 7), const Radius.circular(2)),
        p,
      );
    }
  }

  // ── Control panel strip ──────────────────────────────────────────────────────
  void _drawControlPanel(Canvas canvas) {
    final p = Paint();

    // Panel background
    p.color = const Color(0xFF0E0E0C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(_cfX + 15, _cfY + 14, _cfW - 30, 20),
          const Radius.circular(3)),
      p,
    );

    // Temperature display
    p.color = const Color(0xFF060C06);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(_cfX + 20, _cfY + 16, 55, 16),
          const Radius.circular(2)),
      p,
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: '14°C',
        style: TextStyle(
          fontSize: 9,
          color: Color(0xFF38C038),
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(_cfX + 25, _cfY + 19));

    // Status indicator dots
    for (int i = 0; i < 6; i++) {
      final dotX = _cfX + 88 + i * 11.0;
      final on = i < 4;
      p.color = on ? const Color(0xFF3888E0) : const Color(0xFF222220);
      canvas.drawCircle(Offset(dotX, _cfY + 24), 2, p);
      if (on) {
        p.color = const Color(0x283888E0);
        canvas.drawCircle(Offset(dotX, _cfY + 24), 4, p);
      }
    }
  }

  // ── Glass door (tinted, interior visible) ────────────────────────────────────
  void _drawGlassDoor(Canvas canvas) {
    final p = Paint();

    // Dark tinted glass background
    p.shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color(0xFF030810),
        Color(0xFF061018),
        Color(0xFF08141E),
        Color(0xFF040A10),
      ],
      stops: [0.0, 0.25, 0.65, 1.0],
    ).createShader(Rect.fromLTWH(_gX, _gY, _gW, _gH));
    canvas.drawRect(Rect.fromLTWH(_gX, _gY, _gW, _gH), p);
    p.shader = null;

    // ── Top LED strip ──
    p.color = const Color(0xCCA8D0F0);
    canvas.drawRect(Rect.fromLTWH(_gX, _gY, _gW, 4), p);

    // LED downward glow
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x2898C8F0), Color(0x1070A0D0), Color(0x00000000)],
      stops: [0.0, 0.35, 1.0],
    ).createShader(Rect.fromLTWH(_gX, _gY + 4, _gW, 80));
    canvas.drawRect(Rect.fromLTWH(_gX, _gY + 4, _gW, 80), p);
    p.shader = null;

    // ── Interior warm ambient (bottom-up) ──
    p.shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Color(0x1AD4A040),
        Color(0x0CC09030),
        Color(0x04A08020),
        Color(0x00000000),
      ],
      stops: [0.0, 0.2, 0.4, 1.0],
    ).createShader(Rect.fromLTWH(_gX, _gY, _gW, _gH));
    canvas.drawRect(Rect.fromLTWH(_gX, _gY, _gW, _gH), p);
    p.shader = null;

    // ── Upper zone shelves and bottles ──
    _drawUpperShelves(canvas);

    // ── Dual-Space divider ──
    _drawDivider(canvas);

    // ── LED strip at divider level ──
    p.color = const Color(0x60A0C8E0);
    canvas.drawRect(Rect.fromLTWH(_gX, _divY - 1, _gW, 2), p);
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x1880B0D8), Color(0x00000000)],
    ).createShader(Rect.fromLTWH(_gX, _divY + _divH, _gW, 40));
    canvas.drawRect(Rect.fromLTWH(_gX, _divY + _divH, _gW, 40), p);
    p.shader = null;

    // ── Lower zone shelves and bottles ──
    _drawLowerShelves(canvas);

    // ── Bottom display (lying bottles) ──
    _drawBottomDisplay(canvas);

    // ── Glass reflections ──
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(_gX, _gY, _gW, _gH));

    // Left edge faint reflection
    p.shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0x00FFFFFF), Color(0x08FFFFFF), Color(0x00FFFFFF)],
    ).createShader(Rect.fromLTWH(_gX, _gY, 20, _gH));
    canvas.drawRect(Rect.fromLTWH(_gX, _gY, 20, _gH), p);
    p.shader = null;

    // Diagonal reflection streak
    p.color = const Color(0x05FFFFFF);
    final refl = Path()
      ..moveTo(_gX + 55, _gY)
      ..lineTo(_gX + 85, _gY)
      ..lineTo(_gX + 25, _gY + _gH)
      ..lineTo(_gX - 5, _gY + _gH)
      ..close();
    canvas.drawPath(refl, p);

    // Second thinner streak
    p.color = const Color(0x03FFFFFF);
    final refl2 = Path()
      ..moveTo(_gX + 100, _gY)
      ..lineTo(_gX + 115, _gY)
      ..lineTo(_gX + 55, _gY + _gH)
      ..lineTo(_gX + 40, _gY + _gH)
      ..close();
    canvas.drawPath(refl2, p);

    canvas.restore();

    // Glass border (subtle metallic edge)
    p.color = const Color(0x15FFFFFF);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(_gX + 0.5, _gY + 0.5, _gW - 1, _gH - 1),
          const Radius.circular(1)),
      p,
    );
    p.style = PaintingStyle.fill;
  }

  // ── Upper shelves (data shelves 0..3) ────────────────────────────────────────
  void _drawUpperShelves(Canvas canvas) {
    const spacing = _uzH / _upperShelfCount;

    for (int s = 0; s < _upperShelfCount && s < shelves.length; s++) {
      final railY = _uzY + spacing * (s + 1) - 8;
      _drawWoodRail(canvas, railY);

      final row = shelves[s];
      final slotW = _gW / _slotsPerRow;
      for (int sl = 0; sl < _slotsPerRow; sl++) {
        final cx = _gX + slotW * sl + slotW / 2;
        final cy = railY - 26;
        final bottle = sl < row.length ? row[sl] : null;
        final isSel = s == selectedShelf && sl == selectedSlot;
        _bottleCenters['$s,$sl'] = Offset(cx, cy);

        if (bottle != null) {
          _drawBottleFace(canvas, cx, cy, bottle.type, isSel);
        } else {
          _drawEmptySlot(canvas, cx, cy);
        }
      }
    }
  }

  // ── Lower shelves (data shelves 4..5) ────────────────────────────────────────
  void _drawLowerShelves(Canvas canvas) {
    const spacing = _lzH / _lowerShelfCount;

    for (int s = 0; s < _lowerShelfCount; s++) {
      final dataIdx = s + _upperShelfCount;
      if (dataIdx >= shelves.length) break;

      final railY = _lzY + spacing * (s + 1) - 8;
      _drawWoodRail(canvas, railY);

      final row = shelves[dataIdx];
      final slotW = _gW / _slotsPerRow;
      for (int sl = 0; sl < _slotsPerRow; sl++) {
        final cx = _gX + slotW * sl + slotW / 2;
        final cy = railY - 26;
        final bottle = sl < row.length ? row[sl] : null;
        final isSel = dataIdx == selectedShelf && sl == selectedSlot;
        _bottleCenters['$dataIdx,$sl'] = Offset(cx, cy);

        if (bottle != null) {
          _drawBottleFace(canvas, cx, cy, bottle.type, isSel);
        } else {
          _drawEmptySlot(canvas, cx, cy);
        }
      }
    }
  }

  // ── Wood shelf rail ──────────────────────────────────────────────────────────
  void _drawWoodRail(Canvas canvas, double y) {
    final p = Paint();
    const margin = 3.0;

    // Rail gradient – warm light oak
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFFCA9244), Color(0xFFA0682C), Color(0xFF6E4418)],
    ).createShader(Rect.fromLTWH(_gX + margin, y, _gW - margin * 2, 10));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(_gX + margin, y, _gW - margin * 2, 10),
          const Radius.circular(1.5)),
      p,
    );
    p.shader = null;

    // Wood grain stripes on rail
    final rng = math.Random(y.toInt());
    p.color = const Color(0x22000000);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 0.5;
    for (double gx = _gX + 8; gx < _gX + _gW - 6; gx += 10 + rng.nextDouble() * 10) {
      canvas.drawLine(Offset(gx, y), Offset(gx + 2 + rng.nextDouble() * 2, y + 10), p);
    }
    p.style = PaintingStyle.fill;

    // Top highlight
    p.color = const Color(0x1CFFFFFF);
    canvas.drawRect(Rect.fromLTWH(_gX + margin + 2, y, _gW - margin * 2 - 4, 1.5), p);

    // Bottom shadow beneath rail
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [const Color(0x30000000), Colors.transparent],
    ).createShader(Rect.fromLTWH(_gX + margin, y + 10, _gW - margin * 2, 4));
    canvas.drawRect(
        Rect.fromLTWH(_gX + margin, y + 10, _gW - margin * 2, 4), p);
    p.shader = null;
  }

  // ── Dual-Space divider ───────────────────────────────────────────────────────
  void _drawDivider(Canvas canvas) {
    final p = Paint();

    // Metal strip
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF353533), Color(0xFF252523), Color(0xFF1C1C1A)],
    ).createShader(Rect.fromLTWH(_gX, _divY, _gW, _divH));
    canvas.drawRect(Rect.fromLTWH(_gX, _divY, _gW, _divH), p);
    p.shader = null;

    // Label
    final tp = TextPainter(
      text: const TextSpan(
        text: '◈  Dual Space',
        style: TextStyle(
          fontSize: 7,
          color: Color(0x88A09C94),
          letterSpacing: 1.5,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(minWidth: _gW);
    tp.paint(canvas, Offset(_gX, _divY + 4));

    // Top/bottom edges
    p.color = const Color(0x18FFFFFF);
    canvas.drawRect(Rect.fromLTWH(_gX, _divY, _gW, 0.8), p);
    p.color = const Color(0x30000000);
    canvas.drawRect(Rect.fromLTWH(_gX, _divY + _divH - 0.8, _gW, 0.8), p);
  }

  // ── Bottom display – decorative lying bottles ────────────────────────────────
  void _drawBottomDisplay(Canvas canvas) {
    final p = Paint();

    // Slightly warmer background in display zone
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x08D4A040), Color(0x10C09030)],
    ).createShader(Rect.fromLTWH(_gX, _bdY, _gW, _gY + _gH - _bdY - 12));
    canvas.drawRect(
        Rect.fromLTWH(_gX, _bdY, _gW, _gY + _gH - _bdY - 12), p);
    p.shader = null;

    // Draw 3 lying bottles
    _drawLyingBottle(canvas, _gX + 20, _bdY + 18, 100, WineType.blanc, false);
    _drawLyingBottle(canvas, _gX + 25, _bdY + 44, 105, WineType.blanc, true);
    _drawLyingBottle(canvas, _gX + 18, _bdY + 70, 95, WineType.moelleux, false);

    // Bottom rail
    final railY = _gY + _gH - 12.0;
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFC08840), Color(0xFF6A4018)],
    ).createShader(Rect.fromLTWH(_gX + 3, railY, _gW - 6, 10));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(_gX + 3, railY, _gW - 6, 10),
          const Radius.circular(1.5)),
      p,
    );
    p.shader = null;
  }

  // ── A single lying bottle (side view) ────────────────────────────────────────
  void _drawLyingBottle(
      Canvas canvas, double x, double y, double len, WineType type, bool flip) {
    final t = WineTypeStyle.of(type);
    final p = Paint();

    final bodyStart = flip ? x : x + 20;
    final bodyLen = len - 32;

    // Body
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        t.rim.withValues(alpha: 0.55),
        t.body.withValues(alpha: 0.85),
        t.body.withValues(alpha: 0.5),
      ],
    ).createShader(Rect.fromLTWH(bodyStart, y - 6, bodyLen, 12));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(bodyStart, y - 6, bodyLen, 12),
          const Radius.circular(4)),
      p,
    );
    p.shader = null;

    // Neck
    final neckX = flip ? x + len - 22 : x;
    p.color = t.neck.withValues(alpha: 0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(neckX, y - 3.5, 22, 7), const Radius.circular(3)),
      p,
    );

    // Capsule / foil
    final capX = flip ? x + len - 6 : x - 2;
    p.color = t.rim.withValues(alpha: 0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(capX, y - 4.5, 9, 9), const Radius.circular(2)),
      p,
    );

    // Body highlight
    p.color = const Color(0x12FFFFFF);
    canvas.drawRect(Rect.fromLTWH(bodyStart + 4, y - 5, bodyLen - 8, 2.5), p);

    // Label band
    final labelX = bodyStart + bodyLen * 0.25;
    p.color = const Color(0x28F0E8D0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(labelX, y - 5, 32, 10), const Radius.circular(1)),
      p,
    );
  }

  // ── Bottle face (end-on circle view) ─────────────────────────────────────────
  void _drawBottleFace(
      Canvas canvas, double cx, double cy, WineType type, bool selected) {
    final r = _bottleRadius;
    final t = WineTypeStyle.of(type);
    final p = Paint();

    // Selection ring
    if (selected) {
      p.color = const Color(0x80FFFFFF);
      p.style = PaintingStyle.stroke;
      p.strokeWidth = 2;
      canvas.drawCircle(Offset(cx, cy), r + 4, p);
      p.style = PaintingStyle.fill;
    }

    // Outer glow
    p.shader = RadialGradient(
      colors: [t.rim.withValues(alpha: 0.3), Colors.transparent],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r + 6));
    canvas.drawCircle(Offset(cx, cy), r + 6, p);
    p.shader = null;

    // Body circle
    p.color = t.body;
    canvas.drawCircle(Offset(cx, cy), r, p);

    // Glass-depth gradient
    p.shader = RadialGradient(
      center: const Alignment(-0.35, -0.35),
      radius: 1.0,
      colors: [
        t.rim.withValues(alpha: 0.55),
        t.body,
        Colors.black.withValues(alpha: 0.45),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, p);
    p.shader = null;

    // Collet ring
    p.color = t.rim;
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 2.2;
    canvas.drawCircle(Offset(cx, cy), 6, p);
    p.style = PaintingStyle.fill;

    // Neck disc
    p.color = t.neck;
    canvas.drawCircle(Offset(cx, cy), 4.8, p);

    // Cork with warm gradient
    p.shader = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      colors: const [Color(0xFFE0B850), Color(0xFFA07828)],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 3));
    canvas.drawCircle(Offset(cx, cy), 3, p);
    p.shader = null;

    // Specular highlight
    p.shader = RadialGradient(
      center: const Alignment(-0.55, -0.55),
      colors: [Colors.white.withValues(alpha: 0.28), Colors.transparent],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, p);
    p.shader = null;

    // Glint
    p.color = Colors.white.withValues(alpha: 0.5);
    canvas.save();
    canvas.translate(cx - 4.5, cy - 4.5);
    canvas.rotate(-0.6);
    canvas.drawOval(const Rect.fromLTWH(-2, -1.2, 4, 2.4), p);
    canvas.restore();
  }

  // ── Empty slot (dashed circle) ───────────────────────────────────────────────
  void _drawEmptySlot(Canvas canvas, double cx, double cy) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (int i = 0; i < 8; i++) {
      final start = i * math.pi / 4;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: _bottleRadius),
        start,
        math.pi / 6,
        false,
        p,
      );
    }
  }

  // ── Handle ───────────────────────────────────────────────────────────────────
  void _drawHandle(Canvas canvas) {
    final p = Paint();
    const hx = _cfX + 12.0;
    const hy = _cfY + _cfH / 2 - 42;

    // Handle body
    p.shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFF4A4A48), Color(0xFF626260), Color(0xFF3C3C3A)],
    ).createShader(const Rect.fromLTWH(hx, hy, 7, 84));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(hx, hy, 7, 84), const Radius.circular(3.5)),
      p,
    );
    p.shader = null;

    // Highlight shimmer
    p.color = const Color(0x14FFFFFF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(hx + 1.5, hy + 2, 2.5, 80),
          const Radius.circular(1.5)),
      p,
    );
  }

  // ── Stone base pedestal ──────────────────────────────────────────────────────
  void _drawBase(Canvas canvas) {
    final p = Paint();

    // Base body – polished dark stone
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF201C18), Color(0xFF161412), Color(0xFF100E0A)],
    ).createShader(Rect.fromLTWH(_bX, _bY, _bW, _bH));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(_bX, _bY, _bW, _bH), const Radius.circular(3)),
      p,
    );
    p.shader = null;

    // Polished top edge
    p.color = const Color(0x14FFFFFF);
    canvas.drawRect(Rect.fromLTWH(_bX + 3, _bY, _bW - 6, 1.5), p);

    // Stone texture (subtle speckles)
    final rng = math.Random(789);
    for (int i = 0; i < 40; i++) {
      final sx = _bX + rng.nextDouble() * _bW;
      final sy = _bY + rng.nextDouble() * _bH;
      p.color = Color.fromRGBO(255, 255, 255, rng.nextDouble() * 0.012);
      canvas.drawRect(
          Rect.fromLTWH(sx, sy, 1.5 + rng.nextDouble() * 5, 0.8), p);
    }

    // Front bevel highlight
    p.color = const Color(0x0AFFFFFF);
    canvas.drawRect(Rect.fromLTWH(_bX + 3, _bY + _bH - 2, _bW - 6, 1), p);
  }

  // ── Ambient warm glow (LED under base) ───────────────────────────────────────
  void _drawAmbientGlow(Canvas canvas) {
    final p = Paint();

    // LED strip
    p.shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color(0x00D0982C),
        Color(0xFFD0982C),
        Color(0xFFD0982C),
        Color(0x00D0982C),
      ],
      stops: [0.0, 0.15, 0.85, 1.0],
    ).createShader(Rect.fromLTWH(_bX + 8, _bY + _bH - 1, _bW - 16, 3));
    canvas.drawRect(Rect.fromLTWH(_bX + 8, _bY + _bH - 1, _bW - 16, 3), p);
    p.shader = null;

    // Primary warm glow halo
    p.shader = RadialGradient(
      center: const Alignment(0, -0.6),
      radius: 1.0,
      colors: const [
        Color(0x3CD09830),
        Color(0x20A07820),
        Color(0x0C806018),
        Color(0x00000000),
      ],
      stops: const [0.0, 0.3, 0.55, 1.0],
    ).createShader(
        Rect.fromLTWH(_bX - 40, _bY + _bH - 4, _bW + 80, 110));
    canvas.drawRect(
        Rect.fromLTWH(_bX - 40, _bY + _bH - 4, _bW + 80, 110), p);
    p.shader = null;

    // Floor warm reflection (further)
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x14C89028), Color(0x08906818), Color(0x00000000)],
    ).createShader(Rect.fromLTWH(_bX - 20, _bY + _bH + 8, _bW + 40, 80));
    canvas.drawRect(
        Rect.fromLTWH(_bX - 20, _bY + _bH + 8, _bW + 40, 80), p);
    p.shader = null;

    // Light splash on floor directly below
    p.shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color(0x00C89028),
        Color(0x10C89028),
        Color(0x10C89028),
        Color(0x00C89028),
      ],
      stops: [0.0, 0.25, 0.75, 1.0],
    ).createShader(Rect.fromLTWH(_bX, _bY + _bH + 2, _bW, 12));
    canvas.drawRect(Rect.fromLTWH(_bX, _bY + _bH + 2, _bW, 12), p);
    p.shader = null;
  }

  // ── Atmospheric vignette ─────────────────────────────────────────────────────
  void _drawVignette(Canvas canvas) {
    final p = Paint();

    // Top
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x70000000), Color(0x00000000)],
    ).createShader(const Rect.fromLTWH(0, 0, _w, 50));
    canvas.drawRect(const Rect.fromLTWH(0, 0, _w, 50), p);

    // Bottom
    p.shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0x70000000), Color(0x00000000)],
    ).createShader(Rect.fromLTWH(0, _h - 35, _w, 35));
    canvas.drawRect(Rect.fromLTWH(0, _h - 35, _w, 35), p);

    // Left
    p.shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0x50000000), Color(0x00000000)],
    ).createShader(const Rect.fromLTWH(0, 0, 70, _h));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 70, _h), p);

    // Right
    p.shader = const LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: [Color(0x50000000), Color(0x00000000)],
    ).createShader(Rect.fromLTWH(_w - 70, 0, 70, _h));
    canvas.drawRect(Rect.fromLTWH(_w - 70, 0, 70, _h), p);

    p.shader = null;
  }

  @override
  bool shouldRepaint(WineCavePainter old) =>
      old.shelves != shelves ||
      old.selectedShelf != selectedShelf ||
      old.selectedSlot != selectedSlot;
}
