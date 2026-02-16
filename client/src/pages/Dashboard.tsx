import { PROJECT_MOCK, ALERTS_MOCK } from "@/lib/mock-data";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { ArrowRight, TrendingUp, AlertTriangle, CheckCircle2, DollarSign } from "lucide-react";
import { Area, AreaChart, CartesianGrid, XAxis, ResponsiveContainer, Tooltip } from "recharts";

const data = [
  { name: 'Jan', plan: 10, actual: 10 },
  { name: 'Fev', plan: 25, actual: 22 },
  { name: 'Mar', plan: 40, actual: 35 },
  { name: 'Abr', plan: 55, actual: 48 },
  { name: 'Mai', plan: 70, actual: 65 },
  { name: 'Jun', plan: 85, actual: 78 },
  { name: 'Jul', plan: 100, actual: null },
];

export default function Dashboard() {
  return (
    <div className="space-y-8 max-w-7xl mx-auto">
      {/* Hero Section */}
      <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-sidebar-accent to-background border border-border p-8 md:p-12">
        <div className="absolute top-0 right-0 w-1/2 h-full opacity-10 pointer-events-none">
           <img src="/images/blueprint-abstract.png" alt="Blueprint" className="w-full h-full object-cover mix-blend-overlay" />
        </div>
        
        <div className="relative z-10 space-y-4 max-w-2xl">
          <div className="inline-flex items-center rounded-full border border-primary/20 bg-primary/10 px-3 py-1 text-xs font-medium text-primary">
            <span className="flex h-2 w-2 rounded-full bg-primary mr-2 animate-pulse"></span>
            Obra em Andamento
          </div>
          <h2 className="text-3xl md:text-4xl font-display font-bold tracking-tight text-white">
            {PROJECT_MOCK.name}
          </h2>
          <p className="text-muted-foreground text-lg">
            Etapa Atual: <span className="text-foreground font-medium">{PROJECT_MOCK.nextMilestone}</span>
          </p>
          <div className="flex gap-4 pt-4">
            <Button size="lg" className="bg-primary hover:bg-primary/90 text-white font-medium">
              Ver Detalhes
            </Button>
            <Button size="lg" variant="outline" className="bg-transparent border-white/10 hover:bg-white/5 hover:text-white">
              Diário de Obra
            </Button>
          </div>
        </div>
      </div>

      {/* KPI Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <KpiCard 
          title="Progresso Físico" 
          value={`${PROJECT_MOCK.progress}%`} 
          subtext="+2% esta semana" 
          icon={TrendingUp}
          trend="up"
        />
        <KpiCard 
          title="Score de Qualidade" 
          value={PROJECT_MOCK.qualityScore} 
          subtext="Excelente" 
          icon={CheckCircle2}
          trend="neutral"
          color="text-green-500"
        />
        <KpiCard 
          title="Executado vs Orçado" 
          value="R$ 850k" 
          subtext="34% do total" 
          icon={DollarSign}
          trend="down"
        />
        <KpiCard 
          title="Alertas Ativos" 
          value={ALERTS_MOCK.length} 
          subtext="1 Crítico" 
          icon={AlertTriangle}
          trend="warning"
          color="text-amber-500"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Main Chart */}
        <Card className="lg:col-span-2 border-border/50 bg-card/50 backdrop-blur-sm">
          <CardHeader>
            <CardTitle>Curva S: Planejado vs Realizado</CardTitle>
            <CardDescription>Acompanhamento acumulado do progresso físico</CardDescription>
          </CardHeader>
          <CardContent className="h-[300px]">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={data}>
                <defs>
                  <linearGradient id="colorPlan" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="hsl(var(--muted-foreground))" stopOpacity={0.1}/>
                    <stop offset="95%" stopColor="hsl(var(--muted-foreground))" stopOpacity={0}/>
                  </linearGradient>
                  <linearGradient id="colorActual" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="hsl(var(--primary))" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="hsl(var(--primary))" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{fill: 'hsl(var(--muted-foreground))'}} />
                <Tooltip 
                  contentStyle={{ backgroundColor: 'hsl(var(--card))', borderColor: 'hsl(var(--border))', borderRadius: '8px' }}
                  itemStyle={{ color: 'hsl(var(--foreground))' }}
                />
                <Area type="monotone" dataKey="plan" stroke="hsl(var(--muted-foreground))" strokeDasharray="5 5" fillOpacity={1} fill="url(#colorPlan)" name="Planejado" />
                <Area type="monotone" dataKey="actual" stroke="hsl(var(--primary))" strokeWidth={3} fillOpacity={1} fill="url(#colorActual)" name="Realizado" />
              </AreaChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Alerts Feed */}
        <Card className="border-border/50 bg-card/50 backdrop-blur-sm">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-lg font-medium">Alertas Recentes</CardTitle>
            <Badge variant="outline" className="text-xs font-normal">Hoje</Badge>
          </CardHeader>
          <CardContent className="space-y-4 pt-4">
            {ALERTS_MOCK.map((alert) => (
              <div key={alert.id} className="flex gap-4 items-start group">
                <div className={`mt-1 p-1.5 rounded-full ${
                  alert.severity === 'high' ? 'bg-red-500/10 text-red-500' : 
                  alert.severity === 'medium' ? 'bg-amber-500/10 text-amber-500' : 
                  'bg-blue-500/10 text-blue-500'
                }`}>
                  <AlertTriangle className="h-4 w-4" />
                </div>
                <div className="space-y-1">
                  <p className="text-sm font-medium leading-none group-hover:text-primary transition-colors">
                    {alert.title}
                  </p>
                  <p className="text-xs text-muted-foreground line-clamp-2">
                    {alert.description}
                  </p>
                  <p className="text-[10px] text-muted-foreground/60 pt-1 uppercase tracking-wider">
                    {alert.date}
                  </p>
                </div>
              </div>
            ))}
            <Button variant="ghost" className="w-full text-xs text-muted-foreground mt-2 hover:text-primary">
              Ver Todos os Alertas <ArrowRight className="ml-2 h-3 w-3" />
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function KpiCard({ title, value, subtext, icon: Icon, trend, color }: any) {
  return (
    <Card className="border-border/50 bg-card/50 backdrop-blur-sm hover:border-primary/50 transition-colors duration-300">
      <CardContent className="p-6">
        <div className="flex items-center justify-between space-y-0 pb-2">
          <p className="text-sm font-medium text-muted-foreground">{title}</p>
          <Icon className={`h-4 w-4 ${color || "text-muted-foreground"}`} />
        </div>
        <div className="flex flex-col gap-1 mt-2">
          <div className="text-2xl font-display font-bold">{value}</div>
          <p className="text-xs text-muted-foreground flex items-center gap-1">
            {trend === 'up' && <TrendingUp className="h-3 w-3 text-green-500" />}
            {trend === 'down' && <TrendingUp className="h-3 w-3 text-red-500 rotate-180" />}
            {subtext}
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
