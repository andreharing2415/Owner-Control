import { CHECKLIST_MOCK } from "@/lib/mock-data";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Camera, Upload, AlertTriangle, MessageSquare, Info, CheckCircle2 } from "lucide-react";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Progress } from "@/components/ui/progress";
import { Separator } from "@/components/ui/separator";

export default function Checklists() {
  const completedCount = CHECKLIST_MOCK.items.filter(i => i.status === 'checked').length;
  const progress = Math.round((completedCount / CHECKLIST_MOCK.items.length) * 100);

  return (
    <div className="space-y-6 max-w-5xl mx-auto h-[calc(100vh-8rem)] flex flex-col">
      {/* Header with Stage Info */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 shrink-0">
        <div>
          <div className="flex items-center gap-2 mb-1">
             <Badge variant="outline" className="text-primary border-primary/20 bg-primary/5">Em Execução</Badge>
             <span className="text-sm text-muted-foreground">Etapa 3 de 6</span>
          </div>
          <h2 className="text-3xl font-display font-bold tracking-tight">{CHECKLIST_MOCK.stageName}</h2>
        </div>
        
        <Card className="min-w-[240px] bg-card/50 backdrop-blur-sm border-border/50">
          <CardContent className="p-4 flex items-center gap-4">
            <div className="relative h-12 w-12 flex items-center justify-center">
              <svg className="h-full w-full -rotate-90" viewBox="0 0 36 36">
                <path className="text-muted/20" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" fill="none" stroke="currentColor" strokeWidth="3" />
                <path className="text-primary" strokeDasharray={`${progress}, 100`} d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" fill="none" stroke="currentColor" strokeWidth="3" />
              </svg>
              <span className="absolute text-xs font-bold">{progress}%</span>
            </div>
            <div>
              <p className="text-sm font-medium">Status da Etapa</p>
              <p className="text-xs text-muted-foreground">{completedCount} de {CHECKLIST_MOCK.items.length} itens verificados</p>
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 flex-1 overflow-hidden min-h-0">
        
        {/* Left Column: Checklist Items */}
        <Card className="lg:col-span-2 border-border/50 bg-card/40 flex flex-col h-full overflow-hidden">
          <CardHeader className="pb-3 border-b border-border/40 shrink-0">
            <div className="flex items-center justify-between">
              <CardTitle>Itens de Verificação</CardTitle>
              <Button size="sm" variant="ghost" className="text-xs">
                Expandir Todos
              </Button>
            </div>
          </CardHeader>
          <ScrollArea className="flex-1">
            <CardContent className="p-0">
              {CHECKLIST_MOCK.items.map((item, index) => (
                <div key={item.id} className="group border-b border-border/40 last:border-0">
                  <div className="flex items-start gap-4 p-4 hover:bg-card/60 transition-colors">
                    <Checkbox id={item.id} checked={item.status === 'checked'} className="mt-1 data-[state=checked]:bg-primary data-[state=checked]:border-primary" />
                    
                    <div className="flex-1 space-y-2">
                      <div className="flex items-center justify-between">
                        <label htmlFor={item.id} className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70 cursor-pointer">
                          {item.question}
                        </label>
                        {item.critical && (
                          <Badge variant="destructive" className="text-[10px] h-5 px-1.5 ml-2">Crítico</Badge>
                        )}
                      </div>
                      
                      <div className="flex items-center gap-2 text-xs text-muted-foreground">
                        <span className="px-2 py-0.5 rounded-full bg-muted/50 border border-border/50">
                          {item.category}
                        </span>
                        {item.aiObservation && (
                          <span className="flex items-center gap-1 text-blue-400">
                            <Info className="h-3 w-3" />
                            Dica IA
                          </span>
                        )}
                      </div>

                      {/* Evidence Section */}
                      <div className="flex items-center gap-3 pt-2">
                         {item.evidence ? (
                           <div className="relative group/img cursor-pointer overflow-hidden rounded-md border border-border">
                             <img src={item.evidence} alt="Evidência" className="h-16 w-16 object-cover transition-transform group-hover/img:scale-110" />
                             <div className="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 group-hover/img:opacity-100 transition-opacity">
                               <CheckCircle2 className="h-6 w-6 text-white" />
                             </div>
                           </div>
                         ) : (
                           <Button variant="outline" size="sm" className="h-8 gap-2 border-dashed border-border text-muted-foreground hover:text-foreground hover:border-primary/50">
                             <Camera className="h-3.5 w-3.5" />
                             Adicionar Foto
                           </Button>
                         )}
                         
                         <Button variant="ghost" size="sm" className="h-8 w-8 p-0 text-muted-foreground hover:text-foreground">
                           <MessageSquare className="h-4 w-4" />
                         </Button>
                      </div>

                      {/* AI Insight Box */}
                      {item.aiObservation && (
                        <div className="mt-2 rounded-lg bg-blue-500/5 border border-blue-500/10 p-3 text-xs text-blue-200/80 flex gap-2">
                          <SparklesIcon className="h-4 w-4 text-blue-400 shrink-0 mt-0.5" />
                          <div>
                            <span className="font-semibold text-blue-400 block mb-0.5">Insight Normativo</span>
                            {item.aiObservation}
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </CardContent>
          </ScrollArea>
        </Card>

        {/* Right Column: Actions & Summary */}
        <div className="space-y-6 shrink-0 lg:h-full lg:overflow-auto">
          {/* Quick Actions */}
          <Card className="border-border/50 bg-card/40">
             <CardHeader>
               <CardTitle className="text-sm font-medium uppercase tracking-wider text-muted-foreground">Ações da Etapa</CardTitle>
             </CardHeader>
             <CardContent className="space-y-3">
               <Button className="w-full bg-primary hover:bg-primary/90 text-white gap-2 h-10">
                 <Upload className="h-4 w-4" />
                 Relatório Diário
               </Button>
               <Button variant="outline" className="w-full gap-2 h-10 border-border/60">
                 <AlertTriangle className="h-4 w-4 text-amber-500" />
                 Reportar Problema
               </Button>
             </CardContent>
          </Card>

          {/* AI Analysis Summary */}
          <Card className="border-primary/20 bg-gradient-to-br from-card/40 to-primary/5">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-primary">
                <SparklesIcon className="h-4 w-4" />
                Análise de Conformidade
              </CardTitle>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground space-y-4">
              <p>
                A IA detectou <span className="text-foreground font-medium">94% de conformidade</span> com base nas evidências enviadas até agora.
              </p>
              <div className="space-y-2">
                <div className="flex justify-between text-xs">
                  <span>Fundação</span>
                  <span className="text-green-500">Aprovado</span>
                </div>
                <Progress value={100} className="h-1 bg-muted" />
                
                <div className="flex justify-between text-xs pt-1">
                  <span>Impermeabilização</span>
                  <span className="text-amber-500">Pendente</span>
                </div>
                <Progress value={40} className="h-1 bg-muted" />
              </div>
              <Button variant="secondary" size="sm" className="w-full text-xs mt-2">
                Ver Relatório Completo
              </Button>
            </CardContent>
          </Card>
        </div>

      </div>
    </div>
  );
}

function SparklesIcon({ className }: { className?: string }) {
  return (
    <svg 
      className={className} 
      xmlns="http://www.w3.org/2000/svg" 
      viewBox="0 0 24 24" 
      fill="currentColor" 
      stroke="none"
    >
      <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456zM16.894 20.567L16.625 21.75l-.269-1.183a2.25 2.25 0 00-1.766-1.766L13.5 18.625l1.09-.176a2.25 2.25 0 001.766-1.766l.269-1.183.269 1.183a2.25 2.25 0 001.766 1.766l1.09.176-1.09.176a2.25 2.25 0 00-1.766 1.766z" />
    </svg>
  )
}
