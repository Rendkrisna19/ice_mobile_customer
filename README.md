# ICE Mobile Customer App

**Document Reference:** SAD-ICE-2026-FINAL  
**Type:** Mobile Native (Android/iOS)  
**Stack:** Flutter, Riverpod, Clean Architecture

## 1. Overview
Aplikasi ini khusus untuk **End-Customer**. Fokus utama adalah UX yang smooth dan validasi data stok yang akurat sebelum checkout.

## 2. Architecture: Clean Architecture + Riverpod
Project ini memisahkan kode ke dalam 3 layer utama di setiap fitur (`features/nama_fitur/`):

### A. Domain Layer (Pure Dart)
*Isi: Business Logic & Contracts (Abstract).*
* `entities/`: Object murni (misal: `Product`, `CartItem`).
* `repositories/`: Interface abstract dari repository.
* `usecases/`: Single action logic (contoh: `ValidateCartUseCase.dart`).

### B. Data Layer (Implementation)
*Isi: API Calls & JSON Parsing.*
* `models/`: Turunan entity dengan fungsi `fromJson`/`toJson`.
* `datasources/`: Kode `Dio` untuk request ke API.
* `repositories/`: Implementasi interface domain, menghubungkan datasource.

### C. Presentation Layer (UI)
*Isi: Widgets & State Management.*
* `pages/`: Halaman penuh (Scaffold).
* `widgets/`: Komponen kecil (misal: `MenuCard.dart`, `CartSummary.dart`).
* `providers/`: Riverpod Providers (State management).

## 3. Key Features Implementation Guidelines

### Menu Availability (Optimistic UI)
SAD mewajibkan UI menangani stok `is_available = false`:
* **Menu Card:** Harus di-greyed out (disabled) secara visual.
* **Interaction:** Tombol "Add" disembunyikan.

### Cart Logic
* **Validation:** Wajib memanggil `ValidateCartUseCase` sebelum checkout untuk mengecek stok terakhir di server.
* **Pricing:** Total harga dihitung ulang berdasarkan response API (jangan percaya data lokal 100%).

## 4. Setup & Run
1.  **Generate Code (JsonSerializable):**
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```
2.  **Run App:**
    ```bash
    flutter run
    ```
