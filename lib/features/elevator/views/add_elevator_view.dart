import 'package:asansor/core/constants/app_durations.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/app_form_field.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

const _statusOptions = [
  ('active', 'Aktif', Icons.check_circle_rounded),
  ('inactive', 'Pasif', Icons.do_not_disturb_on_rounded),
  ('under_maintenance', 'Bakımda', Icons.build_rounded),
  ('faulty', 'Arızalı', Icons.warning_rounded),
];

class AddElevatorView extends ConsumerStatefulWidget {
  const AddElevatorView({super.key});

  @override
  ConsumerState<AddElevatorView> createState() => _AddElevatorViewState();
}

class _AddElevatorViewState extends ConsumerState<AddElevatorView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _mapController = MapController();

  String _status = 'active';
  bool _showLocation = true;
  int? _maintenanceDay;
  LatLng? _selectedLatLng;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final ctrlState = ref.watch(elevatorCreateControllerProvider);
    final isLoading = ctrlState.isLoading;

    ref.listen(elevatorCreateControllerProvider, (prev, next) {
      next.whenOrNull(
        data: (elevator) {
          if (elevator != null) {
            HapticFeedback.lightImpact();
            context.pushReplacement('/admin/elevator-qr/${elevator.id}');
          }
        },
        error: (error, _) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $error'),
              backgroundColor: colors.error,
              behavior: SnackBarBehavior.floating,
              duration: AppDurations.snackBarError,
            ),
          );
        },
      );
    });

    return PopScope(
      canPop: !isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Lütfen kayıt tamamlanana kadar bekleyin.'),
              backgroundColor: colors.error,
              duration: AppDurations.snackBarInfo,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface.withValues(alpha: 0.92),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            tooltip: 'Geri',
            onPressed: isLoading ? null : () => context.pop(),
          ),
          title: Text(
            'Asansör Ekle',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              110,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _HeroHeader(),
                      const SizedBox(height: AppSpacing.lg),
                      _FormSection(
                        title: 'Bina Bilgileri',
                        subtitle: 'Tesis adı ve adres bilgileri',
                        icon: Icons.apartment_rounded,
                        child: Column(
                          children: [
                            _Field(
                              controller: _nameCtrl,
                              label: 'Bina/Tesis Adı',
                              hint: 'Örn: Plaza Merkez',
                              icon: Icons.business_rounded,
                              required: true,
                              validator: (value) {
                                if (value == null || value.trim().length < 2) {
                                  return 'En az 2 karakter giriniz';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _Field(
                              controller: _addressCtrl,
                              label: 'Açık Adres',
                              hint: 'Sokak, mahalle, no...',
                              icon: Icons.location_on_rounded,
                              maxLines: 3,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _Field(
                              controller: _cityCtrl,
                              label: 'Şehir',
                              hint: 'Örn: İstanbul',
                              icon: Icons.location_city_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _FormSection(
                        title: 'Mevcut Durum',
                        subtitle: 'Ünitenin başlangıç çalışma durumunu seçin',
                        icon: Icons.info_rounded,
                        child: _StatusPicker(
                          selected: _status,
                          onChanged: (value) => setState(() => _status = value),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _FormSection(
                        title: 'Periyodik Bakım Sözleşmesi',
                        subtitle: 'Otomatik bakım planlama için ay günü',
                        icon: Icons.event_repeat_rounded,
                        badge: 'Önerilen',
                        child: _MaintenanceDayPicker(
                          selected: _maintenanceDay,
                          onChanged: (value) =>
                              setState(() => _maintenanceDay = value),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _LocationSection(
                        isExpanded: _showLocation,
                        selectedLatLng: _selectedLatLng,
                        latController: _latCtrl,
                        lngController: _lngCtrl,
                        mapController: _mapController,
                        onToggle: () =>
                            setState(() => _showLocation = !_showLocation),
                        onMapTap: (point) {
                          setState(() {
                            _selectedLatLng = point;
                            _latCtrl.text = point.latitude.toStringAsFixed(6);
                            _lngCtrl.text = point.longitude.toStringAsFixed(6);
                          });
                        },
                        validateLat: _validateCoord(
                          'Enlem',
                          min: -90,
                          max: 90,
                        ),
                        validateLng: _validateCoord(
                          'Boylam',
                          min: -180,
                          max: 180,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton.icon(
                        onPressed: isLoading ? null : _submit,
                        icon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          isLoading ? 'Kaydediliyor...' : 'Sisteme Kaydet',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: colors.primaryDark,
                          foregroundColor: colors.onPrimary,
                          textStyle: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final addressParts = [
      _addressCtrl.text.trim(),
      _cityCtrl.text.trim(),
    ].where((item) => item.isNotEmpty).toList();
    final fullAddress = addressParts.isEmpty ? null : addressParts.join(', ');
    final lat = _latCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_latCtrl.text.trim());
    final lng = _lngCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_lngCtrl.text.trim());

    ref.read(elevatorCreateControllerProvider.notifier).create(
          buildingName: _nameCtrl.text.trim(),
          address: fullAddress,
          status: _status,
          latitude: lat,
          longitude: lng,
          maintenanceDay: _maintenanceDay,
        );
  }

  String? Function(String?) _validateCoord(
    String label, {
    required double min,
    required double max,
  }) {
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      final parsed = double.tryParse(value.trim());
      if (parsed == null) return '$label geçerli bir sayı olmalıdır';
      if (parsed < min || parsed > max) {
        return '$label $min ile $max arasında olmalıdır';
      }
      return null;
    };
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.primaryDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.16),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -38,
            top: -52,
            child: Icon(
              Icons.elevator_rounded,
              size: 180,
              color: colors.onPrimary.withValues(alpha: 0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.add_business_rounded, color: colors.onPrimary),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Yeni Asansör Ekle',
                style: textTheme.headlineMedium?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sisteme yeni bir ünite kaydedin. Teknik ve lokasyon bilgilerini eksiksiz girin.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimary.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primaryFixed.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: colors.primaryDark),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.26),
                    ),
                  ),
                  child: Text(
                    badge!,
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.warning,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return AppFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      label: required ? '$label *' : label,
      hint: hint,
      prefixIcon: Icon(icon, size: 19, color: colors.outline),
      validator: validator,
    );
  }
}

class _StatusPicker extends StatelessWidget {
  const _StatusPicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 4 : 2;
        final spacing = AppSpacing.sm;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final (value, label, icon) in _statusOptions)
              SizedBox(
                width: width,
                child: _StatusTile(
                  value: value,
                  label: label,
                  icon: icon,
                  selected: selected == value,
                  onTap: () => onChanged(value),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final accent = _statusColor(value, colors);

    return Material(
      color: selected ? accent.withValues(alpha: 0.1) : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 94,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.58)
                  : colors.outlineVariant.withValues(alpha: 0.42),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accent, size: 26),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? accent : colors.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaintenanceDayPicker extends StatelessWidget {
  const _MaintenanceDayPicker({
    required this.selected,
    required this.onChanged,
  });

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.36),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.verified_user_rounded, color: colors.warning),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Bakım günü seçilirse periyodik görev planlamasında kullanılacaktır.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<int?>(
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Aylık Bakım Günü',
            hintText: 'Gün seçin',
            prefixIcon: Icon(Icons.calendar_month_rounded, color: colors.outline),
            filled: true,
            fillColor: colors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.34),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.primary, width: 1.4),
            ),
          ),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(
                'Seçilmedi (sözleşme yok)',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            for (var day = 1; day <= 28; day++)
              DropdownMenuItem<int?>(
                value: day,
                child: Text('Her ayın $day. günü'),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({
    required this.isExpanded,
    required this.selectedLatLng,
    required this.latController,
    required this.lngController,
    required this.mapController,
    required this.onToggle,
    required this.onMapTap,
    required this.validateLat,
    required this.validateLng,
  });

  final bool isExpanded;
  final LatLng? selectedLatLng;
  final TextEditingController latController;
  final TextEditingController lngController;
  final MapController mapController;
  final VoidCallback onToggle;
  final ValueChanged<LatLng> onMapTap;
  final String? Function(String?) validateLat;
  final String? Function(String?) validateLng;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return _FormSection(
      title: 'GPS Konumu',
      subtitle: selectedLatLng == null
          ? 'İsteğe bağlı harita ve koordinat bilgisi'
          : '${selectedLatLng!.latitude.toStringAsFixed(5)}, '
              '${selectedLatLng!.longitude.toStringAsFixed(5)}',
      icon: Icons.satellite_alt_rounded,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.36),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_location_alt_rounded, color: colors.primaryDark),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      selectedLatLng == null
                          ? 'Haritadan konum seç'
                          : 'Konum pini seçildi',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: colors.outline,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            height: 250,
                            child: FlutterMap(
                              mapController: mapController,
                              options: MapOptions(
                                initialCenter:
                                    selectedLatLng ?? const LatLng(39.9334, 32.8597),
                                initialZoom: 13,
                                onTap: (_, point) => onMapTap(point),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.asansor.app',
                                ),
                                if (selectedLatLng != null)
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: selectedLatLng!,
                                        width: 48,
                                        height: 48,
                                        child: Icon(
                                          Icons.location_pin,
                                          color: colors.primaryDark,
                                          size: 40,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Haritaya dokunarak konum pinini belirleyin.',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 620;
                            final latField = _Field(
                              controller: latController,
                              label: 'Enlem',
                              hint: 'Örn: 41.0082',
                              icon: Icons.north_rounded,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              validator: validateLat,
                            );
                            final lngField = _Field(
                              controller: lngController,
                              label: 'Boylam',
                              hint: 'Örn: 28.9784',
                              icon: Icons.east_rounded,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              validator: validateLng,
                            );

                            if (!isWide) {
                              return Column(
                                children: [
                                  latField,
                                  const SizedBox(height: AppSpacing.md),
                                  lngField,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: latField),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: lngField),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String value, AppThemeColors colors) {
  return switch (value) {
    'active' => colors.success,
    'faulty' => colors.error,
    'under_maintenance' => colors.warning,
    _ => colors.outline,
  };
}
