import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:owner_control/api/api.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _obraJson({
  String id = 'obra-1',
  String nome = 'Residencia Teste',
  String? localizacao = 'Sao Paulo, SP',
  double? orcamento = 500000,
  String? dataInicio,
  String? dataFim,
}) =>
    {
      'id': id,
      'nome': nome,
      'localizacao': localizacao,
      'orcamento': orcamento,
      'data_inicio': dataInicio,
      'data_fim': dataFim,
    };

Map<String, dynamic> _etapaJson({
  String id = 'etapa-1',
  String obraId = 'obra-1',
  String nome = 'Fundacoes e Estrutura',
  int ordem = 1,
  String status = 'pendente',
  double? score,
}) =>
    {
      'id': id,
      'obra_id': obraId,
      'nome': nome,
      'ordem': ordem,
      'status': status,
      'score': score,
    };

Map<String, dynamic> _itemJson({
  String id = 'item-1',
  String etapaId = 'etapa-1',
  String titulo = 'Verificar sondagem',
  String status = 'pendente',
  bool critico = false,
}) =>
    {
      'id': id,
      'etapa_id': etapaId,
      'titulo': titulo,
      'descricao': null,
      'status': status,
      'critico': critico,
      'observacao': null,
    };

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── listarObras ────────────────────────────────────────────────────────────

  group('ApiClient.listarObras', () {
    test('retorna lista vazia quando API retorna []', () async {
      final api = ApiClient(client: MockClient((_) async => _json([])));
      final obras = await api.listarObras();
      expect(obras, isEmpty);
    });

    test('mapeia campos obrigatorios e opcionais corretamente', () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => _json([
            _obraJson(dataInicio: '2025-01-15', dataFim: '2025-12-31'),
          ]),
        ),
      );
      final obras = await api.listarObras();
      expect(obras.length, 1);
      final o = obras.first;
      expect(o.id, 'obra-1');
      expect(o.nome, 'Residencia Teste');
      expect(o.localizacao, 'Sao Paulo, SP');
      expect(o.orcamento, 500000);
      expect(o.dataInicio, '2025-01-15');
      expect(o.dataFim, '2025-12-31');
    });

    test('mapeia obra sem datas (campos null)', () async {
      final api = ApiClient(
        client: MockClient((_) async => _json([_obraJson()])),
      );
      final obras = await api.listarObras();
      expect(obras.first.dataInicio, isNull);
      expect(obras.first.dataFim, isNull);
    });

    test('lanca excecao quando status != 200', () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => _json({'detail': 'erro'}, status: 500),
        ),
      );
      expect(() => api.listarObras(), throwsException);
    });
  });

  // ── criarObra ──────────────────────────────────────────────────────────────

  group('ApiClient.criarObra', () {
    test('envia apenas nome quando campos opcionais sao nulos', () async {
      Map<String, dynamic> capturedBody = {};
      final api = ApiClient(
        client: MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _json(_obraJson(localizacao: null, orcamento: null));
        }),
      );
      await api.criarObra(nome: 'Obra Minima');
      expect(capturedBody['nome'], 'Obra Minima');
      expect(capturedBody.containsKey('localizacao'), isFalse);
      expect(capturedBody.containsKey('orcamento'), isFalse);
      expect(capturedBody.containsKey('data_inicio'), isFalse);
      expect(capturedBody.containsKey('data_fim'), isFalse);
    });

    test('envia todos os campos quando fornecidos', () async {
      Map<String, dynamic> capturedBody = {};
      final api = ApiClient(
        client: MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _json(
            _obraJson(dataInicio: '2025-03-01', dataFim: '2026-03-01'),
          );
        }),
      );
      await api.criarObra(
        nome: 'Residencia Premium',
        localizacao: 'Alphaville',
        orcamento: 1200000,
        dataInicio: '2025-03-01',
        dataFim: '2026-03-01',
      );
      expect(capturedBody['nome'], 'Residencia Premium');
      expect(capturedBody['localizacao'], 'Alphaville');
      expect(capturedBody['orcamento'], 1200000);
      expect(capturedBody['data_inicio'], '2025-03-01');
      expect(capturedBody['data_fim'], '2026-03-01');
    });

    test('retorna Obra com datas corretas apos criacao', () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => _json(
            _obraJson(dataInicio: '2025-06-01', dataFim: '2026-06-01'),
          ),
        ),
      );
      final obra = await api.criarObra(
        nome: 'Nova Obra',
        dataInicio: '2025-06-01',
        dataFim: '2026-06-01',
      );
      expect(obra.dataInicio, '2025-06-01');
      expect(obra.dataFim, '2026-06-01');
    });

    test('lanca excecao quando status != 200', () async {
      final api = ApiClient(
        client: MockClient((_) async => _json({}, status: 422)),
      );
      expect(() => api.criarObra(nome: 'Falha'), throwsException);
    });
  });

  // ── listarEtapas ───────────────────────────────────────────────────────────

  group('ApiClient.listarEtapas', () {
    test('extrai etapas do objeto obra retornado pela API', () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => _json({
            'obra': _obraJson(),
            'etapas': [
              _etapaJson(ordem: 1, nome: 'Planejamento'),
              _etapaJson(id: 'etapa-2', ordem: 2, nome: 'Fundacoes'),
            ],
          }),
        ),
      );
      final etapas = await api.listarEtapas('obra-1');
      expect(etapas.length, 2);
      expect(etapas[0].nome, 'Planejamento');
      expect(etapas[1].nome, 'Fundacoes');
      expect(etapas[1].ordem, 2);
    });

    test('retorna lista vazia quando nao ha etapas', () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => _json({'obra': _obraJson(), 'etapas': []}),
        ),
      );
      final etapas = await api.listarEtapas('obra-1');
      expect(etapas, isEmpty);
    });

    test('lanca excecao quando status != 200', () async {
      final api = ApiClient(
        client: MockClient((_) async => _json({}, status: 404)),
      );
      expect(() => api.listarEtapas('nao-existe'), throwsException);
    });
  });

  // ── atualizarStatusEtapa ───────────────────────────────────────────────────

  group('ApiClient.atualizarStatusEtapa', () {
    test('envia PATCH com campo status correto', () async {
      String? capturedStatus;
      final api = ApiClient(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          capturedStatus = body['status'] as String?;
          return _json(_etapaJson(status: 'em_andamento'));
        }),
      );
      final etapa = await api.atualizarStatusEtapa(
        etapaId: 'etapa-1',
        status: 'em_andamento',
      );
      expect(capturedStatus, 'em_andamento');
      expect(etapa.status, 'em_andamento');
    });
  });

  // ── listarItens ────────────────────────────────────────────────────────────

  group('ApiClient.listarItens', () {
    test('mapeia itens corretamente', () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => _json([
            _itemJson(critico: true),
            _itemJson(id: 'item-2', titulo: 'Verificar formas', status: 'ok'),
          ]),
        ),
      );
      final itens = await api.listarItens('etapa-1');
      expect(itens.length, 2);
      expect(itens[0].critico, isTrue);
      expect(itens[1].status, 'ok');
    });
  });

  // ── calcularScore ──────────────────────────────────────────────────────────

  group('ApiClient.calcularScore', () {
    test('retorna score numerico', () async {
      final api = ApiClient(
        client: MockClient((_) async => _json({'score': 72.5})),
      );
      final score = await api.calcularScore('etapa-1');
      expect(score, 72.5);
    });

    test('retorna 0 quando score e null na resposta', () async {
      final api = ApiClient(
        client: MockClient((_) async => _json({'score': null})),
      );
      final score = await api.calcularScore('etapa-1');
      expect(score, 0.0);
    });
  });

  // ── Obra.tipo ───────────────────────────────────────────────────────────

  group('Obra.fromJson — tipo field', () {
    test('defaults to construcao when tipo is absent', () {
      final obra = Obra.fromJson(_obraJson());
      expect(obra.tipo, 'construcao');
    });

    test('parses tipo field when present', () {
      final json = _obraJson();
      json['tipo'] = 'reforma';
      final obra = Obra.fromJson(json);
      expect(obra.tipo, 'reforma');
    });
  });

  // ── AtividadeCronograma ────────────────────────────────────────────────

  group('AtividadeCronograma.fromJson', () {
    test('parses flat activity correctly', () {
      final json = {
        'id': 'ativ-1',
        'obra_id': 'obra-1',
        'parent_id': null,
        'nome': 'Fundacao',
        'descricao': 'Fase de fundacao',
        'ordem': 1,
        'nivel': 1,
        'status': 'pendente',
        'valor_previsto': 50000.0,
        'valor_gasto': 0.0,
        'tipo_projeto': 'Estrutural',
        'sub_atividades': [],
        'servicos': [],
      };
      final atividade = AtividadeCronograma.fromJson(json);
      expect(atividade.id, 'ativ-1');
      expect(atividade.nome, 'Fundacao');
      expect(atividade.nivel, 1);
      expect(atividade.valorPrevisto, 50000.0);
      expect(atividade.subAtividades, isEmpty);
    });

    test('parses nested sub-activities and services', () {
      final json = {
        'id': 'ativ-1',
        'obra_id': 'obra-1',
        'nome': 'Fundacao',
        'ordem': 1,
        'nivel': 1,
        'status': 'pendente',
        'valor_previsto': 50000.0,
        'valor_gasto': 10000.0,
        'sub_atividades': [
          {
            'id': 'ativ-2',
            'obra_id': 'obra-1',
            'parent_id': 'ativ-1',
            'nome': 'Perfuracao',
            'ordem': 1,
            'nivel': 2,
            'status': 'em_andamento',
            'valor_previsto': 15000.0,
            'valor_gasto': 5000.0,
            'servicos': [
              {
                'id': 'svc-1',
                'atividade_id': 'ativ-2',
                'descricao': 'Operador de perfuratriz',
                'categoria': 'empreiteiro',
              },
            ],
          },
        ],
        'servicos': [],
      };
      final atividade = AtividadeCronograma.fromJson(json);
      expect(atividade.subAtividades.length, 1);
      expect(atividade.subAtividades[0].nome, 'Perfuracao');
      expect(atividade.subAtividades[0].servicos.length, 1);
      expect(atividade.subAtividades[0].servicos[0].descricao, 'Operador de perfuratriz');
    });

    test('defaults missing fields gracefully', () {
      final json = {
        'id': 'ativ-1',
        'obra_id': 'obra-1',
        'nome': 'Alvenaria',
      };
      final atividade = AtividadeCronograma.fromJson(json);
      expect(atividade.ordem, 0);
      expect(atividade.nivel, 1);
      expect(atividade.status, 'pendente');
      expect(atividade.valorPrevisto, 0);
      expect(atividade.subAtividades, isEmpty);
      expect(atividade.servicos, isEmpty);
    });
  });

  // ── CronogramaResponse ─────────────────────────────────────────────────

  group('CronogramaResponse.fromJson', () {
    test('parses response with totals', () {
      final json = {
        'obra_id': 'obra-1',
        'total_previsto': 500000.0,
        'total_gasto': 120000.0,
        'desvio_percentual': -76.0,
        'atividades': [
          {
            'id': 'ativ-1',
            'obra_id': 'obra-1',
            'nome': 'Fundacao',
            'ordem': 1,
            'nivel': 1,
            'status': 'pendente',
            'valor_previsto': 50000.0,
            'valor_gasto': 0.0,
            'sub_atividades': [],
            'servicos': [],
          },
        ],
      };
      final response = CronogramaResponse.fromJson(json);
      expect(response.totalPrevisto, 500000.0);
      expect(response.totalGasto, 120000.0);
      expect(response.atividades.length, 1);
    });
  });

  // ── ServicoNecessario ──────────────────────────────────────────────────

  group('ServicoNecessario.fromJson', () {
    test('parses service correctly', () {
      final json = {
        'id': 'svc-1',
        'atividade_id': 'ativ-1',
        'descricao': 'Pedreiro',
        'categoria': 'empreiteiro',
        'prestador_id': null,
      };
      final servico = ServicoNecessario.fromJson(json);
      expect(servico.descricao, 'Pedreiro');
      expect(servico.categoria, 'empreiteiro');
      expect(servico.prestadorId, isNull);
    });
  });

  // ── TipoProjetoIdentificado ────────────────────────────────────────────

  group('TipoProjetoIdentificado.fromJson', () {
    test('parses identified project type', () {
      final json = {
        'nome': 'Estrutural',
        'confianca': 95,
        'projeto_doc_id': 'doc-1',
        'projeto_doc_nome': 'projeto_estrutural.pdf',
      };
      final tipo = TipoProjetoIdentificado.fromJson(json);
      expect(tipo.nome, 'Estrutural');
      expect(tipo.confianca, 95);
      expect(tipo.confirmado, isTrue);
    });
  });
}
