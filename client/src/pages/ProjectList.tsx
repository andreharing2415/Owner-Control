import { PROJECT_MOCK } from "@/lib/mock-data";
import { Card, CardContent, CardFooter, CardHeader } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { MapPin, Calendar, ArrowRight, Plus } from "lucide-react";

export default function ProjectList() {
  return (
    <div className="space-y-8 max-w-7xl mx-auto">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-display font-bold tracking-tight">Minhas Obras</h2>
          <p className="text-muted-foreground mt-1">Gerencie seus empreendimentos ativos</p>
        </div>
        <Button className="bg-primary hover:bg-primary/90 text-white gap-2">
          <Plus className="h-4 w-4" /> Nova Obra
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {/* Active Project Card */}
        <Card className="group overflow-hidden border-border/50 bg-card/50 hover:border-primary/50 transition-all duration-300 shadow-lg hover:shadow-xl hover:shadow-primary/5">
          <div className="relative h-48 overflow-hidden">
            <div className="absolute top-4 left-4 z-10">
              <Badge className="bg-primary/90 text-white backdrop-blur-md border-0">Em Andamento</Badge>
            </div>
            <div className="absolute inset-0 bg-gradient-to-t from-background/90 to-transparent z-0" />
            <img 
              src={PROJECT_MOCK.image} 
              alt={PROJECT_MOCK.name}
              className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105"
            />
          </div>
          <CardHeader className="relative -mt-12 z-10 px-6 pb-2">
            <h3 className="text-xl font-display font-bold text-white group-hover:text-primary transition-colors">
              {PROJECT_MOCK.name}
            </h3>
            <div className="flex items-center text-sm text-muted-foreground gap-1">
              <MapPin className="h-3.5 w-3.5" />
              {PROJECT_MOCK.address}
            </div>
          </CardHeader>
          <CardContent className="px-6 py-4 space-y-4">
            <div className="space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Progresso Físico</span>
                <span className="font-medium">{PROJECT_MOCK.progress}%</span>
              </div>
              <Progress value={PROJECT_MOCK.progress} className="h-2" />
            </div>
            
            <div className="grid grid-cols-2 gap-4 pt-2">
              <div className="space-y-1">
                <span className="text-xs text-muted-foreground uppercase tracking-wider">Próx. Marco</span>
                <p className="text-sm font-medium line-clamp-1">{PROJECT_MOCK.nextMilestone}</p>
              </div>
              <div className="space-y-1">
                <span className="text-xs text-muted-foreground uppercase tracking-wider">Qualidade</span>
                <p className="text-sm font-medium text-green-500">{PROJECT_MOCK.qualityScore}/100 (A)</p>
              </div>
            </div>
          </CardContent>
          <CardFooter className="px-6 py-4 border-t border-border bg-muted/20">
            <Button variant="ghost" className="w-full justify-between group-hover:text-primary hover:bg-transparent px-0">
              Gerenciar Obra <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-1" />
            </Button>
          </CardFooter>
        </Card>

        {/* Placeholder for New Project */}
        <button className="flex flex-col items-center justify-center h-full min-h-[400px] rounded-xl border border-dashed border-border bg-card/20 hover:bg-card/40 hover:border-primary/50 transition-all gap-4 group">
          <div className="h-16 w-16 rounded-full bg-muted flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
            <Plus className="h-8 w-8 text-muted-foreground group-hover:text-primary" />
          </div>
          <div className="text-center">
            <h3 className="text-lg font-medium">Cadastrar Nova Obra</h3>
            <p className="text-sm text-muted-foreground mt-1 max-w-[200px]">
              Inicie o monitoramento de um novo empreendimento
            </p>
          </div>
        </button>
      </div>
    </div>
  );
}
