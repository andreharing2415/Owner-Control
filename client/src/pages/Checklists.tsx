import {
  useChecklistHistorico,
  useChecklistStatus,
  useIniciarChecklist,
  useAplicarChecklist,
  parseCaracteristicas,
  type ChecklistGeracaoLog,
  type ChecklistGeracaoItem,
} from "@/lib/api";
import { CHECKLIST_JOBS_MOCK } from "@/lib/mock-data";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import {
  CheckCircle2,
  Loader2,
  XCircle,
  Sparkles,
  ChevronDown,
  ChevronUp,
  FileCheck,
  Clock,
  Check,
  Eye,
  Ruler,
  Lightbulb,
} from "lucide-react";
import { useState } from "react";

const OBRA_ID = "1";

function StatusBadge({ status }: { status: string }) {
  if (status === "processando") {
    return (
      <Badge className="bg-blue-500/10 text-blue-400 border-blue-500/20 gap-1.5">
        <Loader2 className="h-3 w-3 animate-spin" />
        Processando
      </Badge>
    );
  }
  if (status === "concluido") {
    return (
      <Badge className="bg-emerald-500/10 text-emerald-400 border-emerald-500/20 gap-1.5">
        <CheckCircle2 className="h-3 w-3" />
        Concluído
      </Badge>
    );
  }
  return (
    <Badge className="bg-red-500/10 text-red-400 border-red-500/20 gap-1.5">
      <XCircle className="h-3 w-3" />
      Erro
    </Badge>
  );
}

function formatDate(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString("pt-BR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function ItemCard({ item, selected, onToggle }: {
  item: ChecklistGeracaoItem;
  selected: boolean;
  onToggle: () => void;
}) {
  return (
    <div
      className={`rounded-lg border p-3 cursor-pointer transition-colors ${
        selected ? "border-primary/40 bg-primary/5" : "border-border/30 bg-card/20 hover:bg-card/40"
      }`}
      onClick={onToggle}
    >
      <div className="flex items-start gap-3">
        <div className={`mt-0.5 h-4 w-4 rounded border flex items-center justify-center shrink-0 ${
          selected ? "bg-primary border-primary" : "border-border"
        }`}>
          {selected && <Check className="h-3 w-3 text-white" />}
        </div>
        <div className="flex-1 space-y-1.5">
          <div className="flex items-center gap-2">
            <span className="text-sm font-medium">{item.titulo}</span>
            {item.critico && (
              <Badge variant="outline" className="text-[9px] h-4 px-1 border-red-500/30 text-red-400">
                Crítico
              </Badge>
            )}
          </div>
          <div className="flex items-center gap-2 text-[10px] text-muted-foreground">
            <span>{item.etapa_nome}</span>
            {item.norma_referencia && (
              <>
                <span className="w-1 h-1 rounded-full bg-border" />
                <span>{item.norma_referencia}</span>
              </>
            )}
          </div>
          {(item.como_verificar || item.medidas_minimas || item.explicacao_leigo) && (
            <div className="mt-2 space-y-1.5 rounded-md bg-muted/10 border border-border/20 p-2.5">
              {item.como_verificar && (
                <div className="flex items-start gap-1.5">
                  <Eye className="h-3 w-3 text-emerald-400 mt-0.5 shrink-0" />
                  <p className="text-[11px] text-muted-foreground">{item.como_verificar}</p>
                </div>
              )}
              {item.medidas_minimas && (
                <div className="flex items-start gap-1.5">
                  <Ruler className="h-3 w-3 text-blue-400 mt-0.5 shrink-0" />
                  <p className="text-[11px] text-muted-foreground">{item.medidas_minimas}</p>
                </div>
              )}
              {item.explicacao_leigo && (
                <div className="flex items-start gap-1.5">
                  <Lightbulb className="h-3 w-3 text-amber-400 mt-0.5 shrink-0" />
                  <p className="text-[11px] text-muted-foreground">{item.explicacao_leigo}</p>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function JobCard({ job, useMock = false }: { job: ChecklistGeracaoLog; useMock?: boolean }) {
  const [expanded, setExpanded] = useState(false);
  const [selectedItems, setSelectedItems] = useState<Set<string>>(new Set());

  const isProcessing = job.status === "processando";
  const { data: statusData } = useChecklistStatus(
    job.obra_id,
    expanded || isProcessing ? job.id : null,
    !useMock
  );

  const aplicar = useAplicarChecklist();

  const caracs = parseCaracteristicas(job.caracteristicas_identificadas);
  const progress =
    job.total_paginas > 0
      ? Math.round((job.paginas_processadas / job.total_paginas) * 100)
      : 0;

  const itens = statusData?.itens || [];

  const toggleItem = (id: string) => {
    setSelectedItems((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const selectAll = () => {
    if (selectedItems.size === itens.length) {
      setSelectedItems(new Set());
    } else {
      setSelectedItems(new Set(itens.map((i) => i.id)));
    }
  };

  const handleAplicar = () => {
    const selected = itens.filter((i) => selectedItems.has(i.id));
    aplicar.mutate({
      obraId: job.obra_id,
      itens: selected.map((i) => ({
        etapa_nome: i.etapa_nome,
        titulo: i.titulo,
        descricao: i.descricao,
        norma_referencia: i.norma_referencia,
        critico: i.critico,
      })),
    });
  };

  return (
    <Card className="border-border/50 bg-card/40 hover:bg-card/60 transition-colors">
      <CardContent className="p-5">
        <div className="flex items-start justify-between gap-4">
          <div className="flex-1 space-y-3">
            <div className="flex items-center gap-3 flex-wrap">
              <StatusBadge status={job.status} />
              <span className="text-xs text-muted-foreground flex items-center gap-1">
                <Clock className="h-3 w-3" />
                {formatDate(job.created_at)}
              </span>
              <span className="text-xs text-muted-foreground">
                {job.total_docs_analisados} documento
                {job.total_docs_analisados !== 1 ? "s" : ""} analisado
                {job.total_docs_analisados !== 1 ? "s" : ""}
              </span>
              {useMock && (
                <Badge variant="secondary" className="text-[10px]">Demo</Badge>
              )}
            </div>

            {job.status === "processando" && (
              <div className="space-y-1.5">
                <div className="flex justify-between text-xs text-muted-foreground">
                  <span>Página {job.paginas_processadas} de {job.total_paginas}</span>
                  <span>{progress}%</span>
                </div>
                <Progress value={progress} className="h-2" />
              </div>
            )}

            {job.status === "concluido" && job.resumo_geral && (
              <p className="text-sm text-muted-foreground line-clamp-2">
                {job.resumo_geral}
              </p>
            )}

            {job.status === "erro" && job.erro_detalhe && (
              <p className="text-sm text-red-400">{job.erro_detalhe}</p>
            )}

            {caracs.length > 0 && (
              <div className="flex flex-wrap gap-1.5">
                {caracs.map((c) => (
                  <Badge
                    key={c}
                    variant="outline"
                    className="text-[10px] h-5 border-border/50 capitalize"
                  >
                    {c.replace(/_/g, " ")}
                  </Badge>
                ))}
              </div>
            )}

            <div className="flex items-center gap-4 text-xs text-muted-foreground">
              <span>
                <strong className="text-foreground">{job.total_itens_sugeridos}</strong> itens sugeridos
              </span>
              {job.total_itens_aplicados > 0 && (
                <span>
                  <strong className="text-emerald-400">{job.total_itens_aplicados}</strong> aplicados
                </span>
              )}
            </div>
          </div>

          {job.status === "concluido" && (
            <Button
              variant="ghost"
              size="sm"
              className="shrink-0"
              onClick={() => {
                setExpanded(!expanded);
                if (!expanded && itens.length > 0) {
                  setSelectedItems(new Set(itens.map((i) => i.id)));
                }
              }}
            >
              {expanded ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
            </Button>
          )}
        </div>

        {expanded && (
          <div className="mt-4 pt-4 border-t border-border/40 space-y-3">
            {itens.length > 0 ? (
              <>
                <div className="flex items-center justify-between">
                  <p className="text-sm text-muted-foreground">
                    {itens.length} itens sugeridos pela IA
                  </p>
                  <div className="flex items-center gap-2">
                    <Button size="sm" variant="ghost" onClick={selectAll}>
                      {selectedItems.size === itens.length ? "Desmarcar" : "Selecionar"} todos
                    </Button>
                    <Button
                      size="sm"
                      disabled={selectedItems.size === 0 || aplicar.isPending}
                      onClick={handleAplicar}
                    >
                      {aplicar.isPending ? (
                        <Loader2 className="h-3 w-3 animate-spin mr-1" />
                      ) : (
                        <Check className="h-3 w-3 mr-1" />
                      )}
                      Aplicar ({selectedItems.size})
                    </Button>
                  </div>
                </div>
                <div className="space-y-2 max-h-96 overflow-y-auto">
                  {itens.map((item) => (
                    <ItemCard
                      key={item.id}
                      item={item}
                      selected={selectedItems.has(item.id)}
                      onToggle={() => toggleItem(item.id)}
                    />
                  ))}
                </div>
              </>
            ) : (
              <div className="rounded-lg bg-muted/10 border border-border/30 p-6 text-center">
                <Loader2 className="h-5 w-5 animate-spin text-muted-foreground mx-auto mb-2" />
                <p className="text-sm text-muted-foreground">Carregando itens...</p>
              </div>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function MockJobCard({ job }: { job: typeof CHECKLIST_JOBS_MOCK[0] }) {
  // Convert mock to ChecklistGeracaoLog shape
  const converted: ChecklistGeracaoLog = {
    id: job.id,
    obra_id: job.obraId,
    status: job.status,
    total_docs_analisados: job.totalDocsAnalisados,
    caracteristicas_identificadas: job.caracteristicasIdentificadas,
    total_itens_sugeridos: job.totalItensSugeridos,
    total_itens_aplicados: job.totalItensAplicados,
    total_paginas: job.totalPaginas,
    paginas_processadas: job.paginasProcessadas,
    resumo_geral: job.resumoGeral,
    aviso_legal: job.avisoLegal,
    erro_detalhe: job.erroDetalhe,
    created_at: job.createdAt,
    updated_at: job.createdAt,
  };
  return <JobCard job={converted} useMock />;
}

export default function Checklists() {
  const { data: historico, isLoading, error } = useChecklistHistorico(OBRA_ID);
  const iniciar = useIniciarChecklist();

  const hasRealData = historico && historico.length > 0;

  // Find active processing job for polling
  const activeJob = historico?.find((j) => j.status === "processando");
  useChecklistStatus(OBRA_ID, activeJob?.id || null, !!activeJob);

  const handleGerar = () => {
    iniciar.mutate(OBRA_ID);
  };

  return (
    <div className="space-y-6 max-w-4xl mx-auto">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-3xl font-display font-bold tracking-tight">
            Checklist Inteligente
          </h2>
          <p className="text-sm text-muted-foreground mt-1">
            A IA analisa seus projetos e gera checklists personalizados para cada etapa da obra.
          </p>
        </div>
        <Button
          className="bg-primary hover:bg-primary/90 text-white gap-2"
          onClick={handleGerar}
          disabled={iniciar.isPending}
        >
          {iniciar.isPending ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Sparkles className="h-4 w-4" />
          )}
          Gerar Novo Checklist
        </Button>
      </div>

      <Card className="border-primary/20 bg-gradient-to-r from-primary/5 to-transparent">
        <CardContent className="p-4 flex items-start gap-3">
          <FileCheck className="h-5 w-5 text-primary mt-0.5 shrink-0" />
          <p className="text-sm text-muted-foreground">
            O processamento continua mesmo que você saia desta tela. Você pode
            acompanhar o progresso e revisar os itens quando voltar.
          </p>
        </CardContent>
      </Card>

      {isLoading && (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        </div>
      )}

      <div className="space-y-4">
        {hasRealData
          ? historico.map((job) => <JobCard key={job.id} job={job} />)
          : !isLoading && (
              CHECKLIST_JOBS_MOCK.length === 0 ? (
                <Card className="border-dashed border-border/50">
                  <CardContent className="p-12 text-center">
                    <Sparkles className="h-10 w-10 text-muted-foreground/40 mx-auto mb-4" />
                    <p className="text-muted-foreground">
                      Nenhum checklist gerado ainda. Clique em &quot;Gerar Novo Checklist&quot; para começar.
                    </p>
                  </CardContent>
                </Card>
              ) : (
                CHECKLIST_JOBS_MOCK.map((job) => <MockJobCard key={job.id} job={job} />)
              )
            )
        }
      </div>

      {error && !hasRealData && (
        <p className="text-xs text-muted-foreground text-center">
          Exibindo dados de demonstração. Conecte-se ao backend para dados reais.
        </p>
      )}
    </div>
  );
}
