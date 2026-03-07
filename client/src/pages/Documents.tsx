import { useDocuments, type ProjetoDoc } from "@/lib/api";
import { DOCUMENTS_MOCK } from "@/lib/mock-data";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { FileText, Upload, Search, Filter, Clock, Eye, MoreVertical, CheckSquare, Loader2, AlertTriangle } from "lucide-react";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { Link } from "wouter";

function riskBadge(status: string) {
  if (status === "concluido") return "analyzed";
  if (status === "processando") return "pending";
  return "pending";
}

function DocCard({ doc }: { doc: ProjetoDoc }) {
  const isAnalyzed = doc.status === "concluido";

  return (
    <Card className="group border-border/50 bg-card/40 hover:bg-card/60 transition-all hover:border-primary/20">
      <CardContent className="p-4 flex items-center gap-4">
        <div className="h-12 w-12 rounded-lg bg-muted/50 flex items-center justify-center shrink-0 group-hover:bg-primary/10 transition-colors">
          <FileText className="h-6 w-6 text-red-400" />
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-1">
            <h3 className="font-semibold text-base truncate group-hover:text-primary transition-colors">
              {doc.arquivo_nome}
            </h3>
          </div>
          <div className="flex items-center gap-3 text-xs text-muted-foreground">
            <span>{doc.status === "concluido" ? "Analisado" : doc.status === "processando" ? "Processando" : "Pendente"}</span>
            <span className="w-1 h-1 rounded-full bg-border" />
            <span>{new Date(doc.created_at).toLocaleDateString("pt-BR")}</span>
          </div>
        </div>

        <div className="hidden md:flex flex-col items-end gap-1.5">
          {isAnalyzed ? (
            <Badge variant="outline" className="bg-emerald-500/10 text-emerald-500 border-emerald-500/20">
              Análise Concluída
            </Badge>
          ) : doc.status === "processando" ? (
            <Badge variant="secondary" className="bg-muted text-muted-foreground">
              <Loader2 className="h-3 w-3 mr-1 animate-spin" /> Processando
            </Badge>
          ) : doc.status === "erro" ? (
            <Badge variant="outline" className="bg-red-500/10 text-red-500 border-red-500/20">
              <AlertTriangle className="h-3 w-3 mr-1" /> Erro
            </Badge>
          ) : (
            <Badge variant="secondary" className="bg-muted text-muted-foreground">
              <Clock className="h-3 w-3 mr-1" /> Pendente
            </Badge>
          )}
        </div>

        <div className="flex items-center gap-2 border-l border-border/50 pl-4 ml-2">
          {isAnalyzed && (
            <Button asChild size="sm" variant="ghost" className="hidden sm:flex text-primary hover:text-primary hover:bg-primary/10">
              <Link href={`/app/documents/${doc.id}/analysis`}>
                Ver Análise <Eye className="ml-2 h-4 w-4" />
              </Link>
            </Button>
          )}
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" className="h-8 w-8">
                <MoreVertical className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem>Baixar Arquivo</DropdownMenuItem>
              <DropdownMenuItem className="text-red-500">Excluir</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </CardContent>
    </Card>
  );
}

function MockDocCard({ doc }: { doc: typeof DOCUMENTS_MOCK[0] }) {
  return (
    <Card className="group border-border/50 bg-card/40 hover:bg-card/60 transition-all hover:border-primary/20">
      <CardContent className="p-4 flex items-center gap-4">
        <div className="h-12 w-12 rounded-lg bg-muted/50 flex items-center justify-center shrink-0 group-hover:bg-primary/10 transition-colors">
          <FileText className="h-6 w-6 text-red-400" />
        </div>
        <div className="flex-1 min-w-0">
          <h3 className="font-semibold text-base truncate">{doc.name}</h3>
          <div className="flex items-center gap-3 text-xs text-muted-foreground">
            <span>{doc.category}</span>
            <span className="w-1 h-1 rounded-full bg-border" />
            <span>{doc.size}</span>
          </div>
        </div>
        <Badge variant="secondary" className="bg-muted/50 text-muted-foreground text-[10px]">
          Demo
        </Badge>
      </CardContent>
    </Card>
  );
}

export default function Documents() {
  const { data: documents, isLoading, error } = useDocuments();
  const hasRealData = documents && documents.length > 0;

  return (
    <div className="space-y-8 max-w-6xl mx-auto">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-3xl font-display font-bold tracking-tight">Documentação de Projeto</h2>
          <p className="text-muted-foreground mt-1">Centralize e analise seus projetos com IA</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button asChild variant="outline" className="gap-2">
            <Link href="/app/checklists">
              <CheckSquare className="h-4 w-4" /> Checklist IA
            </Link>
          </Button>
          <Button variant="outline" className="gap-2">
            <Filter className="h-4 w-4" /> Filtros
          </Button>
          <Button className="bg-primary text-white gap-2">
            <Upload className="h-4 w-4" /> Upload de Arquivo
          </Button>
        </div>
      </div>

      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
        <Input placeholder="Buscar por nome, disciplina ou conteúdo..." className="pl-10 h-12 bg-card/50 border-border/50" />
      </div>

      {isLoading && (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        </div>
      )}

      <div className="grid gap-4">
        {hasRealData
          ? documents.map((doc) => <DocCard key={doc.id} doc={doc} />)
          : !isLoading && DOCUMENTS_MOCK.map((doc) => <MockDocCard key={doc.id} doc={doc} />)
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
