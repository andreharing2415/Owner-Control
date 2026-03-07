import { useAnalise, parsePerguntas, parseDocumentos, type Risco } from "@/lib/api";
import { ANALYSIS_MOCK } from "@/lib/mock-data";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  AlertTriangle,
  ArrowLeft,
  FileText,
  Share2,
  Download,
  AlertOctagon,
  ExternalLink,
  MessageCircleQuestion,
  FileCheck2,
  HandHelping,
  ChevronDown,
  ChevronUp,
  HelpCircle,
  Loader2,
} from "lucide-react";
import { Link, useParams } from "wouter";
import { ScrollArea } from "@/components/ui/scroll-area";
import { useState } from "react";

function NormaLink({
  normaReferencia,
  normaUrl,
}: {
  normaReferencia: string | null;
  normaUrl: string | null;
}) {
  if (!normaReferencia) return null;
  const url =
    normaUrl ||
    `https://www.google.com/search?q=ABNT+${encodeURIComponent(normaReferencia)}`;
  return (
    <a
      href={url}
      target="_blank"
      rel="noopener noreferrer"
      className="inline-flex items-center gap-1.5 text-xs text-primary hover:text-primary/80 transition-colors font-medium"
    >
      <ExternalLink className="h-3 w-3" />
      {normaReferencia}
    </a>
  );
}

interface FindingData {
  id: string | number;
  severity: string;
  title: string;
  normaReferencia: string | null;
  normaUrl: string | null;
  traducaoLeigo: string;
  acaoProprietario: string | null;
  perguntas: { pergunta: string; resposta_esperada?: string; respostaEsperada?: string }[];
  documentos: string[];
  requerValidacaoProfissional: boolean;
  location?: string;
  page?: number;
}

function FindingCard({ finding, isExpanded, onToggle }: {
  finding: FindingData;
  isExpanded: boolean;
  onToggle: () => void;
}) {
  return (
    <Card className="border-border/50 bg-card/40 overflow-hidden">
      <div
        className="p-5 cursor-pointer hover:bg-card/60 transition-colors"
        onClick={onToggle}
      >
        <div className="flex gap-4 items-start">
          <div
            className={
              finding.severity === "high" || finding.severity === "alto"
                ? "text-red-500 bg-red-500/10 p-2 rounded-md"
                : finding.severity === "medium" || finding.severity === "medio"
                  ? "text-amber-500 bg-amber-500/10 p-2 rounded-md"
                  : "text-blue-500 bg-blue-500/10 p-2 rounded-md"
            }
          >
            {finding.severity === "high" || finding.severity === "alto" ? (
              <AlertOctagon className="h-5 w-5" />
            ) : finding.severity === "medium" || finding.severity === "medio" ? (
              <AlertTriangle className="h-5 w-5" />
            ) : (
              <FileText className="h-5 w-5" />
            )}
          </div>

          <div className="flex-1 space-y-2">
            <div className="flex justify-between items-start">
              <h4 className="font-semibold text-sm">{finding.title}</h4>
              <div className="flex items-center gap-2 shrink-0">
                <NormaLink
                  normaReferencia={finding.normaReferencia}
                  normaUrl={finding.normaUrl}
                />
                {finding.page && (
                  <Badge variant="secondary" className="text-[10px] h-5">
                    Pg. {finding.page}
                  </Badge>
                )}
                {isExpanded ? (
                  <ChevronUp className="h-4 w-4 text-muted-foreground" />
                ) : (
                  <ChevronDown className="h-4 w-4 text-muted-foreground" />
                )}
              </div>
            </div>

            <div className="flex items-start gap-2 rounded-lg bg-muted/20 p-3">
              <HelpCircle className="h-4 w-4 text-primary shrink-0 mt-0.5" />
              <div>
                <span className="text-xs font-semibold text-primary block mb-0.5">
                  O que isso significa?
                </span>
                <p className="text-sm text-muted-foreground leading-relaxed">
                  {finding.traducaoLeigo}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {isExpanded && (
        <div className="px-5 pb-5 space-y-4 border-t border-border/30 pt-4 ml-14">
          {finding.acaoProprietario && (
            <div className="flex items-start gap-2 rounded-lg bg-emerald-500/5 border border-emerald-500/10 p-3">
              <HandHelping className="h-4 w-4 text-emerald-400 shrink-0 mt-0.5" />
              <div>
                <span className="text-xs font-semibold text-emerald-400 block mb-0.5">
                  O que você deve fazer
                </span>
                <p className="text-sm text-muted-foreground leading-relaxed">
                  {finding.acaoProprietario}
                </p>
              </div>
            </div>
          )}

          {finding.perguntas.length > 0 && (
            <div className="rounded-lg bg-blue-500/5 border border-blue-500/10 p-3">
              <div className="flex items-center gap-2 mb-3">
                <MessageCircleQuestion className="h-4 w-4 text-blue-400" />
                <span className="text-xs font-semibold text-blue-400">
                  Pergunte ao seu engenheiro
                </span>
              </div>
              <div className="space-y-3">
                {finding.perguntas.map((p, idx) => (
                  <div key={idx} className="space-y-1">
                    <p className="text-sm text-foreground/90 font-medium">
                      &ldquo;{p.pergunta}&rdquo;
                    </p>
                    <p className="text-xs text-muted-foreground/70 pl-3 border-l-2 border-blue-500/20">
                      Resposta esperada: {p.resposta_esperada || p.respostaEsperada}
                    </p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {finding.documentos.length > 0 && (
            <div className="rounded-lg bg-amber-500/5 border border-amber-500/10 p-3">
              <div className="flex items-center gap-2 mb-2">
                <FileCheck2 className="h-4 w-4 text-amber-400" />
                <span className="text-xs font-semibold text-amber-400">
                  Documentos a exigir
                </span>
              </div>
              <ul className="space-y-1.5">
                {finding.documentos.map((doc, idx) => (
                  <li key={idx} className="text-sm text-muted-foreground flex items-start gap-2">
                    <span className="text-amber-400/60 mt-1">•</span>
                    {doc}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {finding.requerValidacaoProfissional && (
            <div className="flex items-center gap-2 text-xs text-red-400 bg-red-500/5 rounded-md px-3 py-2">
              <AlertOctagon className="h-3.5 w-3.5 shrink-0" />
              Este item requer validação de engenheiro ou arquiteto antes de qualquer ação.
            </div>
          )}

          {finding.location && (
            <div className="text-xs text-muted-foreground/60">
              <span className="font-medium text-foreground/60">Local no projeto:</span>{" "}
              {finding.location}{finding.page ? ` — Página ${finding.page}` : ""}
            </div>
          )}
        </div>
      )}
    </Card>
  );
}

export default function DocumentAnalysis() {
  const params = useParams<{ id: string }>();
  const projetoId = params.id || "";
  const { data: analise, isLoading } = useAnalise(projetoId);
  const [expandedId, setExpandedId] = useState<string | number | null>(null);

  // Transform real API data into finding format
  const findings: FindingData[] | null = analise
    ? analise.riscos.map((r: Risco) => ({
        id: r.id,
        severity: r.severidade,
        title: r.descricao.length > 100 ? r.descricao.substring(0, 100) + "..." : r.descricao,
        normaReferencia: r.norma_referencia,
        normaUrl: r.norma_url,
        traducaoLeigo: r.traducao_leigo,
        acaoProprietario: r.acao_proprietario,
        perguntas: parsePerguntas(r.perguntas_para_profissional),
        documentos: parseDocumentos(r.documentos_a_exigir),
        requerValidacaoProfissional: r.requer_validacao_profissional,
      }))
    : null;

  // Fallback to mock data
  const mockFindings: FindingData[] = ANALYSIS_MOCK.findings.map((f) => ({
    id: f.id,
    severity: f.severity,
    title: f.title,
    normaReferencia: f.normaReferencia,
    normaUrl: f.normaUrl,
    traducaoLeigo: f.traducaoLeigo,
    acaoProprietario: f.acaoProprietario,
    perguntas: f.perguntasParaProfissional,
    documentos: f.documentosAExigir,
    requerValidacaoProfissional: f.requerValidacaoProfissional,
    location: f.location,
    page: f.page,
  }));

  const displayFindings = findings || mockFindings;
  const fileName = analise?.projeto.arquivo_nome || ANALYSIS_MOCK.fileName;
  const isMock = !findings;

  return (
    <div className="h-[calc(100vh-8rem)] flex flex-col space-y-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 shrink-0">
        <div className="flex items-center gap-4">
          <Button asChild variant="ghost" size="icon" className="rounded-full">
            <Link href="/app/documents">
              <ArrowLeft className="h-5 w-5" />
            </Link>
          </Button>
          <div>
            <h2 className="text-2xl font-display font-bold tracking-tight flex items-center gap-2">
              Análise IA: {fileName}
              {isMock && (
                <Badge variant="secondary" className="text-[10px] ml-2">Demo</Badge>
              )}
            </h2>
            {analise?.projeto.resumo_geral && (
              <p className="text-sm text-muted-foreground mt-1 line-clamp-2">
                {analise.projeto.resumo_geral}
              </p>
            )}
          </div>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="sm" className="gap-2">
            <Share2 className="h-4 w-4" /> Compartilhar
          </Button>
          <Button variant="secondary" size="sm" className="gap-2">
            <Download className="h-4 w-4" /> Baixar Relatório
          </Button>
        </div>
      </div>

      {/* Disclaimer */}
      <Card className="border-amber-500/20 bg-amber-500/5 shrink-0">
        <CardContent className="p-3 flex items-start gap-2">
          <AlertTriangle className="h-4 w-4 text-amber-500 mt-0.5 shrink-0" />
          <p className="text-xs text-amber-200/80">
            {analise?.projeto.aviso_legal ||
              "Esta análise é informativa e NÃO substitui parecer técnico de engenheiro ou arquiteto habilitado. Use as orientações abaixo para conversar com seus profissionais."}
          </p>
        </CardContent>
      </Card>

      {isLoading && (
        <div className="flex-1 flex items-center justify-center">
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        </div>
      )}

      {/* Findings */}
      {!isLoading && (
        <ScrollArea className="flex-1">
          <div className="space-y-4 pb-6">
            {displayFindings.map((finding) => (
              <FindingCard
                key={finding.id}
                finding={finding}
                isExpanded={expandedId === finding.id}
                onToggle={() =>
                  setExpandedId(expandedId === finding.id ? null : finding.id)
                }
              />
            ))}
          </div>
        </ScrollArea>
      )}
    </div>
  );
}
