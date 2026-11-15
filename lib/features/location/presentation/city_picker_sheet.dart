import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/location/application/location_provider.dart';
import 'package:muslimku/features/location/domain/default_city.dart';
import 'package:muslimku/features/prayer/domain/prayer_schedule.dart';

Future<void> showCityPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (context) => const CityPickerSheet(),
  );
}

/// Search MyQuran's city list and pick the city for the prayer schedule.
class CityPickerSheet extends ConsumerStatefulWidget {
  const CityPickerSheet({super.key});

  @override
  ConsumerState<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends ConsumerState<CityPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        ref.read(locationProvider.notifier).searchCities(value.trim());
      }
    });
    setState(() {}); // refresh the clear button
  }

  Future<void> _select(Map<String, dynamic> city) async {
    final navigator = Navigator.of(context);
    await ref
        .read(locationProvider.notifier)
        .selectCity(city['id'].toString(), city['lokasi'].toString());
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(locationProvider);
    final current = state.activeCityName;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pilih lokasi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            current == null
                ? 'Jadwal sholat memakai ${DefaultCity.name} sampai kamu '
                      'memilih kota.'
                : 'Sekarang: ${titleCaseCity(current)}',
            style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Cari kota atau kabupaten…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: state.isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        ref
                            .read(locationProvider.notifier)
                            .clearSearchResults();
                        setState(() {});
                      },
                    ),
              filled: true,
              fillColor: AppColors.lilac,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 10),
            Text(
              state.error!,
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ],
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.4,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: state.searchResults.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: AppColors.lilacLine),
              itemBuilder: (context, i) {
                final city = state.searchResults[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(
                    Icons.location_city_rounded,
                    color: AppColors.secondary,
                  ),
                  title: Text(
                    titleCaseCity(city['lokasi'].toString()),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  onTap: () => _select(city),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
