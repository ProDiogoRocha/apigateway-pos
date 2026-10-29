import { readFileSync, writeFileSync, mkdirSync, unlinkSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
import { parseArgs } from 'node:util';

const contas = { dev: '380271727186', hom: '673385326085', prod: '231186687269' };
const funcao = 'lambda-ln-app-bff-posicao';
const authorizer = 'valida-token-posicao-custodia-numerario-v1-interno';

// Artefato para a infraestrutura corporativa existente. Não cria recursos nem altera o state do Itaú.
export function renderItau(template, { environment, cors, vpce, baseUrl }) {
  if (!Object.hasOwn(contas, environment)) throw new Error('environment deve ser dev, hom ou prod.');
  if (!/^https?:\/\/[a-z0-9.-]+(:[0-9]{1,5})?$/.test(cors ?? '')) {
    throw new Error('cors deve ser a origem exata do front, sem caminho ou barra final.');
  }
  if (!Array.isArray(vpce) || vpce.length === 0 || vpce.some(id => !/^vpce-[a-f0-9]+$/.test(id))) {
    throw new Error('Informe ao menos um --vpce autorizado para a API privada.');
  }
  const url = new URL(baseUrl);
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) {
    throw new Error('base-url deve ser a URL HTTPS do BFF, incluindo o mapping confirmado no Itaú.');
  }
  const conta = contas[environment];
  const invoke = nome => `arn:aws:apigateway:sa-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:sa-east-1:${conta}:function:${nome}/invocations`;
  const valores = {
    lambda_invoke_arn: invoke(`${funcao}:${environment}`),
    sts_authorizer_invoke_arn: invoke(authorizer),
    sts_authorizer_credentials_arn: `arn:aws:iam::${conta}:role/custom-gateway-invoke-authorizer-role`,
    cors_allowed_origin: cors,
  };
  // Substituir valores antes de serializar preserva JSON válido mesmo com caracteres especiais.
  const preencher = valor => {
    if (typeof valor === 'string') return valor.replace(/\$\{([^}]+)\}/g, (_, nome) => {
      if (!Object.hasOwn(valores, nome)) throw new Error(`Variável não resolvida: ${nome}`);
      return valores[nome];
    });
    if (Array.isArray(valor)) return valor.map(preencher);
    if (valor && typeof valor === 'object') return Object.fromEntries(Object.entries(valor).map(([k, v]) => [k, preencher(v)]));
    return valor;
  };
  const api = preencher(template);
  // O bundle já está dereferenciado; só securitySchemes é referenciado por nome nas operações.
  api.components = { securitySchemes: api.components.securitySchemes };
  api.servers = [{ url: baseUrl.replace(/\/+$/, ''), description: environment }];
  for (const item of Object.values(api.paths)) {
    for (const [metodo, operacao] of Object.entries(item)) {
      if (metodo === 'parameters' || metodo === 'options') continue;
      // Mesma role iamsr que as fotos usam e que o repositório da Lambda provisiona.
      operacao['x-amazon-apigateway-integration'].credentials = `arn:aws:iam::${conta}:role/iamsr/invoke-lambda-ln-app-bff-posicao`;
    }
  }
  api['x-amazon-apigateway-policy'] = {
    Version: '2012-10-17',
    Statement: [
      { Effect: 'Deny', Principal: '*', Action: 'execute-api:Invoke', Resource: 'execute-api:/*', Condition: { StringNotEquals: { 'aws:SourceVpce': vpce } } },
      { Effect: 'Allow', Principal: '*', Action: 'execute-api:Invoke', Resource: 'execute-api:/*' },
    ],
  };
  return api;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const { values } = parseArgs({ options: {
      environment: { type: 'string' }, cors: { type: 'string' },
      vpce: { type: 'string', multiple: true }, 'base-url': { type: 'string' },
    } });
    const api = renderItau(JSON.parse(readFileSync(new URL('../dist/openapi.json', import.meta.url), 'utf8')), {
      environment: values.environment, cors: values.cors, vpce: values.vpce, baseUrl: values['base-url'],
    });
    const dir = new URL(`../dist/itau/${values.environment}/`, import.meta.url);
    mkdirSync(dir, { recursive: true });
    const json = new URL('openapi.json', dir);
    const yaml = new URL('itau-ln-infra-bff-posicao-apigateway.yaml', dir);
    writeFileSync(json, JSON.stringify(api, null, 2) + '\n');
    execFileSync(process.execPath, [fileURLToPath(new URL('../node_modules/@redocly/cli/bin/cli.js', import.meta.url)),
      'bundle', fileURLToPath(json), '--output', fileURLToPath(yaml)], { stdio: 'inherit' });
    unlinkSync(json);
    console.log(`Contrato pronto para revisão: ${fileURLToPath(yaml)}`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
