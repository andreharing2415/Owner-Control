---
name: flutter-screen
description: Cria uma nova tela Flutter para o app ObraMaster Owner Control seguindo os padrões do projeto. Use quando precisar adicionar uma nova tela ao app mobile — mencionar "tela", "screen", "página", "adicionar view" ou qualquer funcionalidade nova de UI já é motivo suficiente para usar esta skill.
disable-model-invocation: false
---

# Criar nova tela Flutter — ObraMaster Owner Control

Crie a tela: **$ARGUMENTS**

## Contexto do projeto

- App: Flutter 3.11+, Material 3, tema indigo/azul
- Package: `owner_control`
- Arquivo principal: `lib/main.dart`
- API client: `lib/api/api.dart`
- Telas existentes: `lib/screens/`
- Providers: `lib/providers/` (usa `provider ^6.1.2`)
- Mock data (fallback): `lib/models/mock_data.dart`
- Idioma da UI: Português (Brasil)
- API base: `API_BASE_URL` (env var, default `http://localhost:8000`)

## Padrões obrigatórios

1. **Estado e carregamento**: Sempre exibir `CircularProgressIndicator()` durante carregamento
2. **Tratamento de erros**: Exibir mensagem amigável + botão "Tentar novamente"
3. **Pull-to-refresh**: Usar `RefreshIndicator` nas listas
4. **Estado vazio**: Widget com ícone + texto explicativo quando a lista estiver vazia
5. **Snackbars**: Usar `ScaffoldMessenger.of(context).showSnackBar()` para feedback
6. **Verificar mounted**: Sempre checar `if (mounted)` antes de atualizar estado em callbacks async
7. **Navigator**: Usar `Navigator.of(context).push(MaterialPageRoute(...))` para navegação

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

1. Leia `lib/main.dart` para entender rotas e estrutura de navegação existentes
2. Leia `lib/api/api.dart` para verificar modelos e métodos de API disponíveis
3. Leia a tela mais parecida em `lib/screens/` para seguir os padrões visuais
4. Crie o arquivo da nova tela em `lib/screens/<nome_screen>.dart`
5. Se precisar de novos métodos de API, adicione em `lib/api/api.dart`
6. Registre a navegação para a nova tela em `lib/main.dart` ou na tela de origem
