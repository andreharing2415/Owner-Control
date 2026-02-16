import { 
  Building2, 
  Calendar, 
  CheckSquare, 
  FileText, 
  Home, 
  LayoutDashboard, 
  Search, 
  Settings, 
  AlertTriangle,
  TrendingUp,
  DollarSign,
  Activity
} from "lucide-react";

export const PROJECT_MOCK = {
  id: "1",
  name: "Residencial Alphaville Zero",
  address: "Al. Mamoré, 123 - Barueri/SP",
  image: "/images/project-luxury-villa.png",
  status: "active",
  progress: 32,
  budget: {
    total: 2500000,
    spent: 850000,
    currency: "BRL"
  },
  nextMilestone: "Concretagem Laje 1º Pavimento",
  lastUpdate: "Há 2 horas",
  qualityScore: 94
};

export const ALERTS_MOCK = [
  {
    id: 1,
    severity: "high",
    title: "Norma NBR 6118 Atualizada",
    description: "Detectamos uma revisão na norma de estruturas de concreto que impacta sua obra.",
    date: "Hoje, 09:30"
  },
  {
    id: 2,
    severity: "medium",
    title: "Desvio Orçamentário - Fundação",
    description: "Gasto com aço 12% acima do previsto na etapa de fundação.",
    date: "Ontem, 16:45"
  },
  {
    id: 3,
    severity: "low",
    title: "Documentação Pendente",
    description: "ART de Execução não foi anexada no sistema.",
    date: "14/02/2026"
  }
];

export const NAV_ITEMS = [
  { title: "Dashboard", icon: LayoutDashboard, href: "/" },
  { title: "Minhas Obras", icon: Building2, href: "/projects" },
  { title: "Cronograma", icon: Calendar, href: "/timeline" },
  { title: "Checklists", icon: CheckSquare, href: "/checklists" },
  { title: "Busca Normativa (IA)", icon: Search, href: "/norms", featured: true },
  { title: "Documentos", icon: FileText, href: "/documents" },
  { title: "Configurações", icon: Settings, href: "/settings" },
];
