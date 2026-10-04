# MyFuturePet Project Progress Handoff

Last updated: 2026-09-12 23:14 (UTC+08:00)

## Latest Handoff Snapshot

This document is intended to be uploaded to another AI platform so work can continue without reconstructing the project history.

### Immediate priority

The Flutter project currently contains a confirmed Dart syntax error in `lib/screens/register_screen.dart`. In `_showMessage`, this line is invalid:

```dart
String message, {np
```

It must be:

```dart
String message, {
```

Do not assume the Flutter project is buildable until this is corrected and `flutter analyze` passes.

### Current admin dashboard issue

The React admin dashboard still requests profile name columns that may not exist in Supabase. The confirmed database error from the earlier session was:

```text
column profiles_1.fullname does not exist
```

The current source uses `full_name` in several places. Both `fullname` and `full_name` must be checked against the real `profiles` schema before changing queries. A safe temporary fallback is to select `id, email` and display the email address.

Affected files currently include:

- `myfuturepet-admin/src/components/AdoptionMonitoring.js`
- `myfuturepet-admin/src/components/CommunityPosts.js`
- `myfuturepet-admin/src/components/Notifications.js`
- `myfuturepet-admin/src/components/DashboardOverview.js`
- `myfuturepet-admin/src/components/UserManagement.js`

### Required validation after fixes

Run these commands from the respective project folders:

```powershell
cd "C:\Users\Acer User\Videos\MyFuturePetV1\myfuturepet"
flutter analyze
flutter test
```

```powershell
cd "C:\Users\Acer User\Videos\MyFuturePetV1\myfuturepet-admin"
npm run build
```

Then test the Flutter registration flow and the admin pages for adoption monitoring, community posts, announcements, reports, users, and shelters against real Supabase data.

## Purpose

MyFuturePet is a Flutter capstone application for pet adoption. A separate React web admin dashboard is being developed so administrators can manage the system from a browser/desktop without adding admin screens to the Flutter mobile app.

## Workspace Layout

- Flutter app: `C:\Users\Acer User\Videos\MyFuturePetV1\myfuturepet`
- React admin dashboard: `C:\Users\Acer User\Videos\MyFuturePetV1\myfuturepet-admin`
- Supabase project is shared by both applications.

The Flutter folder is a Git repository on branch `main`. The admin dashboard is a sibling folder and is not currently inside the Flutter repository.

## Flutter App: Current State

### Technology

- Flutter
- Supabase Flutter SDK
- Shared Preferences
- Flutter Launcher Icons
- Dart SDK constraint: `^3.12.2`

### Existing Flutter source

- `lib/main.dart`
- `lib/config/supabase_config.dart`
- `lib/services/auth_service.dart`
- `lib/screens/splash_screen.dart`
- `lib/screens/onboarding_screen.dart`
- `lib/screens/login_screen.dart`
- `lib/screens/register_screen.dart`
- `lib/screens/home_screen.dart`

### Existing Flutter functionality

- Splash and onboarding screens
- Login and registration screens
- Supabase authentication service
- Home screen
- Supabase project configuration
- Image assets configured in `pubspec.yaml`

### Flutter dependencies

Important dependencies in `pubspec.yaml`:

- `supabase_flutter: ^2.17.1`
- `shared_preferences: ^2.5.5`
- `flutter_launcher_icons: ^0.14.4`

### Flutter setup commands

From the Flutter project folder:

```powershell
cd "C:\Users\Acer User\Videos\MyFuturePetV1\myfuturepet"
flutter pub get
flutter run -d windows
```

The project previously required a newer Flutter/Dart version than was installed. Updating Flutter was necessary before dependency resolution.

## Supabase Database State

The original tables currently available were:

### `profiles`

Known columns:

- `id`
- `email`
- `create_at` (verify whether the real column is `create_at` or `created_at`)

Important: The admin dashboard code previously assumed a `fullname` column, but the current Supabase schema does not have it. Queries that select `profiles.fullname` fail with:

```text
column profiles_1.fullname does not exist
```

### `pets`

Known columns:

- `id`
- `name`
- `breed`
- `species`
- `age`
- `description`
- `image_url`
- `location`
- `is_available`
- `created_at`

### Tables added or planned for the admin dashboard

The following tables were created/planned through Supabase SQL:

- `shelters`
- `adoptions`
- `community_posts`
- `announcements`

The `shelters` table was created successfully and RLS policies were reset successfully. A test shelter may have been inserted.

Expected columns:

#### `shelters`

- `id`
- `name`
- `email`
- `phone`
- `location`
- `is_active`
- `created_at`

#### `adoptions`

- `id`
- `pet_id` references `pets.id`
- `adopter_id` references `profiles.id`
- `shelter_id` references `shelters.id`
- `status`
- `application_date`
- `completion_date`
- `notes`
- `created_at`
- `updated_at`

#### `community_posts`

- `id`
- `user_id` references `profiles.id`
- `title`
- `content`
- `image_url`
- `category`
- `is_approved`
- `report_count`
- `created_at`
- `updated_at`

#### `announcements`

- `id`
- `admin_id` references `profiles.id`
- `title`
- `content`
- `target_audience`
- `is_published`
- `sent_at`
- `created_at`
- `updated_at`

## React Admin Dashboard: Current State

### Technology

- React
- Supabase JavaScript client
- React Icons
- React Router dependency is installed
- Neumorphism UI design

### Admin features implemented

- Login/logout
- Dashboard analytics
- User management
- Shelter account management
- Adoption monitoring
- Community post moderation
- Reports and system records
- Announcements/notifications
- System maintenance screen

### Important admin files

- `myfuturepet-admin/src/config/supabaseClient.js`
- `myfuturepet-admin/src/pages/LoginPage.js`
- `myfuturepet-admin/src/pages/DashboardPage.js`
- `myfuturepet-admin/src/components/UserManagement.js`
- `myfuturepet-admin/src/components/ShelterAccounts.js`
- `myfuturepet-admin/src/components/AdoptionMonitoring.js`
- `myfuturepet-admin/src/components/CommunityPosts.js`
- `myfuturepet-admin/src/components/Notifications.js`
- `myfuturepet-admin/src/components/Reports.js`
- `myfuturepet-admin/src/components/SystemMaintenance.js`

### Admin data integration status

- `ShelterAccounts.js` queries `shelters` and supports refresh, search, status updates, and deletion.
- `AdoptionMonitoring.js` queries `adoptions` with joins to `pets`, `profiles`, and `shelters`.
- `CommunityPosts.js` queries `community_posts` with a join to `profiles`.
- `Notifications.js` queries and inserts `announcements`.
- `Reports.js` aggregates counts from `profiles`, `pets`, `adoptions`, `community_posts`, and `shelters`.
- `UserManagement.js` uses Supabase Auth admin APIs.

## Current Blocking Issues

### 1. Flutter registration syntax error

`lib/screens/register_screen.dart` contains `String message, {np` inside `_showMessage`. Replace `{np` with `{`, then run `flutter analyze`.

### 2. Supabase profile-name column mismatch

The following admin components still request a profile name field that has not been confirmed in the database:

- `myfuturepet-admin/src/components/AdoptionMonitoring.js`
- `myfuturepet-admin/src/components/CommunityPosts.js`
- `myfuturepet-admin/src/components/Notifications.js`
- `myfuturepet-admin/src/components/DashboardOverview.js`
- `myfuturepet-admin/src/components/UserManagement.js`

Current query/display fragments include:

```javascript
adopter:adopter_id (full_name, email)
user:user_id (full_name, email)
admin:admin_id (full_name)
.select('id, full_name, email, created_at, is_admin')
```

### Recommended fix

First verify the exact columns in the Supabase `profiles` table. If no name column exists, use only columns that are known to exist, initially `id` and `email`. For example:

```javascript
adopter:adopter_id (id, email)
user:user_id (id, email)
admin:admin_id (id, email)
```

Then update JSX references from `full_name`/`fullname` to a safe display value such as `email`.

Do not add a name column unless the Flutter application and database trigger/profile creation flow are updated to populate and use it consistently. Also verify the timestamp column spelling (`create_at` versus `created_at`) before using it in queries.

## Security Notes

- Never upload or commit `.env.local`, Supabase service-role keys, passwords, or API secrets.
- The browser admin app must use only the Supabase anon key.
- Never expose the Supabase service-role key in React/browser code.
- Current temporary RLS policies allow authenticated users broad access. These should be tightened before production.
- A proper admin-role policy should be implemented, preferably using a secure role claim or a carefully designed profile role field.
- Do not trust a client-side `is_admin` check alone for authorization.

## Validation Already Completed

The React admin project was built successfully with:

```powershell
cd "C:\Users\Acer User\Videos\MyFuturePetV1\myfuturepet-admin"
npm run build
```

The build completed successfully after the initial placeholder components were wired to Supabase. Runtime schema errors remain until the profile-column mismatch is fixed.

## OpenCode Status

OpenCode is installed and working in the Windows terminal.

Verified command:

```powershell
opencode --version
```

Verified version at handoff:

```text
1.18.29
```

The issue was caused by npm blocking OpenCode's postinstall script, which left a 479-byte placeholder executable. Running the package postinstall script restored the real Windows executable.

The project contains `opencode.json`. Do not place API keys or other secrets in that file.

## Recommended Next Steps

1. Fix all `fullname` references in the three React components listed above.
2. Restart the React development server:

   ```powershell
   cd "C:\Users\Acer User\Videos\MyFuturePetV1\myfuturepet-admin"
   npm start
   ```

3. Test Community Posts, Adoption Monitoring, and Notifications with real Supabase rows.
4. Confirm the actual `profiles` timestamp column name.
5. Confirm all foreign-key relationships exist in Supabase so nested selects work.
6. Add realistic test rows only after confirming at least one profile, one pet, and one shelter exist.
7. Replace broad temporary RLS policies with admin-only policies.
8. Connect Flutter pet/adoption/community screens to the final schema.
9. Run Flutter analysis/tests and test the admin dashboard end-to-end.
10. Deploy the admin dashboard only after security policies and environment variables are reviewed.

## Useful Commands

### Flutter

```powershell
cd "C:\Users\Acer User\Videos\MyFuturePetV1\myfuturepet"
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

### React admin

```powershell
cd "C:\Users\Acer User\Videos\MyFuturePetV1\myfuturepet-admin"
npm install
npm start
npm run build
```

### OpenCode

```powershell
cd "C:\Users\Acer User\Videos\MyFuturePetV1\myfuturepet"
opencode
```

## Handoff Instructions for Another AI

Start by reading this file and inspecting the actual repository files. Do not assume the documented schema is exact. Verify the Supabase table columns and relationships before changing queries. The first concrete task is to fix the `profiles.fullname` runtime errors without inventing columns, then run the React build and test the affected dashboard tabs.
