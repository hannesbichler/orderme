# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**OrderMe (W4CASH)** is a Flutter POS (point-of-sale) application for restaurant/hospitality order management. It supports NFC card authentication for staff, product catalog browsing, table/order management, order splitting, and payment processing (cash, EC, Apple Pay).

## Commands

```bash
# Install dependencies
flutter pub get

# Run (specify device: chrome, windows, android, ios)
flutter run -d <device>

# Build
flutter build apk          # Android APK
flutter build appbundle    # Android AAB
flutter build ios          # iOS
flutter build windows      # Windows
flutter build web          # Web

# Test
flutter test               # Runs test/widget_test.dart
flutter test test/widget_test.dart  # Single test file

# Lint / analyze
flutter analyze
```

## Architecture

**State management**: Plain `StatefulWidget` + `setState`. No Provider, Bloc, or Riverpod.

**Layer structure inside `lib/`**:
- `screens/` — full screens and dialogs (UI + business logic co-located)
- `models/` — plain Dart data classes with JSON `fromJson`/`toJson`
- `services/` — singletons for HTTP calls and local storage
- `utils/` — string helpers (HTML entity decoding, SHA1 hashing, URL decoding)

**Key services**:
- `AppSettingsService` — reads/writes host+port from `SharedPreferences`; must be initialized in `main.dart` before `runApp`
- `ProductCatalogService` — singleton that caches products and categories in memory; preloaded at startup (failures are non-blocking)
- `AuthService` — fetches user list from `/persons` and does password comparison

**Backend**: Node.js/Express + Oracle DB (schema: `w4cash`). REST API returns HAL-style JSON (`_embedded`, `_links`). Default base URL: `http://217.154.223.125:3000` (runtime-configurable via Settings screen).

## Key API Endpoints

| Endpoint | Purpose |
|---|---|
| `GET /persons` | User list for login |
| `GET /products` | Full product catalog |
| `GET /categories` | Category hierarchy |
| `GET /floors` | Restaurant floors/sections |
| `GET /places` | Tables per floor |
| `GET /orderitem/{placeId}/{placeName}` | Active order for a table |
| `POST /order/split` | Split order across guests |
| `POST /order/move` | Move order to another table |

## Platform Notes

- **NFC** (`nfc_manager`): Android/iOS only. `LoginScreen` checks `NfcManager.instance.isAvailable()` and shows the NFC reader conditionally.
- **Apple Pay** (`apple_pay_flutter`): iOS only; integrated in `CheckoutDialog`.
- **Window Manager** (`window_manager`): Windows desktop; configured in `main.dart`.
- **Web**: NFC and Apple Pay are disabled at compile-time via platform checks.

## Data Parsing Quirks

- `OrderLine` attributes come from the API under multiple possible field names (`attributes`, `attributeList`, `attList`) — the parser handles all three.
- Attribute descriptions may arrive as a concatenated string that is split on a separator character.
- `StringUtils` decodes HTML entities, numeric HTML entities (decimal + hex), and Unicode escapes before displaying product names.

## Backend (Java / Spring Boot)

Located at `../../java/w4cash_webserver` (separate repo, multi-module Maven project). The active server module is `rest`.

```bash
cd ../../java/w4cash_webserver

# Build all modules
./mvnw clean install

# Run the REST server (port 3000)
./mvnw -pl rest spring-boot:run

# Or build and run the jar directly
./mvnw -pl rest clean package
java -jar rest/target/rest-0.0.1-SNAPSHOT.jar
```

- **Framework**: Spring Boot 3.2.5, Spring Data JPA, Spring HATEOAS
- **Java**: 21
- **Database**: H2 (embedded, in-memory — no external DB setup needed)
- **Default port**: 3000 (matches Flutter app default; change in `rest/src/main/resources/application.properties`)
- **Entry point**: `w4cash.W4cashApplication` in `rest/src/main/java/w4cash/`

### Running the webservice tests

```bash
cd ../../java/w4cash_webserver/rest
../mvnw test
```

Tests live in `rest/src/test/java/w4cash/` and use `@WebMvcTest` with MockMvc — no external database or server needed.

- `person/PersonControllerTest` — 8 tests: GET all (empty + populated, DB sync), GET by id (found / 404), PUT (update + upsert), DELETE
- `product/ProductsControllerTest` — 11 tests: GET all (empty + populated, HTML escaping, DB sync), GET by category (filter + parameterized query), GET by id (found / 404), PUT (update + upsert), DELETE

**Test infrastructure notes:**
- `src/test/resources/mockito-extensions/org.mockito.plugins.MockMaker` forces the subclass mock maker — required because Java 24 module restrictions prevent Mockito's default inline mock maker from instrumenting `java.sql.Connection`.
- `LoadDatabase.DBConnection` (the static JDBC connection) is set to a `mock(Connection.class)` in `@BeforeEach` and reset to `null` in `@AfterEach` to isolate tests.
- Controllers follow a sync pattern on every GET (clear JPA repo → reload from JDBC → return). Tests verify both the HTTP response and that `repository.deleteAll()` / `repository.save()` are called.
