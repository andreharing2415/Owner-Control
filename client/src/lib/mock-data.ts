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

export type StageStatus = "completed" | "in-progress" | "upcoming" | "delayed";

export const TIMELINE_MOCK = [
  {
    id: 1,
    title: "Projetos e Legalização",
    date: "Jan 2026",
    status: "completed" as StageStatus,
    budget: { planejado: 50000, realizado: 48000 },
    progress: 100,
    description: "Aprovação na prefeitura e projetos executivos finalizados."
  },
  {
    id: 2,
    title: "Serviços Preliminares",
    date: "Fev 2026",
    status: "completed" as StageStatus,
    budget: { planejado: 25000, realizado: 28000 },
    progress: 100,
    description: "Limpeza do terreno, tapumes e canteiro de obras."
  },
  {
    id: 3,
    title: "Fundação e Infraestrutura",
    date: "Mar 2026",
    status: "in-progress" as StageStatus,
    budget: { planejado: 120000, realizado: 85000 },
    progress: 65,
    description: "Estacas escavadas e blocos de coroamento em execução.",
    currentActivity: "Concretagem dos blocos do setor A"
  },
  {
    id: 4,
    title: "Superestrutura (Lajes e Pilares)",
    date: "Mai 2026",
    status: "upcoming" as StageStatus,
    budget: { planejado: 350000, realizado: 0 },
    progress: 0,
    description: "Pilares, vigas e lajes dos pavimentos."
  },
  {
    id: 5,
    title: "Alvenaria e Vedação",
    date: "Jul 2026",
    status: "upcoming" as StageStatus,
    budget: { planejado: 180000, realizado: 0 },
    progress: 0,
    description: "Paredes internas e externas."
  },
  {
    id: 6,
    title: "Instalações Hidráulicas/Elétricas",
    date: "Ago 2026",
    status: "upcoming" as StageStatus,
    budget: { planejado: 220000, realizado: 0 },
    progress: 0,
    description: "Tubulações, fiação e infraestrutura de ar condicionado."
  }
];

export const CHECKLIST_MOCK = {
  stageId: 3,
  stageName: "Fundação e Infraestrutura",
  items: [
    {
      id: "f1",
      category: "Gabarito e Locação",
      question: "Os eixos das estacas conferem com o projeto de locação?",
      critical: true,
      status: "checked",
      evidence: "/images/evidence-1.jpg"
    },
    {
      id: "f2",
      category: "Escavação",
      question: "A profundidade das estacas atingiu a cota de projeto?",
      critical: true,
      status: "checked",
      evidence: null
    },
    {
      id: "f3",
      category: "Armação",
      question: "As armaduras estão isentas de oxidação excessiva (ferrugem)?",
      critical: false,
      status: "unchecked",
      evidence: null,
      aiObservation: "Norma NBR 6118 permite oxidação superficial, mas recomenda limpeza se houver descamação."
    },
    {
      id: "f4",
      category: "Concretagem",
      question: "Foi realizado o teste de slump (abatimento) do concreto na chegada do caminhão?",
      critical: true,
      status: "unchecked",
      evidence: null
    }
  ]
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
