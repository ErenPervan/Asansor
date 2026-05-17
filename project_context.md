# Project Context: Asansor (Elevator Maintenance & Fault Tracking System)

This document provides a comprehensive overview of the **Asansor** project, a technical service application built with Flutter and Supabase. It is designed to be read by an AI assistant to gain immediate context for code generation or architectural advice.

---

## 1. Project Overview & Purpose
**Asansor** is a professional tool for elevator maintenance companies. It streamlines the workflow between field technicians, office administrators, and building managers.

### Core Functionality:
- **Fault Reporting:** Quick reporting of elevator malfunctions with photo attachments, fault types (Mekanik, Elektrik, Mahsur), and priority levels.
- **Maintenance Logging:** Standardized maintenance checkups with dynamic checklists, technician/customer signatures, and photo evidence.
- **Automated Reporting:** Real-time generation of professional Material-3 style PDF maintenance reports upon task completion.
- **Scheduling:** Management of periodic maintenance visits and emergency tasks.
- **Offline-First Synchronization:** Robust handling of field work in low-connectivity areas using a local sync queue.
- **Real-Time Notifications:** Push notifications for assigned tasks and urgent fault reports via Firebase Cloud Messaging (FCM).
- **Live Map:** Visualization of all elevators on a map for better routing and technician dispatching.

---

## 2. Tech Stack & Architecture

### Frontend (Flutter/Dart)
- **State Management:** `flutter_riverpod` (v2.6.1) - Used for all business logic, data fetching, and state reactivity.
- **Routing:** `go_router` (v15.1.2) - Declarative routing with deep link support.
- **Offline Storage:** `hive` (v2.2.3) - Used for local caching and the synchronization queue.
- **PDF Generation:** `pdf` and `printing` - Custom high-fidelity report layouts.
- **Networking:** `supabase_flutter` (v2.9.0) for primary backend communication; `connectivity_plus` for network status detection.
- **Architecture Pattern:** Feature-based modularity (`lib/features/`). Each feature contains its own models, views, and providers.

### Backend (Supabase)
- **Database:** PostgreSQL (Managed by Supabase).
- **Auth:** Supabase Auth (Email/Password) with Role-Based Access Control (RBAC).
- **Storage:** Supabase Storage for fault photos, signatures, and generated PDF reports.
- **Real-time:** Supabase real-time subscriptions for notification delivery.

### Offline-First Logic (`SyncQueueService`)
The application implements a "Write-Ahead" local queue strategy:
1. Operations (maintenance logs, fault reports) are first serialized and stored in a Hive box (`pending_sync`).
2. A background service monitors connectivity and flushes the queue when online.
3. Successful syncs trigger secondary actions (e.g., PDF generation and storage upload).

---

## 3. Directory Structure

```text
lib/
├── core/                   # Shared logic and global singletons
│   ├── constants/          # Supabase keys, theme tokens, static strings
│   ├── providers/          # Global Riverpod providers (connectivity, etc.)
│   ├── router/             # GoRouter configuration and route definitions
│   ├── services/           # Core logic (PdfService, SyncQueueService, etc.)
│   ├── theme/              # Material 3 theme data and color schemes
│   └── widgets/            # Reusable UI components (buttons, cards, inputs)
├── features/               # Functional modules
│   ├── admin/              # Management dashboard, scheduling, user management
│   ├── auth/               # Login, profile, and session management
│   ├── elevator/           # Elevator list, detail view, and live map
│   ├── fault/              # Fault reporting and resolution workflow
│   └── maintenance/        # Checklists, log entry, and report viewing
├── firebase_options.dart   # FCM configuration
└── main.dart               # App entry point and provider initialization
```

---

## 4. Backend State & Database Schema

### Public Tables (Fetched via Supabase MCP)

| Table | Primary Key | Key Columns | Relationships |
| :--- | :--- | :--- | :--- |
| **`elevators`** | `id` (uuid) | `building_name`, `status` (Active/Faulty), `maintenance_day`, `model`, `capacity`, `inspection_status` | Linked to `maintenance_logs`, `fault_reports` |
| **`fault_reports`** | `id` (uuid) | `elevator_id`, `description`, `fault_type`, `priority`, `is_resolved` | Foreign key: `elevator_id -> elevators.id` |
| **`maintenance_logs`** | `id` (uuid) | `elevator_id`, `technician_id`, `checklist` (jsonb), `pdf_url`, `signature_url` | Foreign key: `elevator_id -> elevators.id` |
| **`maintenance_schedules`** | `id` (uuid) | `elevator_id`, `technician_id`, `scheduled_date`, `status` | Foreign key: `technician_id -> auth.users.id` |
| **`profiles`** | `id` (uuid) | `full_name`, `role` (admin/technician/customer), `fcm_token` | References `auth.users.id` |
| **`notifications`** | `id` (uuid) | `user_id`, `title`, `body`, `is_read` | References `profiles.id` |
| **`checklist_items`** | `id` (uuid) | `label`, `description`, `is_active` | Template for maintenance tasks |

### Row Level Security (RLS)
- **Admins:** Full `ALL` access to all tables.
- **Technicians:** `SELECT` on all elevators/faults; `INSERT`/`UPDATE` on own assigned schedules and maintenance logs.
- **Customers:** `SELECT` only for elevators/logs/schedules associated with their `elevator_id` in their profile.
- **Public:** `INSERT` only for anonymous fault reporting (if enabled).

### Storage Buckets
- `fault-images`: Public bucket for malfunction photos.
- `maintenance-records`: Evidence photos taken during maintenance.
- `maintenance-reports`: Public bucket for generated PDF reports.

---

## 5. Completed Features
- [x] **Secure Auth:** Login/Logout with profile role detection.
- [x] **Elevator Dashboard:** Material 3 detail view with real-time status and history.
- [x] **Fault Workflow:** Creation of fault reports with type/priority selection and photo upload.
- [x] **Maintenance Execution:** Digital checklist implementation with signature capture.
- [x] **PDF Engine:** Automated generation of professional reports with corporate branding and Turkish character support.
- [x] **Offline Sync:** Automatic queuing of data when internet is lost and silent syncing upon restoration.
- [x] **Live Map:** Interactive map showing elevator locations and health status.

---

## 6. Pending Tasks (To-Do)
- [ ] **Telemetry Integration:** Connecting the "Daily Turn" and "System Health" indicators to real-time sensors (placeholder logic currently exists).
- [ ] **Advanced Analytics:** Admin dashboard for calculating MTBF (Mean Time Between Failures) and technician performance.
- [ ] **Dynamic Checklists:** UI for admins to modify `checklist_items` without code changes.
- [ ] **Multi-language Support:** Localization for English/German in addition to the current Turkish UI.
- [ ] **Customer Portal:** Dedicated simplified view for building residents to track maintenance status.
