import { useState } from "react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Search, Sparkles, BookOpen, ExternalLink, ThumbsUp, AlertCircle, ArrowRight, CheckSquare } from "lucide-react";
import { ScrollArea } from "@/components/ui/scroll-area";
import { cn } from "@/lib/utils";
import { Checkbox } from "@/components/ui/checkbox";

export default function NormsSearch() {
  const [query, setQuery] = useState("");
  const [isSearching, setIsSearching] = useState(false);
  const [hasResults, setHasResults] = useState(false);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (!query.trim()) return;
    
    setIsSearching(true);
    // Simulate API delay
    setTimeout(() => {
      setIsSearching(false);
      setHasResults(true);
    }, 1500);
  };

  return (
    <div className="max-w-4xl mx-auto space-y-8 min-h-[80vh] flex flex-col justify-center">
      
      {/* Header & Search */}
      <div className={cn(
        "space-y-8 transition-all duration-500 ease-in-out text-center",
        hasResults ? "mt-0" : "mt-[-100px]"
      )}>
        <div className="space-y-4">
          <Badge variant="outline" className="py-1.5 px-4 text-sm border-primary/20 bg-primary/5 text-primary">
            <Sparkles className="h-3 w-3 mr-2 fill-primary" />
            IA Normativa Beta 1.0
          </Badge>
          <h1 className="text-4xl md:text-6xl font-display font-bold tracking-tight bg-gradient-to-br from-white to-white/50 bg-clip-text text-transparent pb-2">
            O que você precisa validar?
          </h1>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
            Nossa IA busca normas técnicas atualizadas (NBR) e traduz para linguagem simples.
          </p>
        </div>

        <form onSubmit={handleSearch} className="relative max-w-2xl mx-auto">
          <div className="relative group">
            <div className="absolute inset-0 bg-primary/20 blur-xl rounded-full opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
            <div className="relative flex items-center bg-background border border-border rounded-full shadow-2xl p-2 pl-6 focus-within:border-primary/50 transition-colors">
              <Search className="h-6 w-6 text-muted-foreground" />
              <Input 
                className="border-0 shadow-none focus-visible:ring-0 bg-transparent text-lg h-14 placeholder:text-muted-foreground/50"
                placeholder="Ex: Qual a espessura mínima do contrapiso?"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
              />
              <Button 
                size="lg" 
                className="rounded-full h-12 w-12 p-0 bg-primary hover:bg-primary/90 shadow-lg shadow-primary/20"
                disabled={isSearching}
              >
                {isSearching ? (
                  <Sparkles className="h-5 w-5 animate-spin" />
                ) : (
                  <ArrowRight className="h-5 w-5" />
                )}
              </Button>
            </div>
          </div>
          
          <div className="flex flex-wrap gap-2 justify-center mt-4 text-sm text-muted-foreground">
            <span>Sugestões:</span>
            <button type="button" onClick={() => setQuery("Cura do concreto")} className="hover:text-primary underline decoration-dotted">Cura do concreto</button>
            <button type="button" onClick={() => setQuery("Impermeabilização piscina")} className="hover:text-primary underline decoration-dotted">Impermeabilização piscina</button>
            <button type="button" onClick={() => setQuery("Altura guarda-corpo")} className="hover:text-primary underline decoration-dotted">Altura guarda-corpo</button>
          </div>
        </form>
      </div>

      {/* Results Section */}
      {hasResults && (
        <div className="animate-in fade-in slide-in-from-bottom-10 duration-700 space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            
            {/* Main Answer */}
            <Card className="md:col-span-2 border-primary/20 bg-card/40 backdrop-blur-md h-fit">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-primary">
                  <Sparkles className="h-5 w-5" />
                  Resposta da IA
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="prose prose-invert max-w-none text-muted-foreground leading-relaxed">
                  <p>
                    Com base na norma <strong className="text-foreground">NBR 13753:1996</strong> (Revestimento de piso interno ou externo com placas cerâmicas e com utilização de argamassa colante), a espessura do contrapiso deve variar de acordo com a condição da base:
                  </p>
                  <ul className="list-disc pl-4 space-y-2 mt-2">
                    <li><span className="text-foreground font-medium">Mínimo de 20mm (2cm)</span> quando aplicado diretamente sobre a laje limpa e úmida (aderido).</li>
                    <li><span className="text-foreground font-medium">Mínimo de 40mm (4cm)</span> quando houver camada de separação (como impermeabilização) ou isolamento térmico/acústico (flutuante).</li>
                  </ul>
                  <div className="bg-amber-500/10 border border-amber-500/20 rounded-lg p-4 mt-4 flex gap-3">
                    <AlertCircle className="h-5 w-5 text-amber-500 shrink-0" />
                    <div className="text-sm text-amber-200/80">
                      <p className="font-medium text-amber-500 mb-1">Ponto de Atenção</p>
                      Em áreas molhadas (banheiros, lavanderias), o contrapiso deve ter caimento mínimo de 0,5% a 1% em direção ao ralo.
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Right Column: Sources & Checklist */}
            <div className="space-y-6">
              
              {/* Generated Checklist */}
              <div className="bg-gradient-to-br from-primary/10 to-primary/5 rounded-xl p-5 border border-primary/20 shadow-lg shadow-primary/5">
                <div className="flex items-center gap-2 mb-4">
                  <CheckSquare className="h-5 w-5 text-primary" />
                  <span className="font-bold text-primary">Checklist Gerado</span>
                </div>
                <div className="space-y-3">
                  <div className="flex items-start space-x-2">
                    <Checkbox id="c1" defaultChecked />
                    <label htmlFor="c1" className="text-sm leading-tight text-foreground/90 font-medium">
                      Verificar espessura (mín. 2cm aderido)
                    </label>
                  </div>
                  <div className="flex items-start space-x-2">
                    <Checkbox id="c2" defaultChecked />
                    <label htmlFor="c2" className="text-sm leading-tight text-foreground/90 font-medium">
                      Conferir caimento 1% p/ ralo
                    </label>
                  </div>
                  <div className="flex items-start space-x-2">
                    <Checkbox id="c3" />
                    <label htmlFor="c3" className="text-sm leading-tight text-foreground/90 font-medium">
                      Validar limpeza da laje antes
                    </label>
                  </div>
                </div>
                <Button className="w-full mt-4 bg-primary text-white hover:bg-primary/90" size="sm">
                  Salvar na Etapa "Acabamentos"
                </Button>
              </div>

              {/* Sources */}
              <div className="space-y-3">
                <h3 className="text-xs font-semibold text-muted-foreground uppercase tracking-wider pl-1">Fontes Normativas</h3>
                
                <Card className="border-border/50 bg-card/30 hover:bg-card/50 transition-colors cursor-pointer group">
                  <CardContent className="p-3">
                    <div className="flex items-start justify-between">
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <Badge variant="outline" className="bg-emerald-500/10 text-emerald-500 border-emerald-500/20 text-[10px] h-5 px-1.5">Vigente</Badge>
                          <span className="font-bold text-sm group-hover:text-primary transition-colors">NBR 13753</span>
                        </div>
                        <p className="text-xs text-muted-foreground line-clamp-1">Revestimento de piso interno ou externo...</p>
                      </div>
                      <ExternalLink className="h-3 w-3 text-muted-foreground group-hover:text-primary opacity-0 group-hover:opacity-100 transition-all" />
                    </div>
                  </CardContent>
                </Card>

                <Card className="border-border/50 bg-card/30 hover:bg-card/50 transition-colors cursor-pointer group">
                  <CardContent className="p-3">
                    <div className="flex items-start justify-between">
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <Badge variant="outline" className="bg-blue-500/10 text-blue-500 border-blue-500/20 text-[10px] h-5 px-1.5">Complem.</Badge>
                          <span className="font-bold text-sm group-hover:text-primary transition-colors">NBR 15575-3</span>
                        </div>
                        <p className="text-xs text-muted-foreground line-clamp-1">Desempenho: Sistemas de pisos</p>
                      </div>
                      <ExternalLink className="h-3 w-3 text-muted-foreground group-hover:text-primary opacity-0 group-hover:opacity-100 transition-all" />
                    </div>
                  </CardContent>
                </Card>
              </div>

            </div>

          </div>
        </div>
      )}
    </div>
  );
}
