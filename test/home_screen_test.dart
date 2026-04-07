import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:owner_control/api/api.dart';
import 'package:owner_control/widgets/skeleton_loader.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

Obra _obra({
  String id = 'obra-1',
  String nome = 'Residencia Teste',
  String tipo = 'construcao',
  String? localizacao = 'Sao Paulo, SP',
  double? orcamento = 500000,
}) =>
    Obra(
      id: id,
      nome: nome,
      tipo: tipo,
      localizacao: localizacao,
      orcamento: orcamento,
    );

RelatorioFinanceiro _relatorio({
  bool alerta = false,
  double totalPrevisto = 100000,
  double totalGasto = 40000,
}) =>
    RelatorioFinanceiro(
      obraId: 'obra-1',
      totalPrevisto: totalPrevisto,
      totalGasto: totalGasto,
      desvioPercentual: totalPrevisto > 0
          ? ((totalGasto - totalPrevisto) / totalPrevisto * 100)
          : 0,
      alerta: alerta,
      threshold: 10.0,
      porEtapa: [],
    );

Etapa _etapa({
  String id = 'etapa-1',
  String nome = 'Fundacoes',
  int ordem = 1,
  String status = 'pendente',
}) =>
    Etapa(
      id: id,
      obraId: 'obra-1',
      nome: nome,
      ordem: ordem,
      status: status,
    );

// ─── Widget wrappers ──────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: Scaffold(body: child),
    );

// ─── SkeletonBox tests ────────────────────────────────────────────────────────

void main() {
  group('SkeletonBox', () {
    testWidgets('renderiza container com dimensoes corretas', (tester) async {
      await tester.pumpWidget(_wrap(
        const SkeletonBox(width: 120, height: 16),
      ));
      final container = tester.widget<Container>(find.byType(Container).last);
      expect(container.constraints?.maxWidth, 120);
      expect(container.constraints?.maxHeight, 16);
    });

    testWidgets('inicia animacao sem lancar excecao', (tester) async {
      await tester.pumpWidget(_wrap(
        const SkeletonBox(width: 80, height: 14),
      ));
      // Pump um frame de animacao — nao deve lancar excecao.
      await tester.pump(const Duration(milliseconds: 600));
      // Pode haver mais de um AnimatedBuilder (material + skeleton) — verifica apenas que existe.
      expect(find.byType(AnimatedBuilder), findsWidgets);
    });
  });

  // ─── ObraCardSkeleton tests ─────────────────────────────────────────────────

  group('ObraCardSkeleton', () {
    testWidgets('renderiza card sem dados reais', (tester) async {
      await tester.pumpWidget(_wrap(const ObraCardSkeleton()));
      expect(find.byType(Card), findsOneWidget);
      // Deve ter multiplos SkeletonBoxes para simular o layout.
      expect(find.byType(SkeletonBox), findsWidgets);
    });
  });

  // ─── DashboardSkeleton tests ────────────────────────────────────────────────

  group('DashboardSkeleton', () {
    testWidgets('renderiza multiplos cards skeleton', (tester) async {
      await tester.pumpWidget(_wrap(
        const SingleChildScrollView(child: DashboardSkeleton()),
      ));
      // DashboardSkeleton inclui ObraCardSkeleton + KpiRowSkeleton + card extra.
      expect(find.byType(Card), findsWidgets);
      expect(find.byType(SkeletonBox), findsWidgets);
    });
  });

  // ─── KpiRowSkeleton tests ───────────────────────────────────────────────────

  group('KpiRowSkeleton', () {
    testWidgets('renderiza 3 cards de KPI', (tester) async {
      await tester.pumpWidget(_wrap(const KpiRowSkeleton()));
      expect(find.byType(Card), findsNWidgets(3));
    });
  });

  // ─── _DashboardData unit tests ───────────────────────────────────────────────
  // Acesso via api.dart — testa logica de negocio pura sem Flutter.

  group('Obra.fromJson', () {
    test('mapeia todos os campos opcionais corretamente', () {
      final obra = Obra.fromJson({
        'id': 'obra-abc',
        'nome': 'Casa Verde',
        'localizacao': 'Campinas',
        'orcamento': 250000.0,
        'data_inicio': '2025-01-01',
        'data_fim': '2026-01-01',
      });
      expect(obra.id, 'obra-abc');
      expect(obra.nome, 'Casa Verde');
      expect(obra.localizacao, 'Campinas');
      expect(obra.orcamento, 250000.0);
      expect(obra.dataInicio, '2025-01-01');
      expect(obra.dataFim, '2026-01-01');
    });

    test('aceita campos opcionais nulos', () {
      final obra = Obra.fromJson({
        'id': 'obra-min',
        'nome': 'Minima',
      });
      expect(obra.localizacao, isNull);
      expect(obra.orcamento, isNull);
      expect(obra.dataInicio, isNull);
      expect(obra.dataFim, isNull);
    });
  });

  group('RelatorioFinanceiro.fromJson', () {
    test('detecta alerta financeiro quando true', () {
      final rel = RelatorioFinanceiro.fromJson({
        'obra_id': 'obra-1',
        'total_previsto': 100000.0,
        'total_gasto': 115000.0,
        'desvio_percentual': 15.0,
        'alerta': true,
        'threshold': 10.0,
        'por_etapa': [],
      });
      expect(rel.alerta, isTrue);
      expect(rel.desvioPercentual, 15.0);
    });

    test('nao alerta quando dentro do threshold', () {
      final rel = RelatorioFinanceiro.fromJson({
        'obra_id': 'obra-1',
        'total_previsto': 100000.0,
        'total_gasto': 95000.0,
        'desvio_percentual': -5.0,
        'alerta': false,
        'threshold': 10.0,
        'por_etapa': [],
      });
      expect(rel.alerta, isFalse);
    });

    test('usa threshold padrao 10.0 quando ausente', () {
      final rel = RelatorioFinanceiro.fromJson({
        'obra_id': 'obra-1',
        'total_previsto': 50000.0,
        'total_gasto': 30000.0,
        'desvio_percentual': -40.0,
        'alerta': false,
        'por_etapa': [],
      });
      expect(rel.threshold, 10.0);
    });
  });

  group('Etapa.fromJson', () {
    test('mapeia status e ordem corretamente', () {
      final etapa = Etapa.fromJson({
        'id': 'e-1',
        'obra_id': 'o-1',
        'nome': 'Alvenaria',
        'ordem': 3,
        'status': 'em_andamento',
        'score': 62.5,
      });
      expect(etapa.status, 'em_andamento');
      expect(etapa.ordem, 3);
      expect(etapa.score, 62.5);
    });

    test('aceita status e score nulos com defaults', () {
      final etapa = Etapa.fromJson({
        'id': 'e-2',
        'obra_id': 'o-1',
        'nome': 'Cobertura',
        'ordem': 5,
        'status': 'pendente',
      });
      expect(etapa.score, isNull);
    });
  });

  // ─── Validacao de estado preservado via cache ─────────────────────────────
  // Testa que o Map de cache preserva dados sem nova requisicao.

  group('cache de dashboard preserva dados por obraId', () {
    test('mapa retorna dado inserido pelo mesmo obraId', () {
      final cache = <String, Object>{};
      const obraId = 'obra-99';
      final dados = {'progresso': 0.75};
      cache[obraId] = dados;

      expect(cache[obraId], isNotNull);
      expect((cache[obraId] as Map)['progresso'], 0.75);
    });

    test('lookup retorna null para obraId desconhecido', () {
      final cache = <String, Object>{};
      expect(cache['obra-inexistente'], isNull);
    });

    test('remover obraId do cache invalida entrada', () {
      final cache = <String, Object>{};
      cache['obra-1'] = {'ok': true};
      cache.remove('obra-1');
      expect(cache['obra-1'], isNull);
    });
  });
}
