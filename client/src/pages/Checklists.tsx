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
  Play,
  ChevronDown,
  ChevronUp,
  FileCheck,
  Clock,
} from "lucide-react";
import { useState } from "react";

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

function parseCaracteristicas(json: string | null): string[] {
  if (!json) return [];
  try {
    return JSON.parse(json);
  } catch {
    return [];
  }
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

export default function Checklists() {
  const [expandedId, setExpandedId] = useState<string | null>(null);

  return (
    <div className="space-y-6 max-w-4xl mx-auto">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-3xl font-display font-bold tracking-tight">
            Checklist Inteligente
          </h2>
          <p className="text-sm text-muted-foreground mt-1">
            A IA analisa seus projetos e gera checklists personalizados para
            cada etapa da obra.
          </p>
        </div>
        <Button className="bg-primary hover:bg-primary/90 text-white gap-2">
          <Sparkles className="h-4 w-4" />
          Gerar Novo Checklist
        </Button>
      </div>

      {/* Info Card */}
      <Card className="border-primary/20 bg-gradient-to-r from-primary/5 to-transparent">
        <CardContent className="p-4 flex items-start gap-3">
          <FileCheck className="h-5 w-5 text-primary mt-0.5 shrink-0" />
          <p className="text-sm text-muted-foreground">
            O processamento continua mesmo que você saia desta tela. Você pode
            acompanhar o progresso e revisar os itens quando voltar.
          </p>
        </CardContent>
      </Card>

      {/* Jobs List */}
      <div className="space-y-4">
        {CHECKLIST_JOBS_MOCK.length === 0 ? (
          <Card className="border-dashed border-border/50">
            <CardContent className="p-12 text-center">
              <Sparkles className="h-10 w-10 text-muted-foreground/40 mx-auto mb-4" />
              <p className="text-muted-foreground">
                Nenhum checklist gerado ainda. Clique em &quot;Gerar Novo
                Checklist&quot; para começar.
              </p>
            </CardContent>
          </Card>
        ) : (
          CHECKLIST_JOBS_MOCK.map((job) => {
            const caracs = parseCaracteristicas(
              job.caracteristicasIdentificadas
            );
            const isExpanded = expandedId === job.id;
            const progress =
              job.totalPaginas > 0
                ? Math.round(
                    (job.paginasProcessadas / job.totalPaginas) * 100
                  )
                : 0;

            return (
              <Card
                key={job.id}
                className="border-border/50 bg-card/40 hover:bg-card/60 transition-colors"
              >
                <CardContent className="p-5">
                  {/* Job Header */}
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex-1 space-y-3">
                      <div className="flex items-center gap-3 flex-wrap">
                        <StatusBadge status={job.status} />
                        <span className="text-xs text-muted-foreground flex items-center gap-1">
                          <Clock className="h-3 w-3" />
                          {formatDate(job.createdAt)}
                        </span>
                        <span className="text-xs text-muted-foreground">
                          {job.totalDocsAnalisados} documento
                          {job.totalDocsAnalisados !== 1 ? "s" : ""} analisado
                          {job.totalDocsAnalisados !== 1 ? "s" : ""}
                        </span>
                      </div>

                      {/* Progress for processing jobs */}
                      {job.status === "processando" && (
                        <div className="space-y-1.5">
                          <div className="flex justify-between text-xs text-muted-foreground">
                            <span>
                              Página {job.paginasProcessadas} de{" "}
                              {job.totalPaginas}
                            </span>
                            <span>{progress}%</span>
                          </div>
                          <Progress value={progress} className="h-2" />
                        </div>
                      )}

                      {/* Summary for completed jobs */}
                      {job.status === "concluido" && job.resumoGeral && (
                        <p className="text-sm text-muted-foreground line-clamp-2">
                          {job.resumoGeral}
                        </p>
                      )}

                      {/* Error detail */}
                      {job.status === "erro" && job.erroDetalhe && (
                        <p className="text-sm text-red-400">
                          {job.erroDetalhe}
                        </p>
                      )}

                      {/* Characteristics badges */}
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

                      {/* Stats */}
                      <div className="flex items-center gap-4 text-xs text-muted-foreground">
                        <span>
                          <strong className="text-foreground">
                            {job.totalItensSugeridos}
                          </strong>{" "}
                          itens sugeridos
                        </span>
                        {job.totalItensAplicados > 0 && (
                          <span>
                            <strong className="text-emerald-400">
                              {job.totalItensAplicados}
                            </strong>{" "}
                            aplicados
                          </span>
                        )}
                      </div>
                    </div>

                    {/* Expand button for completed */}
                    {job.status === "concluido" && (
                      <Button
                        variant="ghost"
                        size="sm"
                        className="shrink-0"
                        onClick={() =>
                          setExpandedId(isExpanded ? null : job.id)
                        }
                      >
                        {isExpanded ? (
                          <ChevronUp className="h-4 w-4" />
                        ) : (
                          <ChevronDown className="h-4 w-4" />
                        )}
                      </Button>
                    )}
                  </div>

                  {/* Expanded: show items placeholder */}
                  {isExpanded && (
                    <div className="mt-4 pt-4 border-t border-border/40">
                      <p className="text-sm text-muted-foreground mb-3">
                        Itens sugeridos pela IA para aplicar ao checklist da
                        obra:
                      </p>
                      <div className="rounded-lg bg-muted/10 border border-border/30 p-6 text-center">
                        <p className="text-sm text-muted-foreground">
                          Conecte ao backend para ver os itens gerados.
                        </p>
                        <Button
                          size="sm"
                          className="mt-3 gap-2"
                          variant="secondary"
                        >
                          <Play className="h-3 w-3" />
                          Aplicar Itens Selecionados
                        </Button>
                      </div>
                    </div>
                  )}
                </CardContent>
              </Card>
            );
          })
        )}
      </div>
    </div>
  );
}
