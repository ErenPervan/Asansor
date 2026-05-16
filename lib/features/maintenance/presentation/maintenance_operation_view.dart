import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../../../core/providers/connectivity_providers.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../elevator/models/elevator_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/maintenance_operation_provider.dart';

/// MaintenanceOperationView — dedicated page for technician to perform maintenance.
/// 
/// Accessed after QR code scan. Provides:
/// - Elevator details (read-only)
/// - Maintenance findings input
/// - Checklist management
/// - Photo upload
/// - Technician + customer signature capture
/// - PDF generation (future)
/// - Offline support
class MaintenanceOperationView extends ConsumerStatefulWidget {
  final String elevatorId;

  const MaintenanceOperationView({
    required this.elevatorId,
    super.key,
  });

  @override
  ConsumerState<MaintenanceOperationView> createState() =>
      _MaintenanceOperationViewState();
}

class _MaintenanceOperationViewState
    extends ConsumerState<MaintenanceOperationView> {
  final _findingsController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _techSigController = SignatureController(
    penStrokeWidth: 5,
    penColor: Colors.black87,
    exportBackgroundColor: Colors.white,
  );
  final _custSigController = SignatureController(
    penStrokeWidth: 5,
    penColor: Colors.black87,
    exportBackgroundColor: Colors.white,
  );

  final List<File> _selectedPhotos = [];
  final Map<String, bool> _checklist = {
    'Kablo kontrolü': false,
    'Kapı sensörü': false,
    'Acil fren': false,
    'Harita (limit switch)': false,
    'Operatör paneli': false,
    'Ses sinyali': false,
    'Aydınlatma': false,
    'Klima': false,
  };

  bool _customerSignatureRequired = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _findingsController.dispose();
    _techSigController.dispose();
    _custSigController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _selectedPhotos.add(File(photo.path));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotoğraf seçiminde hata: $e')),
      );
    }
  }

  Future<void> _submitMaintenance() async {
    // Validation
    if (_findingsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bulgularınızı yazın')),
      );
      return;
    }

    if (_techSigController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen teknikçi imzasını çizin')),
      );
      return;
    }

    if (_customerSignatureRequired && _custSigController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen müşteri imzasını çizin')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get current user
      final authState = ref.read(authControllerProvider);
      final user = authState.valueOrNull;
      if (user == null) {
        throw Exception('Kullanıcı kimliği alınamadı');
      }

      // Persist signatures as local files so the sync queue can upload later.
      final techSigBytes = await _techSigController.toPngBytes();
      final techSigPath = await _writeTempSignature(techSigBytes, 'tech_sig');

      String? custSigPath;
      if (_customerSignatureRequired && _custSigController.isNotEmpty) {
        final custSigBytes = await _custSigController.toPngBytes();
        custSigPath = await _writeTempSignature(custSigBytes, 'cust_sig');
      }

      // Prepare photo paths for sync queue/upload
      final photoPaths = _selectedPhotos.map((f) => f.path).toList();

      // Submit via provider
      await ref.read(maintenanceOperationControllerProvider.notifier).submitMaintenanceLog(
        elevatorId: widget.elevatorId,
        technicianId: user.id,
        findings: _findingsController.text.trim(),
        photoUrls: photoPaths,
        technicianSignatureUrl: techSigPath,
        customerSignatureUrl: custSigPath,
        pdfUrl: null, // Generated server-side
        maintenanceDate: DateTime.now(),
        checklistItems: _checklist,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Bakım logu kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back after 1 second
        Future.delayed(const Duration(seconds: 1)).then((_) {
          if (mounted) context.pop();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final elevatorAsync = ref.watch(maintenanceOperationElevatorProvider(widget.elevatorId));
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Bakım İşlemi'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: elevatorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Asansör verisi yüklenmedi: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
        data: (elevator) => SingleChildScrollView(
          child: Column(
            children: [
              // Offline banner (if applicable)
              if (!isOnline)
                const OfflineBanner(),

              // Elevator header card
              _ElevatorHeaderCard(elevator: elevator),

              const SizedBox(height: 16),

              // Main form
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Findings section
                    _SectionHeader(title: 'Bulgular'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _findingsController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Muayene bulgularınızı ayrıntılı olarak yazın...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Checklist section
                    _SectionHeader(title: 'Kontrol Listesi'),
                    const SizedBox(height: 12),
                    ..._checklist.entries.map((entry) {
                      return CheckboxListTile(
                        title: Text(entry.key),
                        value: entry.value,
                        onChanged: (val) {
                          setState(() {
                            _checklist[entry.key] = val ?? false;
                          });
                        },
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),

                    const SizedBox(height: 24),

                    // Photos section
                    _SectionHeader(title: 'Fotoğraflar'),
                    const SizedBox(height: 12),
                    if (_selectedPhotos.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedPhotos.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _selectedPhotos.length) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: _pickPhoto,
                                  child: Container(
                                    width: 100,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add, color: Colors.grey),
                                        Text('Ekle',
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _selectedPhotos[index],
                                      fit: BoxFit.cover,
                                      width: 100,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedPhotos.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _pickPhoto,
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey, width: 2),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade50,
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt,
                                  size: 32, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Fotoğraf çekmek için tıklayın'),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Technician signature
                    _SectionHeader(title: 'Teknikçi İmzası'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Signature(
                        controller: _techSigController,
                        backgroundColor: Colors.white,
                        height: 150,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _techSigController.clear(),
                          child: const Text('Temizle'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Customer signature
                    _SectionHeader(title: 'Müşteri İmzası'),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Müşteri imzası gerekli değil'),
                      value: !_customerSignatureRequired,
                      onChanged: (val) {
                        setState(() {
                          _customerSignatureRequired = !(val ?? false);
                        });
                      },
                    ),
                    if (_customerSignatureRequired) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Signature(
                          controller: _custSigController,
                          backgroundColor: Colors.white,
                          height: 150,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _custSigController.clear(),
                            child: const Text('Temizle'),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submitMaintenance,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Bakım Logu Gönder'),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _writeTempSignature(List<int>? bytes, String prefix) async {
    if (bytes == null || bytes.isEmpty) return null;
    final file = File(
      '${Directory.systemTemp.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

// ── Helper widgets ───────────────────────────────────────────────────────────

class _ElevatorHeaderCard extends StatelessWidget {
  final ElevatorModel elevator;

  const _ElevatorHeaderCard({required this.elevator});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            elevator.buildingName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (elevator.address != null)
            Text(
              elevator.address!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InfoChip(
                  label: 'Tip',
                  value: elevator.model ?? 'Bilinmiyor',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoChip(
                  label: 'Status',
                  value: elevator.status,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
