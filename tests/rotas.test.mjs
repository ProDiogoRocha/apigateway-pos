// Contrato API Gateway x Lambda: roda sobre o bundle (npm test gera dist/openapi.json antes).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const bruto = readFileSync(new URL('../dist/openapi.json', import.meta.url), 'utf8');
const api = JSON.parse(bruto);
const gatewayResponses = api['x-amazon-apigateway-gateway-responses'];

// Mesmas rotas do switch em BffRequestHandler.cs (Lambda.Itau).
const rotasDaLambda = [
  'GET /posicao-transportadores',
  'POST /posicao-transportadores/{indiceControlePosicao}/reverter',
  'GET /posicao-transportadores/{indiceControlePosicao}/justificativa-divergencias',
  'GET /posicao-transportadores/{indiceControlePosicao}/justificativa-termo-juridico',
  'GET /centralizadores/{numeroCentralizador}',
  'GET /centralizadores/{numeroCentralizador}/fornecedores/{fornecedorId}',
  'GET /centralizadores/{numeroCentralizador}/fornecedores/{fornecedorId}/bases/{baseId}',
  'GET /centralizadores/{numeroCentralizador}/polos/{poloId}',
];

const operacoes = Object.entries(api.paths).flatMap(([path, item]) =>
  Object.entries(item)
    .filter(([metodo]) => metodo !== 'parameters')
    .map(([metodo, operacao]) => ({ path, item, metodo: metodo.toUpperCase(), operacao })));

const daLambda = operacoes.filter(({ metodo }) => metodo !== 'OPTIONS');

// Valores de um header do preflight, ex.: "'GET,POST'" => ['get', 'post'].
const liberados = (path, header) =>
  api.paths[path].options['x-amazon-apigateway-integration'].responses.default
    .responseParameters[`method.response.header.${header}`].slice(1, -1).toLowerCase().split(',');

// O import do API Gateway não resolve $ref de respostas ("important notes for REST APIs" da AWS).
test('o bundle não tem $ref', () => {
  assert.ok(!bruto.includes('"$ref"'));
});

test('expõe exatamente as rotas da Lambda', () => {
  assert.deepEqual(daLambda.map(({ metodo, path }) => `${metodo} ${path}`).sort(), [...rotasDaLambda].sort());
});

test('toda rota da Lambda usa integração proxy dentro do limite de 29s do API Gateway', () => {
  for (const { metodo, path, operacao } of daLambda) {
    const integracao = operacao['x-amazon-apigateway-integration'];
    assert.equal(integracao?.type, 'aws_proxy', `${metodo} ${path}`);
    assert.equal(integracao.httpMethod, 'POST', `${metodo} ${path}`);
    assert.equal(integracao.uri, '${lambda_invoke_arn}', `${metodo} ${path}`);
    assert.ok(integracao.timeoutInMillis <= 29000, `${metodo} ${path}`);
  }
});

test('toda rota da Lambda documenta os headers obrigatórios', () => {
  for (const { metodo, path, operacao } of daLambda) {
    const headers = (operacao.parameters ?? []).filter((p) => p.in === 'header' && p.required).map((p) => p.name);
    assert.deepEqual(headers.sort(), ['x-itau-apikey', 'x-itau-correlationID'], `${metodo} ${path}`);
  }
});

test('todo parâmetro de rota está declarado', () => {
  for (const { metodo, path, item, operacao } of daLambda) {
    const declarados = [...(item.parameters ?? []), ...(operacao.parameters ?? [])]
      .filter((p) => p.in === 'path').map((p) => p.name);
    const esperados = [...path.matchAll(/{(\w+)}/g)].map(([, nome]) => nome);
    assert.deepEqual(declarados.sort(), esperados.sort(), `${metodo} ${path}`);
  }
});

test('todo path responde o preflight CORS no próprio API Gateway', () => {
  for (const [path, item] of Object.entries(api.paths)) {
    const integracao = item.options?.['x-amazon-apigateway-integration'];
    assert.equal(integracao?.type, 'mock', path);
    const parametros = integracao.responses.default.responseParameters;
    assert.equal(parametros['method.response.header.Access-Control-Allow-Origin'], "'${cors_allowed_origin}'", path);
    // O import rejeita mapeamento para header que a resposta 200 não declara.
    assert.deepEqual(
      Object.keys(parametros).sort(),
      Object.keys(item.options.responses['200'].headers).map((header) => `method.response.header.${header}`).sort(),
      path);
  }
});

test('o preflight libera o método e os headers de toda rota da Lambda', () => {
  for (const { metodo, path, operacao } of daLambda) {
    assert.ok(liberados(path, 'Access-Control-Allow-Methods').includes(metodo.toLowerCase()), `${metodo} ${path}`);
    const enviados = (operacao.parameters ?? []).filter((p) => p.in === 'header').map((p) => p.name.toLowerCase());
    if (operacao.requestBody) {
      enviados.push('content-type');
    }
    for (const header of enviados) {
      assert.ok(liberados(path, 'Access-Control-Allow-Headers').includes(header), `${header} em ${metodo} ${path}`);
    }
  }
});

test('rota inexistente responde 404 no formato de erro da Lambda', () => {
  const resposta = gatewayResponses.MISSING_AUTHENTICATION_TOKEN;
  assert.equal(resposta.statusCode, '404');
  assert.deepEqual(JSON.parse(resposta.responseTemplates['application/json']), {
    messages: [{ codigo: '404', mensagem: 'Recurso inexistente.' }],
  });
});

test('erro do API Gateway no formato da Lambda leva o próprio status no codigo e está documentado nas rotas', () => {
  for (const [tipo, resposta] of Object.entries(gatewayResponses).filter(([, r]) => r.statusCode)) {
    const corpo = JSON.parse(resposta.responseTemplates['application/json']);
    assert.equal(corpo.messages[0].codigo, resposta.statusCode, tipo);
    for (const { metodo, path, operacao } of daLambda) {
      assert.ok(resposta.statusCode in operacao.responses, `${resposta.statusCode} em ${metodo} ${path}`);
    }
  }
});

test('todo erro gerado pelo API Gateway leva o header CORS', () => {
  assert.ok('DEFAULT_4XX' in gatewayResponses && 'DEFAULT_5XX' in gatewayResponses);
  for (const [tipo, resposta] of Object.entries(gatewayResponses)) {
    assert.equal(
      resposta.responseParameters['gatewayresponse.header.Access-Control-Allow-Origin'],
      "'${cors_allowed_origin}'",
      tipo);
  }
});

// O Terraform passa o bundle por templatefile(): qualquer ${...} ou %{...} além das duas variáveis quebra o deploy.
test('o bundle só usa as variáveis que o Terraform preenche', () => {
  const variaveis = new Set([...bruto.matchAll(/[$%]\{([^}]*)\}/g)].map(([trecho]) => trecho));
  assert.deepEqual([...variaveis].sort(), ['${cors_allowed_origin}', '${lambda_invoke_arn}']);
});
