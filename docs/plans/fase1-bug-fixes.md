# Fase 1: Bug Fixes (3 bugs)

**Sessao independente — sem dependencias de outras fases.**
**Sem mudancas no backend — apenas Flutter.**

---

## Bug 1: "Erro ao criar obra" — mensagem generica

**Problema:** `api_client.dart:271` joga `Exception("Erro ao criar obra")` para qualquer non-200, perdendo o `detail` do 403 (limite de plano atingido).

**Arquivos a modificar:**
- `mobile/lib/services/api_client.dart` (linhas 260-275)
- `mobile/lib/screens/obras/obras_screen.dart` (catch block ~linha 96)

**Implementacao:**

1. Em `api_client.dart`, metodo `criarObra()` (linha 271-272):
   ```dart
   // ANTES:
   if (response.statusCode != 200) {
     throw Exception("Erro ao criar obra");
   }

   // DEPOIS:
   if (response.statusCode == 403) {
     onFeatureGate?.call();  // mesmo padrao de criarConvite (linha 1065)
     final body = jsonDecode(response.body) as Map<String, dynamic>;
     throw Exception(body["detail"] ?? "Limite do plano atingido");
   }
   if (response.statusCode != 200) {
     try {
       final body = jsonDecode(response.body) as Map<String, dynamic>;
       throw Exception(body["detail"] ?? "Erro ao criar obra");
     } catch (_) {
       throw Exception("Erro ao criar obra");
     }
   }
   ```

2. Em `obras_screen.dart`, no catch de `_criarObra()`:
   - Remover o prefixo "Exception:" da mensagem exibida no SnackBar
   - Exibir `e.toString().replaceFirst('Exception: ', '')`

**Padrao existente a reutilizar:** `criarConvite()` em `api_client.dart` linha 1065 faz exatamente o mesmo tratamento de 403.

---

## Bug 2: "Connection abort" em upload de evidencia

**Problema:** `uploadEvidencia()` (linha 462) e `uploadEvidenciaImagem()` (linha 508) usam `request.send()` sem timeout. Fotos da camera (5-15MB) causam abort de conexao.

**Arquivos a modificar:**
- `mobile/lib/services/api_client.dart` (linhas 462-530)
- `mobile/lib/screens/checklist/detalhe_item_screen.dart` (linhas 116-125)

**Implementacao:**

1. Em `api_client.dart`, adicionar helper privado:
   ```dart
   Future<http.StreamedResponse> _sendWithTimeout(
     http.MultipartRequest request, {
     Duration timeout = const Duration(seconds: 120),
   }) async {
     try {
       return await request.send().timeout(timeout);
     } on TimeoutException {
       throw Exception("Upload expirou. Verifique sua conexao e tente novamente.");
     } on SocketException {
       throw Exception("Falha na conexao. Verifique sua internet.");
     }
   }
   ```

2. Em `uploadEvidencia()` linha 502, trocar:
   ```dart
   // ANTES: final response = await request.send();
   // DEPOIS:
   final response = await _sendWithTimeout(request);
   ```

3. Em `uploadEvidenciaImagem()` linha 526, mesma troca.

4. Em `detalhe_item_screen.dart`, ao chamar `pickImage()` (linhas 117-118 e 122-123), adicionar limites:
   ```dart
   // ANTES:
   final img = await _imagePicker.pickImage(
       source: ImageSource.camera, imageQuality: 85);

   // DEPOIS:
   final img = await _imagePicker.pickImage(
       source: ImageSource.camera,
       imageQuality: 85,
       maxWidth: 1920,
       maxHeight: 1920);
   ```
   Aplicar o mesmo para `ImageSource.gallery` (linha 122).

---

## Bug 3: "Web file picker not available on this platform"

**Problema:** `documentos_screen.dart:49` chama `web_picker.pickPdfFile()` que usa import condicional `dart:html`. No Android, cai no stub que joga `UnsupportedError`. O package `file_picker` ja esta no pubspec.yaml mas nao e usado nesta tela.

**Arquivos a modificar:**
- `mobile/lib/screens/documentos/documentos_screen.dart` (linhas 13-15, 47-65)

**Arquivos a deletar:**
- `mobile/lib/screens/documentos/web_file_picker_stub.dart`
- `mobile/lib/screens/documentos/web_file_picker.dart`

**Implementacao:**

1. Em `documentos_screen.dart`, trocar imports (linhas 13-15):
   ```dart
   // REMOVER:
   // import "web_file_picker_stub.dart"
   //     if (dart.library.html) "web_file_picker.dart" as web_picker;

   // ADICIONAR:
   import 'dart:io';
   import 'package:file_picker/file_picker.dart';
   ```

2. Reescrever `_uploadPdf()` (linhas 47-78):
   ```dart
   Future<void> _uploadPdf() async {
     try {
       final result = await FilePicker.platform.pickFiles(
         type: FileType.custom,
         allowedExtensions: ['pdf'],
       );
       if (result == null || result.files.isEmpty) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Nenhum arquivo selecionado.")),
           );
         }
         return;
       }
       setState(() => _uploading = true);
       final file = result.files.first;
       final bytes = file.bytes ?? await File(file.path!).readAsBytes();
       await widget.api.uploadProjeto(
         obraId: widget.obraId,
         bytes: bytes,
         fileName: file.name,
       );
       await _refresh();
       if (mounted) _perguntarChecklistInteligente();
     } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Erro ao enviar projeto: $e")),
         );
       }
     } finally {
       if (mounted) setState(() => _uploading = false);
     }
   }
   ```

3. Deletar `web_file_picker_stub.dart` e `web_file_picker.dart`.

---

## Verificacao

1. **Bug 1:** No app, tentar criar obra com plano gratuito (limite 1 obra). Deve mostrar mensagem clara "Limite de 1 obra(s) atingido para seu plano" em vez de "Erro ao criar obra".
2. **Bug 2:** Tirar foto com camera no checklist e fazer upload. Deve completar sem "connection abort". Testar com foto grande.
3. **Bug 3:** No Android, ir em Documentos, clicar botao de upload. File picker nativo deve aparecer permitindo selecionar PDF.
4. Rodar `cd mobile && flutter analyze` — sem erros.

## Deploy

- Apenas build Flutter (APK): `cd mobile && flutter build apk --release`
- **NAO precisa deploy backend** — nenhuma mudanca no server.
