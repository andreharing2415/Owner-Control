import { Button } from "@/components/ui/button";
import { Link } from "wouter";
import { CheckCircle2, ArrowRight, ShieldCheck, Search, FileText, Smartphone, Menu, X } from "lucide-react";
import { useState } from "react";
import { cn } from "@/lib/utils";

export default function Landing() {
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  return (
    <div className="min-h-screen bg-background text-foreground overflow-x-hidden font-sans selection:bg-primary/30">
      
      {/* Navigation */}
      <nav className="fixed top-0 left-0 right-0 z-50 border-b border-white/5 bg-background/80 backdrop-blur-md">
        <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-2 font-display font-bold text-xl tracking-tighter">
            <div className="h-8 w-8 rounded-lg bg-primary flex items-center justify-center text-primary-foreground">
              OC
            </div>
            <span>OwnerControl</span>
          </div>

          {/* Desktop Nav */}
          <div className="hidden md:flex items-center gap-8 text-sm font-medium text-muted-foreground">
            <a href="#features" className="hover:text-foreground transition-colors">Funcionalidades</a>
            <a href="#how-it-works" className="hover:text-foreground transition-colors">Como Funciona</a>
            <a href="#pricing" className="hover:text-foreground transition-colors">Planos</a>
            <Button asChild variant="ghost" className="text-foreground hover:bg-white/5">
              <Link href="/app">Login</Link>
            </Button>
            <Button asChild className="bg-primary hover:bg-primary/90 text-white rounded-full px-6">
              <Link href="/app">Começar Agora</Link>
            </Button>
          </div>

          {/* Mobile Menu Toggle */}
          <button className="md:hidden p-2 text-foreground" onClick={() => setIsMenuOpen(!isMenuOpen)}>
            {isMenuOpen ? <X /> : <Menu />}
          </button>
        </div>

        {/* Mobile Nav Overlay */}
        {isMenuOpen && (
          <div className="md:hidden absolute top-16 left-0 right-0 bg-background border-b border-border p-6 flex flex-col gap-4 animate-in slide-in-from-top-5">
            <a href="#features" className="text-lg font-medium" onClick={() => setIsMenuOpen(false)}>Funcionalidades</a>
            <a href="#how-it-works" className="text-lg font-medium" onClick={() => setIsMenuOpen(false)}>Como Funciona</a>
            <Link href="/app" onClick={() => setIsMenuOpen(false)}>
              <Button className="w-full mt-4 bg-primary text-white">Acessar Plataforma</Button>
            </Link>
          </div>
        )}
      </nav>

      {/* Hero Section */}
      <section className="relative pt-32 pb-20 md:pt-48 md:pb-32 px-6 overflow-hidden">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[1000px] h-[500px] bg-primary/20 rounded-full blur-[120px] -z-10 opacity-50 pointer-events-none" />
        
        <div className="max-w-5xl mx-auto text-center space-y-8">
          <div className="inline-flex items-center rounded-full border border-primary/20 bg-primary/10 px-3 py-1 text-sm font-medium text-primary animate-in fade-in slide-in-from-bottom-4 duration-700">
            <span className="flex h-2 w-2 rounded-full bg-primary mr-2 animate-pulse"></span>
            Governança para Obras de Alto Padrão
          </div>
          
          <h1 className="text-5xl md:text-7xl font-display font-bold tracking-tight leading-[1.1] animate-in fade-in slide-in-from-bottom-8 duration-700 delay-100">
            Sua obra sob controle.<br />
            <span className="bg-gradient-to-r from-white to-white/50 bg-clip-text text-transparent">Sem ser engenheiro.</span>
          </h1>
          
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto leading-relaxed animate-in fade-in slide-in-from-bottom-8 duration-700 delay-200">
            Valide a qualidade técnica, controle o orçamento e antecipe riscos normativos com a primeira IA treinada nas normas NBR brasileiras.
          </p>
          
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4 pt-4 animate-in fade-in slide-in-from-bottom-8 duration-700 delay-300">
            <Button asChild size="lg" className="h-14 px-8 rounded-full text-lg bg-white text-background hover:bg-white/90 hover:scale-105 transition-all w-full sm:w-auto">
              <Link href="/app">
                Acessar Demonstração <ArrowRight className="ml-2 h-5 w-5" />
              </Link>
            </Button>
            <Button variant="outline" size="lg" className="h-14 px-8 rounded-full text-lg border-white/10 hover:bg-white/5 w-full sm:w-auto">
              Falar com Consultor
            </Button>
          </div>

          {/* Hero Image / Mockup */}
          <div className="mt-16 relative mx-auto max-w-5xl rounded-2xl border border-white/10 shadow-2xl overflow-hidden animate-in fade-in zoom-in duration-1000 delay-500">
            <div className="absolute inset-0 bg-gradient-to-t from-background via-transparent to-transparent z-10" />
            <img 
              src="/images/project-luxury-villa.png" 
              alt="Dashboard Preview" 
              className="w-full h-auto object-cover opacity-80"
            />
            {/* Floating Cards simulating the app interface */}
            <div className="absolute bottom-[-20px] left-1/2 -translate-x-1/2 z-20 w-[90%] md:w-[80%] h-[300px] bg-background/80 backdrop-blur-xl border border-white/10 rounded-t-2xl p-6 shadow-[0_-20px_40px_-15px_rgba(0,0,0,0.5)]">
               <div className="flex items-center justify-between border-b border-white/10 pb-4 mb-4">
                 <div className="flex gap-2">
                   <div className="w-3 h-3 rounded-full bg-red-500/50" />
                   <div className="w-3 h-3 rounded-full bg-amber-500/50" />
                   <div className="w-3 h-3 rounded-full bg-green-500/50" />
                 </div>
                 <div className="text-xs font-mono text-muted-foreground">ownercontrol_app.exe</div>
               </div>
               <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                 <div className="space-y-2">
                   <div className="h-20 bg-primary/10 rounded-lg border border-primary/20 p-4">
                     <div className="text-xs text-primary mb-1">Status da Obra</div>
                     <div className="text-xl font-bold">Em Andamento</div>
                   </div>
                   <div className="h-20 bg-white/5 rounded-lg border border-white/10 p-4">
                     <div className="text-xs text-muted-foreground mb-1">Orçamento</div>
                     <div className="text-xl font-bold">R$ 2.5M</div>
                   </div>
                 </div>
                 <div className="hidden md:block col-span-2 bg-white/5 rounded-lg border border-white/10 p-4">
                   <div className="flex items-center gap-2 mb-4">
                     <Search className="w-4 h-4 text-primary" />
                     <div className="text-sm text-muted-foreground">Busca Normativa IA...</div>
                   </div>
                   <div className="space-y-2">
                     <div className="h-2 w-3/4 bg-white/10 rounded" />
                     <div className="h-2 w-1/2 bg-white/10 rounded" />
                     <div className="h-2 w-full bg-white/10 rounded" />
                   </div>
                 </div>
               </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Grid */}
      <section id="features" className="py-24 px-6 bg-muted/5">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-4xl font-display font-bold mb-4">Tudo o que você precisa para governar sua obra</h2>
            <p className="text-muted-foreground max-w-2xl mx-auto">
              Substitua planilhas complexas e grupos de WhatsApp por uma plataforma centralizada de inteligência.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <FeatureCard 
              icon={Search}
              title="IA Normativa"
              description="Esqueça a busca manual em PDFs. Nossa IA varre as normas NBR e entrega a resposta técnica traduzida para você."
            />
            <FeatureCard 
              icon={FileText}
              title="Análise de Projetos"
              description="Upload de plantas e memoriais. O sistema cruza as informações e aponta riscos de incompatibilidade antes da obra começar."
            />
            <FeatureCard 
              icon={ShieldCheck}
              title="Checklists Inteligentes"
              description="Validadores passo-a-passo para cada etapa da obra, gerados automaticamente com base no tipo do seu projeto."
            />
            <FeatureCard 
              icon={Smartphone}
              title="Mobile First"
              description="Acompanhe tudo pelo celular. Tire fotos, aprove pagamentos e receba alertas onde estiver."
            />
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-24 px-6 text-center">
        <div className="max-w-4xl mx-auto bg-gradient-to-br from-primary/20 to-secondary/20 rounded-3xl p-12 border border-white/10 relative overflow-hidden">
          <div className="relative z-10 space-y-6">
            <h2 className="text-3xl md:text-5xl font-display font-bold">Pronto para assumir o controle?</h2>
            <p className="text-lg text-muted-foreground max-w-xl mx-auto">
              Junte-se a centenas de proprietários que estão construindo com mais segurança, economia e tranquilidade.
            </p>
            <Button asChild size="lg" className="h-14 px-8 rounded-full text-lg bg-primary text-white hover:bg-primary/90 mt-4">
              <Link href="/app">Começar Agora Gratuitamente</Link>
            </Button>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-12 px-6 border-t border-white/5 bg-background">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-6">
          <div className="flex items-center gap-2 font-display font-bold text-xl">
            <div className="h-6 w-6 rounded bg-primary/20 flex items-center justify-center text-primary text-xs">OC</div>
            <span>OwnerControl</span>
          </div>
          <div className="text-sm text-muted-foreground">
            © 2026 OwnerControl. Todos os direitos reservados.
          </div>
          <div className="flex gap-6 text-sm text-muted-foreground">
            <a href="#" className="hover:text-foreground">Termos</a>
            <a href="#" className="hover:text-foreground">Privacidade</a>
            <a href="#" className="hover:text-foreground">Contato</a>
          </div>
        </div>
      </footer>
    </div>
  );
}

function FeatureCard({ icon: Icon, title, description }: any) {
  return (
    <div className="p-8 rounded-2xl bg-card border border-border/50 hover:border-primary/50 transition-colors group">
      <div className="h-12 w-12 rounded-lg bg-primary/10 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300">
        <Icon className="h-6 w-6 text-primary" />
      </div>
      <h3 className="text-xl font-bold mb-3">{title}</h3>
      <p className="text-muted-foreground leading-relaxed">
        {description}
      </p>
    </div>
  );
}
