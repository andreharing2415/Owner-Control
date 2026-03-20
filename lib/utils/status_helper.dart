import 'package:flutter/material.dart';

/// Mapeamento centralizado de status → cor/icone/label (COMPL-02).
/// Usado em etapas, cronograma, atividades e checklist.

// ─── Etapa / Atividade Status ────────────────────────────────────────────────

Color etapaStatusColor(String status) {
  return switch (status) {
    'concluida' => Colors.green,
    'em_andamento' => Colors.orange,
    _ => Colors.grey,
  };
}

IconData etapaStatusIcon(String status) {
  return switch (status) {
    'concluida' => Icons.check_circle,
    'em_andamento' => Icons.timelapse,
    _ => Icons.radio_button_unchecked,
  };
}

String etapaStatusLabel(String status) {
  return switch (status) {
    'concluida' => 'Concluída',
    'em_andamento' => 'Em andamento',
    _ => 'Pendente',
  };
}

// ─── Checklist Item Status ───────────────────────────────────────────────────

Color checklistStatusColor(String status) {
  return switch (status) {
    'ok' => Colors.green,
    'nao_conforme' => Colors.red,
    _ => Colors.grey,
  };
}

String checklistStatusLabel(String status) {
  return switch (status) {
    'ok' => 'Conforme',
    'nao_conforme' => 'Não conforme',
    _ => 'Pendente',
  };
}
