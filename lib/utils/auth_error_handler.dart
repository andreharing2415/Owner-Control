import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../providers/auth_provider.dart';

/// Formata mensagem de erro removendo prefixos internos do Dart.
String formatErrorMessage(Object error) {
  final raw = '$error';
  // Remove "Exception: " prefix from Dart exceptions
  if (raw.startsWith('Exception: ')) return raw.substring(11);
  return raw;
}

/// Trata erros de API. Se for AuthExpiredException, faz logout automático.
/// Padrão único para todas as telas (ARQ-03).
void handleApiError(BuildContext context, Object error) {
  if (error is AuthExpiredException) {
    context.read<AuthProvider>().logout();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sessao expirada. Faca login novamente.')),
    );
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(formatErrorMessage(error))),
  );
}
