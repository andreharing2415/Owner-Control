import { useQuery, useMutation } from "@tanstack/react-query";
import { apiRequest, queryClient } from "./queryClient";

// Types matching the backend schemas

export interface ProjetoDoc {
  id: string;
  obra_id: string;
  arquivo_url: string;
  arquivo_nome: string;
  status: string;
  resumo_geral: string | null;
  aviso_legal: string | null;
  created_at: string;
  updated_at: string;
}

export interface Risco {
  id: string;
  projeto_id: string;
  descricao: string;
  severidade: string;
  norma_referencia: string | null;
  traducao_leigo: string;
  requer_validacao_profissional: boolean;
  confianca: number;
  norma_url: string | null;
  acao_proprietario: string | null;
  perguntas_para_profissional: string | null;
  documentos_a_exigir: string | null;
}

export interface ProjetoAnalise {
  projeto: ProjetoDoc;
  riscos: Risco[];
}

export interface ChecklistGeracaoLog {
  id: string;
  obra_id: string;
  status: string;
  total_docs_analisados: number;
  caracteristicas_identificadas: string | null;
  total_itens_sugeridos: number;
  total_itens_aplicados: number;
  total_paginas: number;
  paginas_processadas: number;
  resumo_geral: string | null;
  aviso_legal: string | null;
  erro_detalhe: string | null;
  created_at: string;
  updated_at: string;
}

export interface ChecklistGeracaoItem {
  id: string;
  log_id: string;
  etapa_nome: string;
  titulo: string;
  descricao: string;
  norma_referencia: string | null;
  critico: boolean;
  risco_nivel: string;
  requer_validacao_profissional: boolean;
  confianca: number;
  como_verificar: string;
  medidas_minimas: string | null;
  explicacao_leigo: string;
  caracteristica_origem: string;
  created_at: string;
}

export interface ChecklistGeracaoStatus {
  log: ChecklistGeracaoLog;
  itens: ChecklistGeracaoItem[];
}

// Parse JSON string fields from Risco
export function parsePerguntas(
  raw: string | null
): { pergunta: string; resposta_esperada: string }[] {
  if (!raw) return [];
  try {
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

export function parseDocumentos(raw: string | null): string[] {
  if (!raw) return [];
  try {
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

export function parseCaracteristicas(raw: string | null): string[] {
  if (!raw) return [];
  try {
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

// Hardcoded for now — will come from auth/obra context later
const OBRA_ID = "1";

// --- Documents ---

export function useDocuments(obraId: string = OBRA_ID) {
  return useQuery<ProjetoDoc[]>({
    queryKey: ["/api/obras", obraId, "projetos"],
    staleTime: 30_000,
  });
}

export function useAnalise(projetoId: string) {
  return useQuery<ProjetoAnalise>({
    queryKey: ["/api/projetos", projetoId, "analise"],
    enabled: !!projetoId,
  });
}

export function useAnalisarProjeto() {
  return useMutation({
    mutationFn: async (projetoId: string) => {
      const res = await apiRequest("POST", `/api/projetos/${projetoId}/analisar`);
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["/api/obras"] });
    },
  });
}

// --- Checklist Inteligente ---

export function useChecklistHistorico(obraId: string = OBRA_ID) {
  return useQuery<ChecklistGeracaoLog[]>({
    queryKey: ["/api/obras", obraId, "checklist-inteligente", "historico"],
    staleTime: 10_000,
  });
}

export function useChecklistStatus(
  obraId: string,
  logId: string | null,
  enabled: boolean = true
) {
  return useQuery<ChecklistGeracaoStatus>({
    queryKey: ["/api/obras", obraId, "checklist-inteligente", logId!, "status"],
    enabled: enabled && !!logId,
    refetchInterval: (query) => {
      const data = query.state.data as ChecklistGeracaoStatus | undefined;
      if (data && data.log.status !== "processando") return false;
      return 3000; // Poll every 3s while processing
    },
  });
}

export function useIniciarChecklist() {
  return useMutation({
    mutationFn: async (obraId: string) => {
      const res = await apiRequest(
        "POST",
        `/api/obras/${obraId}/checklist-inteligente/iniciar`
      );
      return (await res.json()) as ChecklistGeracaoLog;
    },
    onSuccess: (_, obraId) => {
      queryClient.invalidateQueries({
        queryKey: ["/api/obras", obraId, "checklist-inteligente", "historico"],
      });
    },
  });
}

export function useAplicarChecklist() {
  return useMutation({
    mutationFn: async ({
      obraId,
      itens,
    }: {
      obraId: string;
      itens: { etapa_nome: string; titulo: string; descricao: string; norma_referencia: string | null; critico: boolean }[];
    }) => {
      const res = await apiRequest(
        "POST",
        `/api/obras/${obraId}/checklist-inteligente/aplicar`,
        { itens }
      );
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["/api/obras"] });
    },
  });
}
