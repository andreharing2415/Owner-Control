---
name: flutter-screen
description: Cria uma nova tela Flutter para o app Mestre da Obra seguindo os padrões do projeto. Use quando precisar adicionar uma nova tela ao app mobile.
disable-model-invocation: false
---

# Criar nova tela Flutter — Mestre da Obra

Crie a tela: **$ARGUMENTS**

## Contexto do projeto

- App: Flutter 3.11+, Material 3, tema indigo
- Arquivo principal: `mobile/lib/main.dart`
- API client: `mobile/lib/api/api.dart`
- Padrão: StatefulWidget + FutureBuilder para dados assíncronos
- Idioma da UI: Português (Brasil)

## Padrões obrigatórios

1. **Estado e carregamento**: Sempre exibir `CircularProgressIndicator()` durante carregamento
2. **Tratamento de erros**: Exibir mensagem amigável + botão "Tentar novamente"
3. **Pull-to-refresh**: Usar `RefreshIndicator` nas listas
4. **Estado vazio**: Widget com ícone + texto explicativo quando a lista estiver vazia
5. **Snackbars**: Usar `ScaffoldMessenger.of(context).showSnackBar()` para feedback ao usuário
6. **Verificar mounted**: Sempre checar `if (mounted)` antes de atualizar estado em callbacks async

## Estrutura de uma tela padrão

```dart
class MinhaScreen extends StatefulWidget {
  const MinhaScreen({super.key, required this.param});
  final TipoParam param;

  @override
  State<MinhaScreen> createState() => _MinhaScreenState();
}

class _MinhaScreenState extends State<MinhaScreen> {
  final ApiClient _api = ApiClient();
  late Future<List<Modelo>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.listarAlgo(widget.param.id);
  }

  Future<void> _refresh() async {
    setState(() { _future = _api.listarAlgo(widget.param.id); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.param.nome)),
      body: FutureBuilder<List<Modelo>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(/* ... erro ... */);
          }
          final dados = snapshot.data ?? [];
          if (dados.isEmpty) {
            return Center(/* ... vazio ... */);
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(/* ... */),
          );
        },
      ),
    );
  }
}
```

## Passos

1. Leia `mobile/lib/main.dart` para entender os modelos e padrões existentes
2. Leia `mobile/lib/api/api.dart` para verificar métodos disponíveis
3. Adicione a nova tela ao final de `mobile/lib/main.dart`
4. Se precisar de novos métodos de API, adicione também em `api.dart`
5. Adicione a navegação para a nova tela de onde fizer sentido
