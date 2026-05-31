import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../providers/elevator_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/input_decorations.dart';
import '../../../core/widgets/section_label.dart';
import '../../../core/constants/app_durations.dart';
// ── Status options ────────────────────────────────────────────────────────────

const _statusOptions = [
  ('active', 'Aktif', Icons.check_circle_outline_rounded),
  ('inactive', 'Pasif', Icons.cancel_outlined),
  ('under_maintenance', 'Bakımda', Icons.build_outlined),
  ('faulty', 'Arızalı', Icons.warning_amber_outlined),
];

// ─────────────────────────────────────────────────────────────────────────────

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
  final MapController _mapController = MapController();

  String _status = 'active';
  bool _showLocation = false;
  int? _maintenanceDay; // null = no contract configured
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
    final ctrlState = ref.watch(elevatorCreateControllerProvider);
    final isLoading = ctrlState.isLoading;

    // Navigate to QR view on success.
    ref.listen(elevatorCreateControllerProvider, (prev, next) {
      next.whenOrNull(
        data: (elevator) {
          if (elevator != null) {
            HapticFeedback.lightImpact();
            context.pushReplacement('/admin/elevator-qr/${elevator.id}');
          }
        },
        error: (e, st) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.primary,
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
            const SnackBar(
              content: Text('Lütfen kayıt tamamlanana kadar bekleyin.'),
              backgroundColor: AppColors.error,
              duration: AppDurations.snackBarInfo,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppThemeColors.of(context).background,
        appBar: AppBar(
          title: const Text(
            'Asansör Ekle',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
            children: [
              // ── Building info ─────────────────────────────────────────
              SectionLabel(
                icon: Icons.domain_outlined,
                label: 'Bina Bilgileri',
                color: AppColors.onSurfaceVariant,
                uppercase: true,
              ),
              const SizedBox(height: 12),

              // Building name
              _Field(
                controller: _nameCtrl,
                label: 'Bina Adı',
                hint: 'örn. Merkez Plaza, Güneş Apt.',
                icon: Icons.apartment_outlined,
                required: true,
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return 'En az 2 karakter giriniz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Address
              _Field(
                controller: _addressCtrl,
                label: 'Adres',
                hint: 'Cadde, Sokak, Mahalle',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // City
              _Field(
                controller: _cityCtrl,
                label: 'Şehir',
                hint: 'örn. Ankara, İstanbul',
                icon: Icons.location_city_outlined,
              ),

              const SizedBox(height: 20),

              // ── Status ────────────────────────────────────────────────
              SectionLabel(
                icon: Icons.info_outline_rounded,
                label: 'Durum',
                color: AppColors.onSurfaceVariant,
                uppercase: true,
              ),
              const SizedBox(height: 12),
              _StatusPicker(
                selected: _status,
                onChanged: (v) => setState(() => _status = v),
              ),

              const SizedBox(height: 20),

              // ── Periodic maintenance contract ─────────────────────────
              SectionLabel(
                icon: Icons.event_repeat_outlined,
                label: 'Periyodik Bakım Sözleşmesi',
                color: AppColors.onSurfaceVariant,
                uppercase: true,
              ),
              const SizedBox(height: 12),
              _MaintenanceDayPicker(
                selected: _maintenanceDay,
                onChanged: (v) => setState(() => _maintenanceDay = v),
              ),

              const SizedBox(height: 20),

              // ── Location (optional, collapsible) ─────────────────────
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _showLocation = !_showLocation),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.my_location_rounded,
                        size: 18,
                        color: _showLocation
                            ? AppColors.primary
                            : AppColors.outline,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedLatLng == null
                              ? 'GPS Konumu (İsteğe Bağlı)'
                              : 'GPS Konumu • ${_selectedLatLng!.latitude.toStringAsFixed(5)}, '
                                    '${_selectedLatLng!.longitude.toStringAsFixed(5)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _showLocation
                                ? AppColors.primary
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Icon(
                        _showLocation
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AppColors.outline,
                      ),
                    ],
                  ),
                ),
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _showLocation
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 200,
                                child: FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter:
                                        _selectedLatLng ??
                                        const LatLng(39.9334, 32.8597),
                                    initialZoom: 13,
                                    onTap: (_, point) {
                                      setState(() {
                                        _selectedLatLng = point;
                                        _latCtrl.text = point.latitude
                                            .toStringAsFixed(6);
                                        _lngCtrl.text = point.longitude
                                            .toStringAsFixed(6);
                                      });
                                    },
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.asansor.app',
                                    ),
                                    if (_selectedLatLng != null)
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            point: _selectedLatLng!,
                                            width: 44,
                                            height: 44,
                                            child: const Icon(
                                              Icons.location_pin,
                                              color: AppColors.primary,
                                              size: 36,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Haritaya dokunarak konum pinini belirleyin.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Field(
                              controller: _latCtrl,
                              label: 'Enlem',
                              hint: 'örn. 39.9334',
                              icon: Icons.arrow_upward_rounded,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              validator: _validateCoord(
                                'Enlem',
                                min: -90,
                                max: 90,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Field(
                              controller: _lngCtrl,
                              label: 'Boylam',
                              hint: 'örn. 32.8597',
                              icon: Icons.arrow_forward_rounded,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              validator: _validateCoord(
                                'Boylam',
                                min: -180,
                                max: 180,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              FilledButton.icon(
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(
                  isLoading ? 'Oluşturuluyor…' : 'Asansör Oluştur',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  backgroundColor: AppColors.primary,
                ),
                onPressed: isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Build the full address by combining address + city.
    final addressParts = [
      _addressCtrl.text.trim(),
      _cityCtrl.text.trim(),
    ].where((s) => s.isNotEmpty).toList();
    final fullAddress = addressParts.isEmpty ? null : addressParts.join(', ');

    final lat = _latCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_latCtrl.text.trim());
    final lng = _lngCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_lngCtrl.text.trim());

    ref
        .read(elevatorCreateControllerProvider.notifier)
        .create(
          buildingName: _nameCtrl.text.trim(),
          address: fullAddress,
          status: _status,
          latitude: lat,
          longitude: lng,
          maintenanceDay: _maintenanceDay,
        );
  }

  /// Returns a validator for coordinate fields.
  String? Function(String?) _validateCoord(
    String label, {
    required double min,
    required double max,
  }) {
    return (v) {
      if (v == null || v.trim().isEmpty) return null; // optional
      final parsed = double.tryParse(v.trim());
      if (parsed == null) return '$label geçerli bir sayı olmalıdır';
      if (parsed < min || parsed > max) {
        return '$label $min ile $max arasında olmalıdır';
      }
      return null;
    };
  }
}

// ── Section header ────────────────────────────────────────────────────────────

// ── Text field ────────────────────────────────────────────────────────────────

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
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: AppColors.onSurface),
      decoration: appInputDecoration(
        label: required ? '$label *' : label,
        hint: hint,
        prefixIcon: Icon(icon, size: 18, color: AppColors.outline),
        fillColor: AppColors.surface,
        radius: 12,
      ),
      validator: validator,
    );
  }
}

// ── Maintenance day picker ────────────────────────────────────────────────────

/// Lets the admin pick a contract maintenance day (1–28) or leave it unset.
///
/// Displays as a labelled row with a DropdownButtonFormField.  Selecting
/// "Seçilmedi" clears the value (null = no contract).
class _MaintenanceDayPicker extends StatelessWidget {
  const _MaintenanceDayPicker({
    required this.selected,
    required this.onChanged,
  });

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      initialValue: selected,
      isExpanded: true,
      decoration: appInputDecoration(
        label: 'Sözleşme Bakım Günü',
        hint: 'Ayın kaçında bakım yapılacak?',
        prefixIcon: const Icon(
          Icons.calendar_month_outlined,
          size: 18,
          color: AppColors.outline,
        ),
        fillColor: AppColors.surface,
        radius: 12,
      ),
      style: const TextStyle(fontSize: 15, color: AppColors.onSurface),
      items: [
        // Unset option
        const DropdownMenuItem<int?>(
          value: null,
          child: Text(
            'Seçilmedi (sözleşme yok)',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ),
        // Days 1–28
        for (int day = 1; day <= 28; day++)
          DropdownMenuItem<int?>(
            value: day,
            child: Text('Her ayın $day. günü'),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

// ── Status picker ─────────────────────────────────────────────────────────────

class _StatusPicker extends StatelessWidget {
  const _StatusPicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (val, lbl, ico) in _statusOptions)
          _StatusChip(
            value: val,
            label: lbl,
            icon: ico,
            isSelected: selected == val,
            onTap: () => onChanged(val),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.value,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(value, isSelected);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? fg.withValues(alpha: 0.5)
                : AppColors.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static (Color, Color) _colors(String val, bool selected) {
    if (!selected) return (AppColors.surface, AppColors.outline);
    switch (val) {
      case 'active':
        return (const Color(0xFFDCFCE7), const Color(0xFF166534));
      case 'faulty':
        return (const Color(0xFFFEE2E2), const Color(0xFFB91C1C));
      case 'under_maintenance':
        return (const Color(0xFFFFF7ED), const Color(0xFF92400E));
      default: // inactive
        return (AppColors.surfaceContainer, AppColors.onSurfaceVariant);
    }
  }
}
