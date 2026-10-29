import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { renderItau } from '../scripts/render-itau.mjs';

const template = JSON.parse(readFileSync(new URL('../dist/openapi.json', import.meta.url), 'utf8'));
const config = { environment: 'dev', cors: 'https://front.exemplo.com', vpce: ['vpce-0123456789abcdef0'], baseUrl: 'https://bff.api-sp.dev.aws.cloud.ihf/posicao-transportadores-bff/v1' };

for (const [environment, account] of Object.entries({ dev: '380271727186', hom: '673385326085', prod: '231186687269' })) {
  test(`artefato Itaú ${environment} usa alias e roles da conta, STS e policy privada`, () => {
    const api = renderItau(template, { ...config, environment });
    assert.ok(!JSON.stringify(api).includes('${'));
    for (const item of Object.values(api.paths)) {
      assert.deepEqual(item.options.security, []);
      for (const [method, operation] of Object.entries(item).filter(([m]) => m === 'get' || m === 'post')) {
        assert.ok(operation['x-amazon-apigateway-integration'].uri.endsWith(`:function:lambda-ln-app-bff-posicao:${environment}/invocations`));
        assert.ok(operation['x-amazon-apigateway-integration'].uri.includes(`:${account}:function:`));
        assert.equal(operation['x-amazon-apigateway-integration'].credentials, `arn:aws:iam::${account}:role/iamsr/invoke-lambda-ln-app-bff-posicao`);
        assert.deepEqual(operation.security, [{ APIGatewaySTSAuthorizer: [`numerario-posicao-transportadores.${method === 'post' ? 'write' : 'read'}`] }]);
      }
    }
    const authorizer = api.components.securitySchemes.APIGatewaySTSAuthorizer['x-amazon-apigateway-authorizer'];
    assert.equal(authorizer.authorizerCredentials, `arn:aws:iam::${account}:role/custom-gateway-invoke-authorizer-role`);
    assert.ok(authorizer.authorizerUri.includes(`:${account}:function:valida-token-posicao-custodia-numerario-v1-interno/invocations`));
    assert.equal(authorizer.type, 'request');
    assert.equal(authorizer.authorizerResultTtlInSeconds, 0);
    assert.deepEqual(api['x-amazon-apigateway-policy'].Statement[0].Condition.StringNotEquals['aws:SourceVpce'], config.vpce);
    assert.equal(api.servers[0].url, config.baseUrl);
    assert.equal(api['x-amazon-apigateway-gateway-responses'].UNAUTHORIZED.responseParameters['gatewayresponse.header.Access-Control-Allow-Origin'], `'${config.cors}'`);
  });
}

test('artefato rejeita ambiente, CORS, VPCE ou URL de acesso inválidos', () => {
  for (const patch of [{ environment: 'outro' }, { cors: '*' }, { cors: 'https://front.exemplo.com/' }, { vpce: [] }, { vpce: ['PREENCHER'] }, { baseUrl: 'http://bff.local' }, { baseUrl: 'https://user:senha@bff.local' }]) {
    assert.throws(() => renderItau(template, { ...config, ...patch }));
  }
});

test('artefato rejeita placeholder desconhecido e mantém o template original intacto', () => {
  const before = JSON.stringify(template);
  renderItau(template, config);
  assert.equal(JSON.stringify(template), before);
  assert.throws(() => renderItau({ ...template, info: { description: '${nao_configurada}' } }, config), /Variável não resolvida/);
});
