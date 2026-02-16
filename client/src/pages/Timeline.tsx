import { TIMELINE_MOCK } from "@/lib/mock-data";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { CheckCircle2, Clock, Calendar, AlertCircle, ChevronRight, DollarSign } from "lucide-react";
import { cn } from "@/lib/utils";

export default function Timeline() {
  return (
    <div className="space-y-8 max-w-5xl mx-auto">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-3xl font-display font-bold tracking-tight">Cronograma Físico-Financeiro</h2>
          <p className="text-muted-foreground mt-1">Acompanhe o avanço das etapas e o desembolso financeiro</p>
        </div>
        <div className="flex gap-2">
           <Button variant="outline" size="sm">
             <Calendar className="mr-2 h-4 w-4" /> Exportar PDF
           </Button>
           <Button size="sm" className="bg-primary text-white">
             Atualizar Status
           </Button>
        </div>
      </div>

      <div className="relative space-y-8 before:absolute before:inset-0 before:ml-5 before:-translate-x-px md:before:mx-auto md:before:translate-x-0 before:h-full before:w-0.5 before:bg-gradient-to-b before:from-transparent before:via-border before:to-transparent">
        {TIMELINE_MOCK.map((stage, index) => {
          const isLeft = index % 2 === 0;
          
          return (
            <div key={stage.id} className={cn(
              "relative flex items-center justify-between md:justify-normal md:odd:flex-row-reverse group",
              isLeft ? "md:flex-row-reverse" : ""
            )}>
              
              {/* Timeline Dot */}
              <div className={cn(
                "absolute left-0 md:left-1/2 flex items-center justify-center w-10 h-10 rounded-full border-4 border-background shadow shrink-0 md:-translate-x-1/2 z-10 transition-colors duration-500",
                stage.status === 'completed' ? "bg-emerald-500 border-emerald-500/20" :
                stage.status === 'in-progress' ? "bg-primary border-primary/20 animate-pulse" :
                stage.status === 'delayed' ? "bg-red-500 border-red-500/20" :
                "bg-muted border-border"
              )}>
                {stage.status === 'completed' ? <CheckCircle2 className="w-5 h-5 text-white" /> :
                 stage.status === 'in-progress' ? <Clock className="w-5 h-5 text-white" /> :
                 stage.status === 'delayed' ? <AlertCircle className="w-5 h-5 text-white" /> :
                 <div className="w-3 h-3 rounded-full bg-muted-foreground/50" />}
              </div>

              {/* Card Content */}
              <div className={cn(
                "w-[calc(100%-3.5rem)] md:w-[calc(50%-2.5rem)] ml-14 md:ml-0",
                // !isLeft ? "md:mr-auto" : "md:ml-auto" // Corrected alignment logic below
              )}>
                 <Card className={cn(
                   "transition-all duration-300 hover:shadow-lg border-border/60",
                   stage.status === 'in-progress' ? "border-primary/50 bg-primary/5 shadow-md shadow-primary/5" : "bg-card/40"
                 )}>
                   <CardHeader className="pb-2">
                     <div className="flex justify-between items-start">
                       <Badge variant="outline" className={cn(
                         "mb-2",
                         stage.status === 'completed' ? "text-emerald-500 border-emerald-500/20 bg-emerald-500/10" :
                         stage.status === 'in-progress' ? "text-primary border-primary/20 bg-primary/10" :
                         stage.status === 'delayed' ? "text-red-500 border-red-500/20 bg-red-500/10" :
                         "text-muted-foreground"
                       )}>
                         {stage.date}
                       </Badge>
                       {stage.status === 'in-progress' && (
                         <span className="text-[10px] font-bold text-primary animate-pulse uppercase tracking-wider">Em Execução</span>
                       )}
                     </div>
                     <CardTitle className="text-lg font-bold">{stage.title}</CardTitle>
                     <CardDescription className="line-clamp-2">{stage.description}</CardDescription>
                   </CardHeader>
                   <CardContent className="space-y-4">
                     {/* Progress Bar */}
                     <div className="space-y-1.5">
                       <div className="flex justify-between text-xs text-muted-foreground">
                         <span>Conclusão Física</span>
                         <span className="font-medium text-foreground">{stage.progress}%</span>
                       </div>
                       <Progress value={stage.progress} className="h-1.5" />
                     </div>

                     {/* Financial Mini-Table */}
                     <div className="bg-muted/30 rounded-lg p-3 text-xs space-y-2 border border-border/50">
                       <div className="flex items-center gap-2 font-medium text-muted-foreground mb-2">
                         <DollarSign className="w-3.5 h-3.5" />
                         <span>Controle Orçamentário</span>
                       </div>
                       <div className="flex justify-between">
                         <span className="text-muted-foreground">Planejado</span>
                         <span>R$ {stage.budget.planejado.toLocaleString('pt-BR')}</span>
                       </div>
                       <div className="flex justify-between">
                         <span className="text-muted-foreground">Realizado</span>
                         <span className={cn(
                           stage.budget.realizado > stage.budget.planejado ? "text-red-500 font-bold" : "text-emerald-500 font-medium"
                         )}>
                           R$ {stage.budget.realizado.toLocaleString('pt-BR')}
                         </span>
                       </div>
                     </div>

                     {stage.status === 'in-progress' && (
                       <Button size="sm" className="w-full mt-2" variant="secondary">
                         Ver Checklist da Etapa <ChevronRight className="w-4 h-4 ml-1" />
                       </Button>
                     )}
                   </CardContent>
                 </Card>
              </div>

            </div>
          );
        })}
      </div>
    </div>
  );
}
