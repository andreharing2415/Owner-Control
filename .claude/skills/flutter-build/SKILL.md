---
name: flutter-build
description: Gera o build do app Flutter para Android (APK/AAB) ou iOS. Use quando precisar gerar um build para teste ou publicação.
disable-model-invocation: true
allowed-tools: Bash
---

# Build Flutter — Mestre da Obra

## Ambiente Flutter
- Versão: !`flutter --version 2>/dev/null | head -2`
- Dispositivos: !`flutter devices 2>/dev/null`

## Build para: $ARGUMENTS

### Android — APK de debug (para testes rápidos)
```bash
cd C:\Project\ObraMaster\Owner-Control\mobile
flutter build apk --debug \
  --dart-define=API_BASE_URL=http://SEU_IP:8000
```
> APK gerado em: `build/app/outputs/flutter-apk/app-debug.apk`

### Android — APK de release
```bash
cd C:\Project\ObraMaster\Owner-Control\mobile
flutter build apk --release \
  --dart-define=API_BASE_URL=https://polymktbr-web-fjrjxh4gla-uc.a.run.app
```

### Android — AAB (para Google Play)
```bash
cd C:\Project\ObraMaster\Owner-Control\mobile
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://polymktbr-web-fjrjxh4gla-uc.a.run.app
```
> AAB gerado em: `build/app/outputs/bundle/release/app-release.aab`

### iOS — build de release (requer macOS + Xcode)
```bash
cd C:\Project\ObraMaster\Owner-Control\mobile
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://polymktbr-web-fjrjxh4gla-uc.a.run.app
```

## Informações importantes

| Item | Valor |
|------|-------|
| Package name Android | `br.mestredaobra.app` |
| Bundle ID iOS | `br.mestredaobra.app` |
| Nome do app | Mestre da Obra |
| Versão atual | `pubspec.yaml` → `version:` |

## Antes do release — checklist

- [ ] `API_BASE_URL` aponta para a API de produção (Cloud Run: `gcloud run services list --platform managed` → use a URL do serviço, ex.: `polymktbr-web`)
- [ ] Versão (`versionCode` / `CFBundleVersion`) incrementada no `pubspec.yaml`
- [ ] Keystore Android configurado em `build.gradle.kts`
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
