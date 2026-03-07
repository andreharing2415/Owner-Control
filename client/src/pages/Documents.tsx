import { DOCUMENTS_MOCK } from "@/lib/mock-data";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { FileText, Upload, Search, Filter, AlertTriangle, CheckCircle2, Clock, Eye, MoreVertical, FileCode, FileType, CheckSquare } from "lucide-react";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { Link } from "wouter";

export default function Documents() {
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

      {/* Search Bar */}
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
        <Input placeholder="Buscar por nome, disciplina ou conteúdo..." className="pl-10 h-12 bg-card/50 border-border/50" />
      </div>

      {/* Documents List */}
      <div className="grid gap-4">
        {DOCUMENTS_MOCK.map((doc) => (
          <Card key={doc.id} className="group border-border/50 bg-card/40 hover:bg-card/60 transition-all hover:border-primary/20">
            <CardContent className="p-4 flex items-center gap-4">
              {/* Icon */}
              <div className="h-12 w-12 rounded-lg bg-muted/50 flex items-center justify-center shrink-0 group-hover:bg-primary/10 transition-colors">
                {doc.type === 'PDF' ? <FileText className="h-6 w-6 text-red-400" /> :
                 doc.type === 'DWG' ? <FileCode className="h-6 w-6 text-blue-400" /> :
                 <FileType className="h-6 w-6 text-amber-400" />}
              </div>

              {/* Info */}
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <h3 className="font-semibold text-base truncate group-hover:text-primary transition-colors">{doc.name}</h3>
                  <Badge variant="outline" className="text-[10px] h-5 px-1.5 border-border">{doc.version}</Badge>
                </div>
                <div className="flex items-center gap-3 text-xs text-muted-foreground">
                  <span>{doc.category}</span>
                  <span className="w-1 h-1 rounded-full bg-border" />
                  <span>{doc.size}</span>
                  <span className="w-1 h-1 rounded-full bg-border" />
                  <span>{doc.uploadedAt}</span>
                </div>
              </div>

              {/* Status & Analysis */}
              <div className="hidden md:flex flex-col items-end gap-1.5">
                {doc.status === 'analyzed' ? (
                  <div className="flex items-center gap-2">
                    <span className="text-xs text-muted-foreground">Análise IA:</span>
                    <Badge variant="outline" className={
                      doc.riskLevel === 'high' ? "bg-red-500/10 text-red-500 border-red-500/20" :
                      doc.riskLevel === 'medium' ? "bg-amber-500/10 text-amber-500 border-amber-500/20" :
                      "bg-emerald-500/10 text-emerald-500 border-emerald-500/20"
                    }>
                      {doc.riskLevel === 'high' ? "Risco Alto" :
                       doc.riskLevel === 'medium' ? "Atenção" :
                       "Aprovado"}
                    </Badge>
                  </div>
                ) : (
                  <Badge variant="secondary" className="bg-muted text-muted-foreground">
                    <Clock className="h-3 w-3 mr-1" /> Em Processamento
                  </Badge>
                )}
              </div>

              {/* Actions */}
              <div className="flex items-center gap-2 border-l border-border/50 pl-4 ml-2">
                {doc.status === 'analyzed' && (
                  <Button asChild size="sm" variant="ghost" className="hidden sm:flex text-primary hover:text-primary hover:bg-primary/10">
                    <Link href={`/documents/${doc.id}/analysis`}>
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
                    <DropdownMenuItem>Substituir Versão</DropdownMenuItem>
                    <DropdownMenuItem className="text-red-500">Excluir</DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
