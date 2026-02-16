import { ANALYSIS_MOCK } from "@/lib/mock-data";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { AlertTriangle, ArrowLeft, CheckCircle2, FileText, Search, Share2, Download, AlertOctagon } from "lucide-react";
import { Link, useRoute } from "wouter";
import { ScrollArea } from "@/components/ui/scroll-area";

export default function DocumentAnalysis() {
  const [, params] = useRoute("/documents/:id/analysis");
  // In a real app, use params.id to fetch data. Using mock for now.

  return (
    <div className="h-[calc(100vh-8rem)] flex flex-col space-y-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 shrink-0">
        <div className="flex items-center gap-4">
          <Button asChild variant="ghost" size="icon" className="rounded-full">
            <Link href="/documents"><ArrowLeft className="h-5 w-5" /></Link>
          </Button>
          <div>
            <h2 className="text-2xl font-display font-bold tracking-tight flex items-center gap-2">
              Análise IA: {ANALYSIS_MOCK.fileName}
            </h2>
            <div className="flex items-center gap-2 mt-1">
              <Badge variant="outline" className="border-red-500/30 text-red-500 bg-red-500/5">
                Risco Geral: Alto
              </Badge>
              <span className="text-sm text-muted-foreground">Processado em 15/02/2026</span>
            </div>
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

      {/* Main Content */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 flex-1 min-h-0">
        
        {/* Left: Document Preview (Placeholder) */}
        <Card className="bg-muted/10 border-border/50 flex flex-col overflow-hidden">
          <CardHeader className="py-3 px-4 border-b border-border/50 bg-card/30 flex flex-row justify-between items-center">
            <div className="text-xs font-medium text-muted-foreground">Visualização do Arquivo</div>
            <div className="flex gap-2">
              <Badge variant="outline" className="text-[10px]">Página 12 de 45</Badge>
            </div>
          </CardHeader>
          <div className="flex-1 bg-muted/20 relative flex items-center justify-center p-8">
            <div className="absolute inset-0 opacity-10 bg-[url('https://www.transparenttextures.com/patterns/graphy.png')]"></div>
            <img 
              src="/images/blueprint-abstract.png" 
              alt="Blueprint Preview" 
              className="max-w-full max-h-full shadow-2xl border border-white/10 opacity-80"
            />
            
            {/* Simulation of an annotation overlay */}
            <div className="absolute top-1/3 left-1/4 bg-red-500/20 border-2 border-red-500 w-32 h-32 rounded animate-pulse flex items-center justify-center">
              <div className="bg-red-500 text-white text-[10px] font-bold px-1 py-0.5 rounded absolute -top-3 left-0">
                Finding #1
              </div>
            </div>
          </div>
        </Card>

        {/* Right: Analysis Results */}
        <Card className="bg-card/40 border-border/50 flex flex-col overflow-hidden">
          <CardHeader className="pb-2">
            <CardTitle className="text-lg flex items-center gap-2">
              <Search className="h-5 w-5 text-primary" />
              Resultados da Análise
            </CardTitle>
            <CardDescription>
              {ANALYSIS_MOCK.summary}
            </CardDescription>
          </CardHeader>
          
          <ScrollArea className="flex-1">
            <CardContent className="space-y-4 pt-4">
              {ANALYSIS_MOCK.findings.map((finding) => (
                <div key={finding.id} className="group rounded-lg border border-border/50 bg-card/50 p-4 hover:bg-card/80 transition-all hover:border-primary/20">
                  <div className="flex gap-4 items-start">
                    <div className={
                      finding.severity === 'high' ? "text-red-500 bg-red-500/10 p-2 rounded-md" :
                      finding.severity === 'medium' ? "text-amber-500 bg-amber-500/10 p-2 rounded-md" :
                      "text-blue-500 bg-blue-500/10 p-2 rounded-md"
                    }>
                      {finding.severity === 'high' ? <AlertOctagon className="h-5 w-5" /> :
                       finding.severity === 'medium' ? <AlertTriangle className="h-5 w-5" /> :
                       <FileText className="h-5 w-5" />}
                    </div>
                    
                    <div className="flex-1 space-y-1">
                      <div className="flex justify-between items-start">
                        <h4 className="font-semibold text-sm group-hover:text-primary transition-colors">
                          {finding.title}
                        </h4>
                        <Badge variant="secondary" className="text-[10px] h-5">
                          Pg. {finding.page}
                        </Badge>
                      </div>
                      <p className="text-sm text-muted-foreground leading-relaxed">
                        {finding.description}
                      </p>
                      <div className="pt-2 flex items-center gap-2 text-xs text-muted-foreground/70">
                        <span className="font-medium text-foreground/80">Local:</span> {finding.location}
                      </div>
                    </div>
                  </div>
                  
                  {/* Action Buttons */}
                  <div className="mt-4 pl-14 flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <Button size="sm" variant="outline" className="h-7 text-xs">
                      Ver na Norma
                    </Button>
                    <Button size="sm" variant="ghost" className="h-7 text-xs hover:text-red-400">
                      Marcar como Erro
                    </Button>
                  </div>
                </div>
              ))}
            </CardContent>
          </ScrollArea>
        </Card>

      </div>
    </div>
  );
}
