class SubscriptionInfo {
  SubscriptionInfo({
    required this.plan,
    required this.planConfig,
    required this.usage,
    required this.obraCount,
    required this.docCount,
    this.conviteCount = 0,
    this.expiresAt,
    this.status = "active",
  });

  final String plan;
  final Map<String, dynamic> planConfig;
  final Map<String, int> usage;
  final int obraCount;
  final int docCount;
  final int conviteCount;
  final String? expiresAt;
  final String status;

  bool get isGratuito => plan == "gratuito";
  bool get isDono => plan == "dono_da_obra";

  int? get maxObras => planConfig["max_obras"] as int?;
  int? get maxDocUploads => planConfig["max_doc_uploads"] as int?;
  int? get maxDocSizeMb => planConfig["max_doc_size_mb"] as int?;
  int? get maxDocPagesViewable => planConfig["max_doc_pages_viewable"] as int?;
  bool get canDeleteDoc => planConfig["can_delete_doc"] as bool? ?? false;
  bool get canCreateEtapas => planConfig["can_create_etapas"] as bool? ?? false;
  bool get canCreateChecklistItems =>
      planConfig["can_create_checklist_items"] as bool? ?? false;
  bool get canCreateComentarios =>
      planConfig["can_create_comentarios"] as bool? ?? false;
  int? get aiVisualMonthlyLimit =>
      planConfig["ai_visual_monthly_limit"] as int?;
  int? get checklistInteligenteLifetimeLimit =>
      planConfig["checklist_inteligente_lifetime_limit"] as int?;
  int? get normasResultsLimit => planConfig["normas_results_limit"] as int?;
  int? get prestadoresLimit => planConfig["prestadores_limit"] as int?;
  bool get prestadoresShowContact =>
      planConfig["prestadores_show_contact"] as bool? ?? false;
  int? get docAnalysisPagesLimit =>
      planConfig["doc_analysis_pages_limit"] as int?;
  int get maxConvites => planConfig["max_convites"] as int? ?? 0;

  int get aiVisualUsed => usage["ai_visual"] ?? 0;
  int get checklistInteligenteUsed => usage["checklist_inteligente"] ?? 0;
  int get docUploadUsed => usage["doc_upload"] ?? 0;

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final usageRaw = json["usage"] as Map<String, dynamic>? ?? {};
    final usageMap = usageRaw.map(
      (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
    );
    return SubscriptionInfo(
      plan: json["plan"] as String? ?? "gratuito",
      planConfig: json["plan_config"] as Map<String, dynamic>? ?? {},
      usage: usageMap,
      obraCount: (json["obra_count"] as num?)?.toInt() ?? 0,
      docCount: (json["doc_count"] as num?)?.toInt() ?? 0,
      conviteCount: (json["convite_count"] as num?)?.toInt() ?? 0,
      expiresAt: json["expires_at"] as String?,
      status: json["status"] as String? ?? "active",
    );
  }
}
