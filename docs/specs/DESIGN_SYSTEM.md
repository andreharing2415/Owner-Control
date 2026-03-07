# DESIGN_SYSTEM.md

## Visao geral
- Stack: Tailwind v4 + shadcn/ui (style `new-york`) + Radix UI.
- Tokens: CSS variables em `Owner-Control/client/src/index.css`.
- Tema: dark premium forçado por padrao.
- Icones: `lucide`.

## Tipografia
- Texto: `Plus Jakarta Sans`.
- Display: `Outfit`.
- Aplicacao: `body` usa `font-sans`; headings usam `font-display`.

## Cores (tokens principais)
- Fundo: `--background` (base escura).
- Texto: `--foreground`.
- Card: `--card` / `--card-foreground`.
- Primary (CTA): `--primary` / `--primary-foreground`.
- Secondary (premium): `--secondary` / `--secondary-foreground`.
- Muted: `--muted` / `--muted-foreground`.
- Accent (hover): `--accent` / `--accent-foreground`.
- Destructive: `--destructive` / `--destructive-foreground`.
- Bordas/inputs: `--border`, `--input`, `--ring`.

## Sidebar
- `--sidebar`, `--sidebar-foreground`
- `--sidebar-primary`, `--sidebar-primary-foreground`
- `--sidebar-accent`, `--sidebar-accent-foreground`
- `--sidebar-border`, `--sidebar-ring`

## Charts
- `--chart-1` a `--chart-5`

## Raio
- Base: `--radius: 0.5rem`
- Variacoes: `--radius-sm`, `--radius-md`, `--radius-lg`, `--radius-xl`

## Componentes base
- Local: `Owner-Control/client/src/components/ui/*`
- Exemplos em uso: `Owner-Control/client/src/pages/*`

## Convencoes de uso
- Use classes semanticas do design system: `bg-background`, `text-foreground`, `border-border`, `bg-card`, `text-muted-foreground`.
- Para destaque premium: `bg-secondary` + `text-secondary-foreground`.
- Para CTA: `bg-primary` + `text-primary-foreground`.
- Evite cores hardcoded; prefira tokens.

## Layout base (Shell)
- Estrutura: sidebar fixa + header sticky + conteudo scrollavel.
- Referencia: `Owner-Control/client/src/components/layout/Shell.tsx`
- Wrapper: `flex min-h-screen w-full bg-background text-foreground font-sans`.
- Header: `sticky top-0 ... border-b border-border bg-background/80 backdrop-blur-md`.
- Area de conteudo: `p-4 md:p-8 animate-in fade-in duration-500`.

## Containers e espacamento
- Container padrao: `max-w-7xl mx-auto` com `space-y-8`.
- Variacoes por pagina:
- `Dashboard`: `max-w-7xl` (cards e charts).
- `Checklists`: `max-w-5xl`, altura calculada `h-[calc(100vh-8rem)]`.
- `Documents`: `max-w-6xl`.
- `NormsSearch`: `max-w-4xl` e layout centralizado vertical.
- Grids comuns:
- KPI: `grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6`.
- Conteudo principal: `grid grid-cols-1 lg:grid-cols-3 gap-8`.

## Cards e superficies
- Base: `Card` com `border-border/50` e `bg-card/40` a `bg-card/60`.
- Glass/blur: `backdrop-blur-sm` em cards com sobreposicao.
- Hero: gradiente em card grande com `bg-gradient-to-br` e imagem overlay.
- Hover: `hover:border-primary/50` e `transition-all duration-300`.

## Padroes de pagina
- Hero (Dashboard): card grande com imagem de blueprint, badge e CTAs.
- Ref: `Owner-Control/client/src/pages/Dashboard.tsx`.
- KPI Cards: 4 cards pequenos com icone + valor + subtitulo.
- Ref: `Owner-Control/client/src/pages/Dashboard.tsx`.
- Lista de documentos: linhas horizontais em `Card` com icone, metadados e acoes.
- Ref: `Owner-Control/client/src/pages/Documents.tsx`.
- Linha do tempo: eixo vertical central com cards alternados esquerda/direita.
- Ref: `Owner-Control/client/src/pages/Timeline.tsx`.
- Busca normativa: hero central + search pill + resultados em grid 2/1.
- Ref: `Owner-Control/client/src/pages/NormsSearch.tsx`.
- Checklists: duas colunas (itens + acoes/summary) com scroll interno.
- Ref: `Owner-Control/client/src/pages/Checklists.tsx`.

## Botoes (variantes em uso)
- Primary: `bg-primary text-white` + `hover:bg-primary/90`.
- Outline: `variant="outline"` com `border-border/60`.
- Ghost: `variant="ghost"` para acoes sutis em listas.
- Secondary: usado para CTAs secundarios e analises (`variant="secondary"`).

## Badges e status
- Status critico: `bg-red-500/10 text-red-500 border-red-500/20`.
- Warning: `bg-amber-500/10 text-amber-500 border-amber-500/20`.
- OK: `bg-emerald-500/10 text-emerald-500 border-emerald-500/20`.
- Premium: `bg-primary/10 text-primary border-primary/20`.

## Inputs e busca
- Input com icone dentro e padding esquerdo: `pl-10 h-12`.
- Search pill (NormsSearch): `rounded-full`, `shadow-2xl`, `focus-within:border-primary/50`.

## Iconografia
- Biblioteca: `lucide-react`.
- Tamanhos padrao: `h-3.5` a `h-5` para icones inline.

## Snippets (uso padrao)

### Button
```tsx
import { Button } from "@/components/ui/button";

<Button className="bg-primary text-white hover:bg-primary/90">Primary CTA</Button>
<Button variant="outline" className="border-border/60">Outline</Button>
<Button variant="ghost" className="text-muted-foreground hover:text-primary">Ghost</Button>
```

### Card
```tsx
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";

<Card className="border-border/50 bg-card/40">
  <CardHeader>
    <CardTitle>Titulo</CardTitle>
  </CardHeader>
  <CardContent>Conteudo</CardContent>
</Card>
```

### Badge
```tsx
import { Badge } from "@/components/ui/badge";

<Badge className="bg-primary/10 text-primary border-primary/20">Premium</Badge>
<Badge className="bg-emerald-500/10 text-emerald-500 border-emerald-500/20">OK</Badge>
<Badge className="bg-amber-500/10 text-amber-500 border-amber-500/20">Warning</Badge>
<Badge className="bg-red-500/10 text-red-500 border-red-500/20">Critico</Badge>
```

### Input com icone
```tsx
import { Input } from "@/components/ui/input";
import { Search } from "lucide-react";

<div className="relative">
  <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
  <Input className="pl-10 h-12 bg-card/50 border-border/50" placeholder="Buscar..." />
</div>
```

### Progress
```tsx
import { Progress } from "@/components/ui/progress";

<Progress value={65} className="h-2" />
```

## Do / Dont

### Do
- Use tokens (`bg-background`, `text-foreground`, `border-border`).
- Reutilize `Card`, `Badge`, `Button` e `Progress` para consistencia.
- Mantenha `max-w-*` e `space-y-*` conforme os padroes de pagina.
- Use `backdrop-blur` apenas em superficies de destaque.

### Dont
- Nao usar cores hardcoded em fundos/textos principais.
- Nao criar novos estilos de botao fora das variantes existentes.
- Nao quebrar o layout base do `Shell` (sidebar + header sticky).
- Nao misturar tipografias fora de `Plus Jakarta Sans` e `Outfit`.

## Arquivos-chave
- Tokens e tema: `Owner-Control/client/src/index.css`
- Config do shadcn: `Owner-Control/components.json`
- Fontes: `Owner-Control/client/index.html`

## Snippets de layout

### KPI grid (Dashboard)
```tsx
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
  <Card className="border-border/50 bg-card/50">
    <CardContent className="p-6">
      <div className="flex items-center justify-between">
        <p className="text-sm font-medium text-muted-foreground">Titulo</p>
        <Icon className="h-4 w-4 text-muted-foreground" />
      </div>
      <div className="mt-2 text-2xl font-display font-bold">123</div>
      <p className="text-xs text-muted-foreground">Subtexto</p>
    </CardContent>
  </Card>
</div>
```

### Linha do tempo (Timeline)
```tsx
<div className="relative space-y-8 before:absolute before:inset-0 before:ml-5 before:-translate-x-px md:before:mx-auto md:before:translate-x-0 before:h-full before:w-0.5 before:bg-gradient-to-b before:from-transparent before:via-border before:to-transparent">
  <div className="relative flex items-center justify-between md:justify-normal md:odd:flex-row-reverse">
    <div className="absolute left-0 md:left-1/2 flex items-center justify-center w-10 h-10 rounded-full border-4 border-background shadow md:-translate-x-1/2" />
    <div className="w-[calc(100%-3.5rem)] md:w-[calc(50%-2.5rem)] ml-14 md:ml-0">
      <Card className="border-border/60 bg-card/40">
        <CardHeader className="pb-2">
          <CardTitle className="text-lg font-bold">Etapa</CardTitle>
          <CardDescription>Descricao</CardDescription>
        </CardHeader>
        <CardContent>Conteudo</CardContent>
      </Card>
    </div>
  </div>
</div>
```

### Lista de documentos
```tsx
<Card className="border-border/50 bg-card/40 hover:bg-card/60 transition-all">
  <CardContent className="p-4 flex items-center gap-4">
    <div className="h-12 w-12 rounded-lg bg-muted/50" />
    <div className="flex-1 min-w-0">
      <h3 className="font-semibold truncate">Arquivo.pdf</h3>
      <div className="text-xs text-muted-foreground">Arquitetura • 12.4 MB</div>
    </div>
    <Button variant="ghost" size="icon" className="h-8 w-8">...</Button>
  </CardContent>
</Card>
```

### Checklists (duas colunas)
```tsx
<div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
  <Card className="lg:col-span-2 border-border/50 bg-card/40" />
  <div className="space-y-6">
    <Card className="border-border/50 bg-card/40" />
    <Card className="border-primary/20 bg-gradient-to-br from-card/40 to-primary/5" />
  </div>
</div>
```

## Checklist de consistencia visual
- Layout dentro do `Shell` (sidebar + header sticky).
- Containers com `max-w-*` e `space-y-*` padronizados.
- Cards com `bg-card/40` a `bg-card/60` e `border-border/50`.
- CTAs em `bg-primary` e secundarias em `variant=outline` ou `secondary`.
- Badges com cores semanticas e opacidades 10%.
- Inputs com `bg-card/50` e `border-border/50`.
- Icones `lucide-react` com tamanhos coerentes (`h-4` padrao).
- Sem cores hardcoded em superficies principais.
