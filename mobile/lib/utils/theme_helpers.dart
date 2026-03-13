import "package:flutter/material.dart";

/// Color for severidade levels: "alto"/"alta"/"critica", "medio"/"media", "baixo".
Color severidadeColor(String severidade) {
  switch (severidade.toLowerCase()) {
    case "alto":
    case "alta":
    case "critica":
      return Colors.red;
    case "medio":
    case "media":
      return Colors.orange;
    case "baixo":
      return Colors.green;
    default:
      return Colors.grey;
  }
}

/// Color for checklist item status: "ok", "nao_conforme", "pendente".
Color checklistStatusColor(String status) {
  switch (status) {
    case "ok":
      return Colors.green;
    case "nao_conforme":
      return Colors.red;
    default:
      return Colors.grey;
  }
}

/// Human-readable label for checklist item status.
String checklistStatusLabel(String status) {
  switch (status) {
    case "ok":
      return "OK";
    case "nao_conforme":
      return "Não conforme";
    default:
      return "Pendente";
  }
}
