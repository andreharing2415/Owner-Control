# Testing Patterns

**Analysis Date:** 2026-04-06

## Test Framework

**Runner (Flutter/Dart):**
- `flutter_test` (bundled with Flutter SDK)
- Config: no separate config file — tests run via `flutter test`
- Mocking: `mockito ^5.4.4` + `build_runner ^2.4.9` (for code generation)
- HTTP mocking: `http/testing.dart` (`MockClient`) — from the `http` package

**Runner (Python/FastAPI):**
- `pytest 8.1.1`
- `pytest-asyncio 0.23.5`
- HTTP test client: `httpx 0.27.0` (FastAPI `TestClient`)
- No Python test files exist yet — framework is configured but no tests written

**Run Commands:**
```bash
# Flutter
flutter test                    # Run all Dart tests
flutter test --coverage         # Run with coverage report

# Python (from server/ directory)
pytest                          # Run all Python tests
pytest -v                       # Verbose output
pytest --asyncio-mode=auto      # Async test support
```

## Test File Organization

**Flutter:**
- Location: `test/` at project root (separate from `lib/`)
- Files: `test/widget_test.dart`, `test/api_client_test.dart`
- Naming: `<module>_test.dart`

**Python:**
- No test files currently exist in `server/`
- Expected location would be `server/tests/` per pytest convention

## Test Structure (Flutter)

**Suite Organization:**
```dart
// Private helper factories at top (outside main)
http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _obraJson({String id = 'obra-1', ...}) => {...};

// Test entry point
void main() {
  // ── group description (comments use ── prefix) ──────────────────────────

  group('ApiClient.methodName', () {
    test('describes expected behavior', () async {
      final api = ApiClient(client: MockClient((_) async => _json(...)));
      final result = await api.method();
      expect(result, matcher);
    });
  });
}
```

**Patterns:**
- No `setUp`/`tearDown` — each test instantiates its own `ApiClient` with a fresh `MockClient`
- Grouping: one `group()` per public API method or model class
- Test names are full Portuguese/English sentences describing the behavior: `'retorna lista vazia quando API retorna []'`
- Async tests use `() async` lambdas

## Mocking

**Framework:** `http/testing.dart` `MockClient` (from the `http` package — no `mockito` annotation needed for HTTP)

**HTTP Mocking Pattern:**
```dart
// Simple response mock
final api = ApiClient(client: MockClient((_) async => _json({'score': 72.5})));

// Request capture mock (inspecting outgoing body)
Map<String, dynamic> capturedBody = {};
final api = ApiClient(
  client: MockClient((request) async {
    capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
    return _json(_obraJson());
  }),
);
await api.criarObra(nome: 'Test');
expect(capturedBody['nome'], 'Test');
```

**`ApiClient` Dependency Injection:**
- `ApiClient` accepts an optional `client` parameter in its constructor to enable mocking
- Production code creates `ApiClient()` with no argument (uses default real HTTP client)
- Tests pass `ApiClient(client: MockClient(...))` to inject a fake

**What to Mock:**
- HTTP layer via `MockClient` — all network calls
- Never mock the `ApiClient` itself — test it directly with a mocked HTTP client

**What NOT to Mock:**
- Model `fromJson` logic — test it directly with raw JSON maps
- Business logic inside `ApiClient` methods

## Fixtures and Factories

**Test Data — Private factory functions at top of test file:**
```dart
// Returns a valid http.Response with JSON body
http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

// Returns a model-shaped JSON map with sensible defaults
Map<String, dynamic> _obraJson({
  String id = 'obra-1',
  String nome = 'Residencia Teste',
  String? localizacao = 'Sao Paulo, SP',
  double? orcamento = 500000,
  String? dataInicio,
  String? dataFim,
}) => { 'id': id, 'nome': nome, ... };
```

Separate factory functions exist for each domain model: `_obraJson`, `_etapaJson`, `_itemJson`.

**Location:** Defined as private top-level functions in the same test file — `test/api_client_test.dart`

## Coverage

**Requirements:** None enforced — no minimum threshold configured

**View Coverage:**
```bash
flutter test --coverage
# Coverage report generated at coverage/lcov.info
# View with: genhtml coverage/lcov.info -o coverage/html
```

## Test Types

**Unit Tests (Dart — `test/api_client_test.dart`):**
- Scope: `ApiClient` methods and model `fromJson` factories
- Tests HTTP request formation (outgoing payload shape)
- Tests HTTP response mapping (incoming JSON → model fields)
- Tests error handling (non-200 status codes throw `Exception`)
- Tests null/optional field handling and default values

**Widget Tests (Dart — `test/widget_test.dart`):**
- Scope: smoke test only — verifies `MestreDaObraApp` mounts without crash
- No widget interaction or navigation tested

**Integration Tests:** Not present

**E2E Tests:** Not used

## Common Patterns

**Testing error responses:**
```dart
test('lanca excecao quando status != 200', () async {
  final api = ApiClient(
    client: MockClient((_) async => _json({'detail': 'erro'}, status: 500)),
  );
  expect(() => api.listarObras(), throwsException);
});
```

**Testing null/optional fields:**
```dart
test('mapeia obra sem datas (campos null)', () async {
  final api = ApiClient(
    client: MockClient((_) async => _json([_obraJson()])),
  );
  final obras = await api.listarObras();
  expect(obras.first.dataInicio, isNull);
  expect(obras.first.dataFim, isNull);
});
```

**Testing `fromJson` defaults directly (no HTTP):**
```dart
test('defaults missing fields gracefully', () {
  final json = {'id': 'ativ-1', 'obra_id': 'obra-1', 'nome': 'Alvenaria'};
  final atividade = AtividadeCronograma.fromJson(json);
  expect(atividade.ordem, 0);
  expect(atividade.status, 'pendente');
});
```

**Testing nested JSON parsing:**
```dart
test('parses nested sub-activities and services', () {
  final json = {
    'sub_atividades': [
      {
        'servicos': [{'id': 'svc-1', 'descricao': 'Operador', ...}],
        ...
      },
    ],
    ...
  };
  final atividade = AtividadeCronograma.fromJson(json);
  expect(atividade.subAtividades[0].servicos[0].descricao, 'Operador');
});
```

## Gaps and Notes

- Python backend has **no tests** despite `pytest` and `pytest-asyncio` being in `requirements-dev.txt`
- Flutter widget tests are minimal (smoke test only)
- No integration tests for Provider layer (`AuthProvider`, `ObraProvider`, `SubscriptionProvider`)
- `mockito` package is declared in `pubspec.yaml` but not used in existing tests (HTTP is mocked via `MockClient` instead)

---

*Testing analysis: 2026-04-06*
