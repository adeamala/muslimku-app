import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/features/hadith/application/hadits_providers.dart';
import 'package:muslimku/features/hadith/presentation/arbain_tab.dart';
import 'package:muslimku/features/hadith/presentation/bulughul_tab.dart';
import 'package:muslimku/features/hadith/presentation/perawi_tab.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// The Hadits tab (design-v2 h1–h3): Arbain, Bulughul Maram and 9 Perawi.
class HadithScreen extends ConsumerStatefulWidget {
  const HadithScreen({super.key});

  @override
  ConsumerState<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends ConsumerState<HadithScreen> {
  int _segment = 0;

  /// Segments are built on first visit (Bulughul Maram downloads while it
  /// is open) and then kept, with their scroll position.
  final Set<int> _opened = {0};

  @override
  Widget build(BuildContext context) {
    final arbainCount = ref.watch(arbainListProvider).valueOrNull?.data.length;
    return SenjaTabScaffold(
      title: 'Hadits',
      subtitle: 'Arbain, Bulughul Maram,\ndan 9 Perawi',
      hero: 'images/3d/icon_hadits.webp',
      heroWidth: 150,
      heroTop: 48,
      heroRight: 14,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: SenjaSegmented(
              items: [
                SenjaSegment('Arbain', count: arbainCount ?? 42),
                const SenjaSegment('Bulughul Maram'),
                const SenjaSegment('9 Perawi'),
              ],
              selected: _segment,
              onChanged: (index) => setState(() {
                _segment = index;
                _opened.add(index);
              }),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _segment,
              sizing: StackFit.expand,
              children: [
                const ArbainTab(),
                if (_opened.contains(1))
                  const BulughulTab()
                else
                  const SizedBox.shrink(),
                if (_opened.contains(2))
                  const PerawiTab()
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
