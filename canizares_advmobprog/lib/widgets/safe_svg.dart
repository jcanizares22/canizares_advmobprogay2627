import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

class SafeSvg extends StatelessWidget {
  final String assetName;
  final double? width;
  final double? height;
  final BoxFit fit;

  const SafeSvg.asset(this.assetName, {super.key, this.width, this.height, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _loadAndSanitize(assetName),
      builder: (context, snap) {
        if (snap.hasData) {
          try {
            return SvgPicture.string(
              snap.data!,
              width: width,
              height: height,
              fit: fit,
            );
          } catch (_) {
            return SizedBox(width: width, height: height, child: const FlutterLogo());
          }
        }
        if (snap.hasError) return SizedBox(width: width, height: height, child: const FlutterLogo());
        return SizedBox(width: width, height: height);
      },
    );
  }

  static Future<String> _loadAndSanitize(String asset) async {
    var s = await rootBundle.loadString(asset);

    // Remove unsupported unit suffixes (pt, px) on width/height attributes
    s = s.replaceAllMapped(RegExp(r'width="(\d+(?:\.\d+)?)(pt|px)"'), (m) => 'width="${m[1]}"');
    s = s.replaceAllMapped(RegExp(r'height="(\d+(?:\.\d+)?)(pt|px)"'), (m) => 'height="${m[1]}"');

    // If <defs> exists and is referenced before definition, move it right after the opening <svg> tag.
    final defsStart = s.indexOf('<defs');
    final defsEnd = s.indexOf('</defs>');
    final svgOpenEnd = s.indexOf('>');
    if (defsStart != -1 && defsEnd != -1 && svgOpenEnd != -1 && defsStart > svgOpenEnd) {
      final defsBlock = s.substring(defsStart, defsEnd + 7);
      s = s.replaceFirst(defsBlock, '');
      s = s.substring(0, svgOpenEnd + 1) + defsBlock + s.substring(svgOpenEnd + 1);
    }

    return s;
  }
}
