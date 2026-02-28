import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../providers/auth_provider.dart';

/// Trata erros de API. Se for AuthExpiredException, faz logout automático.
void handleApiError(BuildContext context, Object error) {
  if (error is AuthExpiredException) {
    context.read<AuthProvider>().logout();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sessao expirada. Faca login novamente.')),
    );
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$error')),
  );
}
