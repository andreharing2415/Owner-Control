---
name: flutter-build
description: Gera o build do app Flutter para Android (APK/AAB) ou iOS. Use quando precisar gerar um build para teste ou publicação.
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Grep
---

# Build Flutter — Mestre da Obra

## REGRA OBRIGATÓRIA — Incrementar versão antes de QUALQUER build release/appbundle

Antes de rodar `flutter build appbundle` ou `flutter build apk --release`, SEMPRE:

1. Ler `mobile/pubspec.yaml` e encontrar a linha `version: X.Y.Z+N`
2. Incrementar o versionCode (o número após `+`) em +1
3. Salvar o arquivo com a versão atualizada
4. Só então executar o build

Exemplo:
- Antes: `version: 2.2.1+10`
- Depois: `version: 2.2.1+11`

**NUNCA pular este passo. O Google Play rejeita builds com versionCode já usado.**

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
flutter build apk --release
```

### Android — AAB (para Google Play)
```bash
cd C:\Project\ObraMaster\Owner-Control\mobile
flutter build appbundle --release
```
> AAB gerado em: `build/app/outputs/bundle/release/app-release.aab`

### iOS — build de release (requer macOS + Xcode)
```bash
cd C:\Project\ObraMaster\Owner-Control\mobile
flutter build ipa --release
```

## Informações importantes

| Item | Valor |
|------|-------|
| Package name Android | `br.mestredaobra.app` |
| Bundle ID iOS | `br.mestredaobra.app` |
| Nome do app | Mestre da Obra |
| Versão atual | `pubspec.yaml` → `version:` |
| API produção | `https://mestreobra-backend-530484413221.us-central1.run.app` |

## Antes do release — checklist

- [x] Versão (`versionCode`) incrementada automaticamente (regra obrigatória acima)
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
