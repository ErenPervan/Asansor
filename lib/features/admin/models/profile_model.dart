/// Maps to the `profiles` table in Supabase.
///
/// Run the following SQL once in the Supabase SQL editor to create the table,
/// auto-create a profile for every new sign-up, and set RLS policies:
///
/// ```sql
/// -- 1. Table
/// create table public.profiles (
///   id          uuid references auth.users on delete cascade primary key,
///   email       text,
///   full_name   text,
///   phone       text,
///   role        text not null default 'technician',
///   elevator_id uuid references public.elevators(id) on delete set null
/// );
///
/// -- 2. Auto-create a profile row when a new user signs up
/// create or replace function public.handle_new_user()
/// returns trigger as $$
/// begin
///   insert into public.profiles (id, email)
///   values (new.id, new.email)
///   on conflict (id) do nothing;
///   return new;
/// end;
/// $$ language plpgsql security definer;
///
/// create trigger on_auth_user_created
///   after insert on auth.users
///   for each row execute procedure public.handle_new_user();
///
/// -- 3. RLS
/// alter table public.profiles enable row level security;
///
/// create policy "Authenticated users can read all profiles"
///   on public.profiles for select to authenticated using (true);
///
/// create policy "Users can update own profile"
///   on public.profiles for update using (auth.uid() = id);
///
/// create policy "Admins can update any profile"
///   on public.profiles for update
///   using ((select role from public.profiles where id = auth.uid()) = 'admin');
/// ```
library;

import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/enums/app_capability.dart';

class ProfileModel {
  const ProfileModel({
    required this.id,
    this.email,
    this.fullName,
    this.phone,
    required this.role,
    this.elevatorId,
  });

  final String id;
  final String? email;
  final String? fullName;
  final String? phone;

  final UserRole role;

  /// Only relevant for the `customer` role.
  /// References the elevator (and therefore building) this customer belongs to.
  final String? elevatorId;

  // ── Factories ──────────────────────────────────────────────────────────────

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      role: UserRole.fromDb(json['role'] as String?),
      elevatorId: json['elevator_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'phone': phone,
    'role': role.dbValue,
    'elevator_id': elevatorId,
  };

  ProfileModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    UserRole? role,
    String? elevatorId,
    bool clearElevatorId = false,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      elevatorId: clearElevatorId ? null : (elevatorId ?? this.elevatorId),
    );
  }

  // ── Computed helpers ───────────────────────────────────────────────────────

  /// Best-effort display name: fullName → email prefix → shortened id.
  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!.trim();
    }
    if (email != null && email!.isNotEmpty) return email!.split('@').first;
    return id.length >= 8 ? id.substring(0, 8) : id;
  }

  /// Initials for the avatar circle (1–2 characters).
  String get initials {
    final name = displayName;
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(1, 2)).toUpperCase();
  }

  /// Turkish localised role label.
  String get roleTr {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.technician:
        return 'Teknisyen';
      case UserRole.customer:
        return 'Müşteri';
    }
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isTechnician => role == UserRole.technician;
  bool get isCustomer => role == UserRole.customer;

  // ── Capability Check ───────────────────────────────────────────────────────

  /// Bu profilin belirtilen yeteneğe ([AppCapability]) sahip olup olmadığını
  /// döndürür. Yetki kontrolleri bu metot üzerinden yapılmalıdır.
  bool can(AppCapability capability) =>
      capabilityMatrix[role]?.contains(capability) ?? false;

  @override
  String toString() =>
      'ProfileModel(id: $id, role: ${role.name}, email: $email, '
      'fullName: $fullName)';
}
