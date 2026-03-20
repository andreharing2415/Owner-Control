---
name: flutter-build
description: Gera o build do app Flutter ObraMaster Owner Control para Android (APK/AAB) ou iOS. Use quando precisar gerar um build para teste ou publicação.
disable-model-invocation: true
allowed-tools: Bash
---

# Build Flutter — ObraMaster Owner Control

## Ambiente Flutter

- Versão: !`flutter --version 2>/dev/null | head -2`
- Dispositivos: !`flutter devices 2>/dev/null`

## Build para: $ARGUMENTS

> Todos os comandos devem ser executados a partir da raiz da worktree:
> `C:\Project\ObraMaster\Owner-Control\.claude\worktrees\brave-lovelace`

### Android — APK de debug (para testes rápidos)

```bash
flutter build apk --debug \
  --dart-define=API_BASE_URL=http://SEU_IP:8000
```

> APK gerado em: `build/app/outputs/flutter-apk/app-debug.apk`

### Android — APK de release

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://mestreobra-backend-530484413221.us-central1.run.app
```

### Android — AAB (para Google Play)

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://mestreobra-backend-530484413221.us-central1.run.app
```

> AAB gerado em: `build/app/outputs/bundle/release/app-release.aab`

### iOS — build de release (requer macOS + Xcode)

```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://mestreobra-backend-530484413221.us-central1.run.app
```

### Web

```bash
flutter build web \
  --dart-define=API_BASE_URL=https://mestreobra-backend-530484413221.us-central1.run.app
```

## Informações do app

| Item | Valor |
|------|-------|
| Package name Android | ver `android/app/build.gradle` |
| Bundle ID iOS | ver `ios/Runner.xcodeproj` |
| Nome do app | ObraMaster Owner Control |
| Versão atual | `pubspec.yaml` → `version:` |

## Antes do release — checklist

- [ ] `API_BASE_URL` aponta para servidor de produção (não localhost)
- [ ] Versão (`versionCode` / `CFBundleVersion`) incrementada no `pubspec.yaml`
- [ ] `flutter pub get` executado com sucesso
- [ ] `flutter analyze` sem erros
- [ ] Keystore Android configurado em `android/app/build.gradle`
- [ ] Provisioning profile iOS configurado no Xcode
- [ ] Testar no dispositivo real antes de submeter

## Instalar APK em dispositivo Android conectado

```bash
flutter install
```

## Ver logs do app em tempo real

```bash
flutter logs
```
