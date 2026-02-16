import { FINANCIAL_MOCK } from "@/lib/mock-data";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { Separator } from "@/components/ui/separator";
import { DollarSign, TrendingUp, AlertTriangle, Download, PieChart, ArrowUpRight, ArrowDownRight } from "lucide-react";
import { Bar, BarChart, CartesianGrid, XAxis, YAxis, Tooltip, ResponsiveContainer, Line, ComposedChart, Legend, Area } from "recharts";

export default function Financial() {
  const deviation = FINANCIAL_MOCK.projectedCost - FINANCIAL_MOCK.totalBudget;
  const deviationPercent = (deviation / FINANCIAL_MOCK.totalBudget) * 100;

  return (
    <div className="space-y-8 max-w-7xl mx-auto">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-3xl font-display font-bold tracking-tight">Governança Financeira</h2>
          <p className="text-muted-foreground mt-1">Controle de orçamento e fluxo de caixa</p>
        </div>
        <div className="flex gap-2">
           <Button variant="outline" className="gap-2">
             <Download className="h-4 w-4" /> Relatório Executivo
           </Button>
           <Button className="bg-primary text-white">
             Novo Pagamento
           </Button>
        </div>
      </div>

      {/* Top Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card className="bg-card/40 border-border/50">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium text-muted-foreground">Orçamento Total</span>
              <DollarSign className="h-4 w-4 text-muted-foreground" />
            </div>
            <div className="mt-2 flex items-baseline gap-2">
              <span className="text-2xl font-bold">
                R$ {FINANCIAL_MOCK.totalBudget.toLocaleString('pt-BR')}
              </span>
            </div>
            <Progress value={100} className="h-1 mt-4 bg-muted" />
          </CardContent>
        </Card>

        <Card className="bg-card/40 border-border/50">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium text-muted-foreground">Realizado (Pago)</span>
              <TrendingUp className="h-4 w-4 text-primary" />
            </div>
            <div className="mt-2 flex items-baseline gap-2">
              <span className="text-2xl font-bold text-primary">
                R$ {FINANCIAL_MOCK.totalSpent.toLocaleString('pt-BR')}
              </span>
              <span className="text-xs text-muted-foreground">
                ({Math.round((FINANCIAL_MOCK.totalSpent / FINANCIAL_MOCK.totalBudget) * 100)}%)
              </span>
            </div>
            <Progress value={(FINANCIAL_MOCK.totalSpent / FINANCIAL_MOCK.totalBudget) * 100} className="h-1 mt-4" />
          </CardContent>
        </Card>

        <Card className="bg-card/40 border-border/50">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium text-muted-foreground">Projeção Final</span>
              <AlertTriangle className={deviation > 0 ? "h-4 w-4 text-amber-500" : "h-4 w-4 text-emerald-500"} />
            </div>
            <div className="mt-2 flex items-baseline gap-2">
              <span className={`text-2xl font-bold ${deviation > 0 ? "text-amber-500" : "text-emerald-500"}`}>
                R$ {FINANCIAL_MOCK.projectedCost.toLocaleString('pt-BR')}
              </span>
            </div>
            <div className="flex items-center gap-1 mt-4 text-xs font-medium">
              {deviation > 0 ? (
                <span className="text-amber-500 flex items-center gap-1">
                  <ArrowUpRight className="h-3 w-3" /> 
                  +{deviationPercent.toFixed(1)}% acima do orçamento
                </span>
              ) : (
                <span className="text-emerald-500 flex items-center gap-1">
                  <ArrowDownRight className="h-3 w-3" /> 
                  Dentro do previsto
                </span>
              )}
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Main Chart: Financial Evolution */}
        <Card className="lg:col-span-2 border-border/50 bg-card/40">
          <CardHeader>
            <CardTitle>Evolução Financeira (Acumulado)</CardTitle>
            <CardDescription>Comparativo Previsto vs. Realizado ao longo do tempo</CardDescription>
          </CardHeader>
          <CardContent className="h-[350px]">
            <ResponsiveContainer width="100%" height="100%">
              <ComposedChart data={FINANCIAL_MOCK.monthlyData}>
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
                <XAxis dataKey="month" axisLine={false} tickLine={false} tick={{fill: 'hsl(var(--muted-foreground))'}} />
                <YAxis 
                  axisLine={false} 
                  tickLine={false} 
                  tick={{fill: 'hsl(var(--muted-foreground))'}} 
                  tickFormatter={(value) => `R$${value/1000}k`}
                />
                <Tooltip 
                  contentStyle={{ backgroundColor: 'hsl(var(--card))', borderColor: 'hsl(var(--border))', borderRadius: '8px' }}
                  itemStyle={{ color: 'hsl(var(--foreground))' }}
                  formatter={(value: number) => `R$ ${value.toLocaleString('pt-BR')}`}
                />
                <Legend />
                <Area type="monotone" dataKey="accumulatedPlan" name="Previsto Acumulado" stroke="hsl(var(--muted-foreground))" fill="url(#colorPlan)" />
                <Area type="monotone" dataKey="accumulatedActual" name="Realizado Acumulado" stroke="hsl(var(--primary))" strokeWidth={3} fill="url(#colorActual)" />
              </ComposedChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Budget Breakdown */}
        <Card className="border-border/50 bg-card/40">
          <CardHeader>
            <CardTitle>Detalhamento por Categoria</CardTitle>
            <CardDescription>Distribuição dos gastos atuais</CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            {FINANCIAL_MOCK.categories.map((cat, idx) => (
              <div key={idx} className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="font-medium">{cat.name}</span>
                  <span className={
                    cat.status === 'warning' ? "text-amber-500 font-bold" : 
                    cat.status === 'completed' ? "text-emerald-500" : 
                    "text-muted-foreground"
                  }>
                    {Math.round((cat.spent / cat.planned) * 100)}%
                  </span>
                </div>
                <Progress 
                  value={(cat.spent / cat.planned) * 100} 
                  className={`h-2 ${
                    cat.status === 'warning' ? "bg-amber-500/20 [&>div]:bg-amber-500" : 
                    cat.status === 'completed' ? "bg-emerald-500/20 [&>div]:bg-emerald-500" : 
                    ""
                  }`} 
                />
                <div className="flex justify-between text-xs text-muted-foreground">
                  <span>Gasto: R$ {cat.spent.toLocaleString('pt-BR')}</span>
                  <span>Meta: R$ {cat.planned.toLocaleString('pt-BR')}</span>
                </div>
              </div>
            ))}
            
            <Separator className="my-4" />
            
            <div className="rounded-lg bg-amber-500/10 p-4 border border-amber-500/20">
              <div className="flex gap-3">
                <AlertTriangle className="h-5 w-5 text-amber-500 shrink-0" />
                <div className="space-y-1">
                  <h4 className="text-sm font-semibold text-amber-500">Alerta de Desvio</h4>
                  <p className="text-xs text-amber-200/80">
                    A categoria <span className="font-medium text-amber-500">Materiais</span> está com consumo 15% acima do planejado devido ao aumento no preço do aço (Cimento Portland III).
                  </p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
